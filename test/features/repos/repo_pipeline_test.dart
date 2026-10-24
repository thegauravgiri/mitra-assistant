import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/features/repos/data/repo_indexer.dart';
import 'package:mitra_assistant/features/repos/data/repo_repository.dart';
import 'package:mitra_assistant/features/repos/data/repo_summarizer.dart';
import 'package:mitra_assistant/features/repos/domain/models/repo_models.dart';

Future<Directory> makeRepo(Map<String, String> files) async {
  final dir = await Directory.systemTemp.createTemp('repo_test');
  for (final e in files.entries) {
    final f = File('${dir.path}/${e.key}');
    await f.parent.create(recursive: true);
    await f.writeAsString(e.value);
  }
  return dir;
}

String bigClass(String name) => 'class $name {\n${List.generate(30, (i) => '  int field$i = $i; // $name filler line number $i').join('\n')}\n}\n';

void main() {
  group('RepoIndexer', () {
    test('indexes a folder, skips secrets and dependencies, reports progress', () async {
      final dir = await makeRepo({
        'lib/payments.dart': bigClass('Payments'),
        'lib/auth.dart': bigClass('Auth'),
        'node_modules/x/index.js': 'x',
        '.env': 'KEY=1',
        'README.md': '# Hello\nProduct overview that is long enough to keep.\n',
        for (var i = 0; i < 25; i++) 'lib/f$i.dart': 'class F$i {}\n',
      });
      addTearDown(() => dir.delete(recursive: true));
      final progress = <double>[];
      final data = await RepoIndexer.index(
        RepoSource(id: 'r1', name: 'shop', path: dir.path),
        onProgress: (f, _) => progress.add(f),
      );
      expect(data.source.status, RepoStatus.ready);
      expect(data.source.fileCount, data.files.length);
      expect(data.files.keys, isNot(contains('.env')));
      expect(data.files.keys.every((p) => !p.startsWith('node_modules')), isTrue);
      expect(data.chunks.any((c) => c.path == 'lib/payments.dart'), isTrue);
      expect(data.source.indexedAt, isNotNull);
      expect(progress, isNotEmpty);
      expect(progress.every((f) => f > 0 && f <= 1), isTrue);
      expect(progress, orderedEquals([...progress]..sort())); // moves forward only
    });

    test('a refresh re-reads only changed files and keeps notes on unchanged ones', () async {
      final dir = await makeRepo({'lib/a.dart': bigClass('A'), 'lib/b.dart': bigClass('B')});
      addTearDown(() => dir.delete(recursive: true));
      final source = RepoSource(id: 'r1', name: 'x', path: dir.path);
      var data = await RepoIndexer.index(source);

      // pretend notes were written for both files
      data = RepoSummarizer.apply(data, {
        'lib/a.dart': const FileNotes(summary: 'About A.', scenarios: [ScenarioCard(question: 'What does A do?', answer: 'A things.', sources: ['lib/a.dart'])]),
        'lib/b.dart': const FileNotes(summary: 'About B.'),
      });
      expect(data.source.summarisedFiles, 2);

      await Future<void>.delayed(const Duration(milliseconds: 1100)); // make the modified time differ
      await File('${dir.path}/lib/b.dart').writeAsString(bigClass('B2'));
      final again = await RepoIndexer.index(data.source, previous: data);

      expect(again.chunks.where((c) => c.path == 'lib/a.dart').every((c) => c.summary == 'About A.'), isTrue, reason: 'unchanged file keeps its notes');
      expect(again.chunks.where((c) => c.path == 'lib/b.dart').every((c) => c.summary == null), isTrue, reason: 'changed file needs new notes');
      expect(again.chunks.where((c) => c.path == 'lib/b.dart').map((c) => c.text).join(), contains('B2'));
      expect(again.scenarios.single.question, 'What does A do?');
    });

    test('deleted files disappear, and ready-made answers citing them are dropped', () async {
      final dir = await makeRepo({'lib/a.dart': bigClass('A'), 'lib/b.dart': bigClass('B')});
      addTearDown(() => dir.delete(recursive: true));
      var data = await RepoIndexer.index(RepoSource(id: 'r1', name: 'x', path: dir.path));
      data = data.copyWith(scenarios: const [ScenarioCard(question: 'q about b', answer: 'a', sources: ['lib/b.dart'])]);
      await File('${dir.path}/lib/b.dart').delete();
      final again = await RepoIndexer.index(data.source, previous: data);
      expect(again.files.keys, ['lib/a.dart']);
      expect(again.scenarios, isEmpty);
    });

    test('binary files are skipped and a missing folder is an error', () async {
      final dir = await makeRepo({'lib/a.dart': bigClass('A')});
      addTearDown(() => dir.delete(recursive: true));
      await File('${dir.path}/lib/blob.dart').writeAsBytes([0, 1, 2, 0, 255, 0]);
      final data = await RepoIndexer.index(RepoSource(id: 'r1', name: 'x', path: dir.path));
      expect(data.files.keys, ['lib/a.dart']);
      expect(() => RepoIndexer.index(const RepoSource(id: 'r2', name: 'y', path: '/definitely/not/here')), throwsException);
    });
  });

  group('RepoRepository', () {
    test('saves one file per repository, loads them back, and deletes', () async {
      final dir = await Directory.systemTemp.createTemp('repo_store');
      addTearDown(() => dir.delete(recursive: true));
      final repo = RepoRepository(directory: () async => dir);
      expect(await repo.loadAll(), isEmpty);

      RepoData d(String id, String name) => RepoData(
            source: RepoSource(id: id, name: name, path: '/x/$name', status: RepoStatus.ready, indexedAt: DateTime(2026, 10, id == 'a' ? 1 : 2)),
            chunks: [CodeChunk(repoId: id, path: 'a.dart', startLine: 1, endLine: 2, kind: ChunkKind.code, symbols: const ['A'], text: 'class A {}')],
            files: const {'a.dart': '1:2'},
          );
      await repo.save(d('a', 'billing'));
      await repo.save(d('b', 'auth'));
      final loaded = await RepoRepository(directory: () async => dir).loadAll();
      expect(loaded.map((r) => r.source.name), ['billing', 'auth']);
      expect(loaded.first.chunks.single.repoId, 'a');

      await repo.delete('a');
      expect((await repo.loadAll()).map((r) => r.source.id), ['b']);
    });

    test('a corrupt file is skipped, the others still load', () async {
      final dir = await Directory.systemTemp.createTemp('repo_store');
      addTearDown(() => dir.delete(recursive: true));
      final repo = RepoRepository(directory: () async => dir);
      await repo.save(RepoData(source: const RepoSource(id: 'ok', name: 'ok', path: '/p', status: RepoStatus.ready)));
      await File('${dir.path}/broken.json').writeAsString('{not json');
      expect((await repo.loadAll()).map((r) => r.source.id), ['ok']);
    });
  });

  group('RepoSummarizer', () {
    RepoData sample() => RepoData(
          source: const RepoSource(id: 'r', name: 'shop', path: '/p'),
          chunks: [
            for (final p in ['lib/payment_service.dart', 'lib/util.dart', 'lib/tiny.dart', 'test/payment_test.dart'])
              CodeChunk(
                repoId: 'r',
                path: p,
                startLine: 1,
                endLine: 40,
                kind: p.startsWith('test') ? ChunkKind.test : ChunkKind.code,
                symbols: const [],
                text: p == 'lib/tiny.dart' ? 'class T {}' : 'x' * 900,
              ),
            const CodeChunk(repoId: 'r', path: 'README.md', startLine: 1, endLine: 5, kind: ChunkKind.doc, symbols: [], text: 'docs docs docs'),
          ],
        );

    test('selects substantial code files, important ones first, never docs or tiny files', () {
      final files = RepoSummarizer.selectFiles(sample());
      final paths = files.map((f) => f.$1).toList();
      expect(paths.first, 'lib/payment_service.dart'); // "payment"/"service" in the name
      expect(paths, isNot(contains('README.md')));
      expect(paths, isNot(contains('lib/tiny.dart')));
      expect(paths, containsAll(['lib/util.dart', 'test/payment_test.dart']));
    });

    test('files that already have notes are skipped unless forced', () {
      final d = sample();
      final noted = RepoSummarizer.apply(d, {'lib/payment_service.dart': const FileNotes(summary: 'x')});
      expect(RepoSummarizer.selectFiles(noted).map((f) => f.$1), isNot(contains('lib/payment_service.dart')));
      expect(RepoSummarizer.selectFiles(noted, force: true).map((f) => f.$1), contains('lib/payment_service.dart'));
    });

    test('batches stay within the size and count limits', () {
      final files = [for (var i = 0; i < 20; i++) ('lib/f$i.dart', 'y' * 3000)];
      final batches = RepoSummarizer.batches(files);
      expect(batches.every((b) => b.length <= RepoSummarizer.maxFilesPerBatch), isTrue);
      expect(batches.every((b) => b.fold<int>(0, (a, f) => a + f.$2.length) <= RepoSummarizer.batchChars + 3000), isTrue);
      expect(batches.expand((b) => b).length, 20); // nothing dropped
    });

    test('parses notes, keeps only the files we asked about, tolerates fences and bad rows', () {
      final raw = '```json\n${jsonEncode({
            'files': [
              {
                'path': 'lib/payment_service.dart',
                'summary': 'Charges customers.',
                'behaviours': ['Retries 3 times', 'Emails the customer after the last failure'],
                'scenarios': [
                  {'question': 'What if a payment fails?', 'answer': 'We retry three times, then email the customer.'},
                  {'question': '', 'answer': 'ignored'},
                ],
              },
              {'path': 'lib/invented.dart', 'summary': 'Not asked about'},
              {'path': 'lib/util.dart'},
              'garbage',
            ],
          })}\n```';
      final notes = RepoSummarizer.parse(raw, allowedPaths: {'lib/payment_service.dart', 'lib/util.dart'});
      expect(notes.keys, ['lib/payment_service.dart']);
      final n = notes['lib/payment_service.dart']!;
      expect(n.text, contains('Charges customers.'));
      expect(n.text, contains('Retries 3 times'));
      expect(n.scenarios.single.sources, ['lib/payment_service.dart']);
      expect(RepoSummarizer.parse('nope', allowedPaths: {'a'}), isEmpty);
      expect(RepoSummarizer.parse('', allowedPaths: {'a'}), isEmpty);
    });

    test('run: a failing batch is skipped and counted, the rest still produce notes', () async {
      final files = [for (var i = 0; i < 14; i++) ('lib/f$i.dart', 'z' * 3000)];
      var call = 0;
      final progress = <int>[];
      final result = await RepoSummarizer.run(
        'shop',
        files,
        onProgress: (done, total) => progress.add(done),
        generate: (system, prompt) async {
          call++;
          expect(system, contains('plain, non-technical'));
          if (call == 1) throw Exception('rate limited');
          final paths = RegExp(r'=== FILE: (\S+) ===').allMatches(prompt).map((m) => m.group(1)!).toList();
          return jsonEncode({'files': [for (final p in paths) {'path': p, 'summary': 'Does $p things.'}]});
        },
      );
      expect(result.failedBatches, 1);
      expect(result.notes.length, greaterThan(0));
      expect(result.notes.length, lessThan(14));
      expect(progress.last, progress.length);
    });

    test('apply writes notes onto every chunk of a file and merges scenario cards without duplicates', () {
      final d = sample().copyWith(scenarios: const [ScenarioCard(question: 'What happens if a payment fails?', answer: 'old', sources: ['x'])]);
      final out = RepoSummarizer.apply(d, {
        'lib/payment_service.dart': const FileNotes(
          summary: 'Charges.',
          scenarios: [
            ScenarioCard(question: 'What happens if the payment fails?', answer: 'duplicate by meaning', sources: ['lib/payment_service.dart']),
            ScenarioCard(question: 'Can customers get refunds?', answer: 'Yes within 5 days.', sources: ['lib/payment_service.dart']),
          ],
        ),
      });
      expect(out.chunks.firstWhere((c) => c.path == 'lib/payment_service.dart').summary, 'Charges.');
      expect(out.chunks.firstWhere((c) => c.path == 'lib/util.dart').summary, isNull);
      expect(out.scenarios.map((s) => s.question), ['What happens if a payment fails?', 'Can customers get refunds?']);
      expect(out.source.summarisedFiles, 1);
    });
  });
}
