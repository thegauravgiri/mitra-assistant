import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/features/repos/data/bm25_index.dart';
import 'package:mitra_assistant/features/repos/data/code_chunker.dart';
import 'package:mitra_assistant/features/repos/data/question_detector.dart';
import 'package:mitra_assistant/features/repos/data/repo_retrieval.dart';
import 'package:mitra_assistant/features/repos/data/repo_scanner.dart';
import 'package:mitra_assistant/features/repos/domain/models/repo_models.dart';
import 'package:mitra_assistant/features/transcription/domain/models/transcript_entry.dart';

CodeChunk chunk(String repo, String path, String text, {List<String> symbols = const [], ChunkKind kind = ChunkKind.code, String? summary, int line = 1}) =>
    CodeChunk(repoId: repo, path: path, startLine: line, endLine: line + text.split('\n').length, kind: kind, symbols: symbols, text: text, summary: summary);

final billing = [
  chunk('billing', 'lib/retry_policy.dart', 'class PaymentRetryPolicy {\n  final int maxAttempts = 3;\n  bool shouldRetry(int attempt) => attempt < maxAttempts;\n}', symbols: ['PaymentRetryPolicy', 'shouldRetry']),
  chunk('billing', 'lib/charge.dart', 'Future<void> chargeCustomer(String id, int cents) async {\n  await gateway.charge(id, cents);\n}', symbols: ['chargeCustomer']),
  chunk('billing', 'test/retry_policy_test.dart', "test('retries three times when the payment fails', () {\n  expect(PaymentRetryPolicy().shouldRetry(2), isTrue);\n});", symbols: ['retries three times when the payment fails'], kind: ChunkKind.test),
  chunk('billing', 'lib/refund.dart', 'Future<void> refundOrder(String orderId) async {\n  await gateway.refund(orderId);\n}', symbols: ['refundOrder']),
  chunk('billing', 'README.md', '# Billing\nThis service handles invoices and logging.', kind: ChunkKind.doc),
];
final auth = [
  chunk('auth', 'lib/login.dart', 'Future<Session> login(String email, String password) async {\n  return sessions.create(email);\n}', symbols: ['login']),
  chunk('auth', 'lib/reset.dart', 'Future<void> sendPasswordReset(String email) async {\n  await mailer.send(email, template: "reset");\n}', symbols: ['sendPasswordReset']),
];

RepoRetrieval retrievalFor(List<CodeChunk> chunks, {List<(String, ScenarioCard)> scenarios = const []}) => RepoRetrieval(
      index: Bm25Index.build(chunks),
      repoNames: {'billing': 'billing-service', 'auth': 'auth-service'},
      scenarios: scenarios,
    );

void main() {
  group('Bm25Index', () {
    final index = Bm25Index.build([...billing, ...auth]);

    test('finds the code a plain-English question is about', () {
      final hits = index.search('what happens when a payment is retried');
      expect(hits.first.chunk.path, anyOf('lib/retry_policy.dart', 'test/retry_policy_test.dart'));
    });

    test('a declared name outranks an incidental mention', () {
      final hits = index.search('refund order');
      expect(hits.first.chunk.path, 'lib/refund.dart');
    });

    test('synonyms bridge speech and code, but never match on their own', () {
      // "stop"/"end" are synonyms; only the code uses "stop"
      final idx = Bm25Index.build([
        chunk('r', 'lib/session.dart', 'void stopSession() { timer.cancel(); }', symbols: ['stopSession']),
        chunk('r', 'lib/other.dart', 'void paint() { canvas.draw(); }', symbols: ['paint']),
      ]);
      expect(idx.search('what happens when it ends the session').first.chunk.path, 'lib/session.dart');
      // a chunk reachable ONLY through a synonym of a query word does not count
      final only = Bm25Index.build([chunk('r', 'lib/x.dart', 'void stop() {}', symbols: ['stop'])]);
      expect(only.search('end'), isEmpty);
    });

    test('tests get a small boost (their names describe scenarios)', () {
      final idx = Bm25Index.build([
        chunk('r', 'lib/a.dart', 'void retry() { payment fails again }', symbols: ['retry']),
        chunk('r', 'test/a_test.dart', 'void retry() { payment fails again }', symbols: ['retry'], kind: ChunkKind.test),
      ]);
      expect(idx.search('retry payment fails').first.chunk.kind, ChunkKind.test);
    });

    test('plain-English notes make a chunk findable by words its code never uses', () {
      final plain = [chunk('r', 'lib/q.dart', 'int f(int x) => x * 2;', symbols: ['f'])];
      expect(Bm25Index.build(plain).search('doubles the invoice total'), isEmpty);
      final noted = [chunk('r', 'lib/q.dart', 'int f(int x) => x * 2;', symbols: ['f'], summary: 'Doubles the invoice total for rush orders.')];
      expect(Bm25Index.build(noted).search('doubles the invoice total').first.chunk.path, 'lib/q.dart');
    });

    test('can be limited to some repositories or a kind of chunk; empty index and empty query are safe', () {
      expect(index.search('login password', repoIds: {'billing'}), isEmpty);
      expect(index.search('login password', repoIds: {'auth'}).first.chunk.repoId, 'auth');
      expect(index.search('retry payment', kind: ChunkKind.test).every((h) => h.chunk.kind == ChunkKind.test), isTrue);
      expect(Bm25Index.empty.search('anything'), isEmpty);
      expect(index.search('the and of'), isEmpty);
    });
  });

  group('RepoRetrieval', () {
    final r = retrievalFor([...billing, ...auth]);

    test('returns a labelled, cited block and names the repo', () {
      final ctx = r.retrieve('what happens if the payment fails');
      expect(ctx.isEmpty, isFalse);
      expect(ctx.text, contains('[billing-service]'));
      expect(ctx.text, contains('lib/retry_policy.dart'));
      expect(ctx.sources.first.repoName, 'billing-service');
      expect(ctx.sources.any((s) => s.ref.startsWith('test/')), isTrue, reason: 'the test describing the scenario comes along');
    });

    test('searches several repositories at once, and can be limited to chosen ones', () {
      final both = r.retrieve('payment retry or password reset email');
      final repos = both.sources.map((s) => s.repoName).toSet();
      expect(repos, containsAll(['billing-service', 'auth-service']));
      final onlyAuth = r.retrieve('payment retry or password reset email', repoIds: {'auth'});
      expect(onlyAuth.sources.every((s) => s.repoName == 'auth-service'), isTrue);
    });

    test('respects the size budget', () {
      final big = [for (var i = 0; i < 40; i++) chunk('billing', 'lib/p$i.dart', 'payment retry ${'x' * 1500}', symbols: ['payment$i'])];
      final ctx = retrievalFor(big).retrieve('payment retry', maxChars: 1200);
      expect(ctx.text.length, lessThanOrEqualTo(1300));
      expect(ctx.sources, isNotEmpty);
    });

    test('plain-English notes are shown ahead of the code', () {
      final c = chunk('billing', 'lib/z.dart', 'class Z { void go() {} }', symbols: ['Z'], summary: 'Retries failed payments up to three times.');
      expect(retrievalFor([c]).retrieve('failed payments retried').text, contains('In plain English: Retries failed payments'));
    });

    test('unrelated questions return nothing instead of noise', () {
      expect(r.retrieve('quantum entanglement of unicorns').isEmpty, isTrue);
      expect(r.retrieve('').isEmpty, isTrue);
      expect(RepoRetrieval(index: Bm25Index.empty, repoNames: const {}).retrieve('payment').isEmpty, isTrue);
    });

    test('a matching scenario card is returned for an instant answer', () {
      const card = ScenarioCard(question: 'What happens if a payment fails?', answer: 'It is retried three times, then the customer is emailed.', sources: ['lib/retry_policy.dart']);
      final withCard = retrievalFor(billing, scenarios: [('billing', card)]);
      final ctx = withCard.retrieve('so what happens if the payment fails on our side');
      expect(ctx.scenario?.answer, contains('retried three times'));
      expect(ctx.scenarioRepo, 'billing-service');
      expect(withCard.retrieve('how do refunds work').scenario, isNull);
      expect(withCard.retrieve('payment fails', repoIds: {'auth'}).scenario, isNull); // repo switched off
    });
  });

  group('QuestionDetector', () {
    test('catches scenario questions', () {
      for (final q in [
        'What happens if the payment fails halfway through?',
        'How does it handle two users editing at once?',
        'Can it work offline when the connection drops',
        'Walk me through what happens when someone cancels their subscription',
        'Is it possible to export everything as a CSV?',
        'What if the server goes down during the demo',
      ]) {
        expect(QuestionDetector.isScenarioQuestion(q), isTrue, reason: q);
      }
    });

    test('ignores statements, small talk and fragments', () {
      for (final q in ['Yeah that sounds great.', 'Thanks for joining everyone', 'okay?', 'We handled that last week in the standup meeting.', 'Sure']) {
        expect(QuestionDetector.isScenarioQuestion(q), isFalse, reason: q);
      }
    });

    test('latest() takes the newest question from someone else, never from "You"', () {
      TranscriptEntry e(String sp, String t) => TranscriptEntry(id: t, text: t, timestamp: DateTime(2026), isFinal: true, speaker: sp);
      final lines = [
        e('Speaker 2', 'What happens if the payment fails halfway?'),
        e('You', 'Good question, how does it handle that? Let me think.'),
        e('Speaker 2', 'okay'),
      ];
      expect(QuestionDetector.latest(lines)?.text, startsWith('What happens'));
      expect(QuestionDetector.latest([e('You', 'What happens if the payment fails halfway?')]), isNull);
      expect(QuestionDetector.latest([]), isNull);
    });
  });

  group('speed', () {
    test('searching 30,000 chunks takes milliseconds', () {
      final words = ['payment', 'invoice', 'session', 'cache', 'queue', 'retry', 'limit', 'token', 'render', 'sync', 'folder', 'export'];
      final chunks = [
        for (var i = 0; i < 30000; i++)
          chunk('big', 'lib/m${i % 400}/f$i.dart', 'void handle${words[i % 12]}${words[(i * 7) % 12]}$i() { ${words[(i * 3) % 12]} ${words[(i * 5) % 12]} value$i }', symbols: ['handle${words[i % 12]}$i']),
      ];
      final index = Bm25Index.build(chunks);
      final retrieval = RepoRetrieval(index: index, repoNames: {'big': 'big'});
      retrieval.retrieve('what happens when a payment retry hits the limit'); // warm up
      final sw = Stopwatch()..start();
      const runs = 20;
      for (var i = 0; i < runs; i++) {
        retrieval.retrieve('what happens when a payment retry hits the limit');
      }
      final perCall = sw.elapsedMilliseconds / runs;
      expect(perCall, lessThan(60), reason: 'a lookup must stay far below the AI call it rides on (measured ${perCall.toStringAsFixed(1)} ms)');
    });
  });

  test('a real repository (this one) is searchable and finds the right file', () async {
    final root = Directory.current.path;
    final files = (await RepoScanner.scan(root)).where((f) => f.relPath.startsWith('lib/')).toList();
    final chunks = [for (final f in files) ...CodeChunker.chunk('mitra', f.relPath, File(f.absPath).readAsStringSync())];
    expect(chunks.length, greaterThan(300));
    final retrieval = RepoRetrieval(index: Bm25Index.build(chunks), repoNames: {'mitra': 'mitra'});
    final sw = Stopwatch()..start();
    final ctx = retrieval.retrieve('how are uploaded documents saved between launches');
    sw.stop();
    expect(ctx.sources.take(5).map((s) => s.ref).join(' '), contains('document_repository.dart'));
    expect(sw.elapsedMilliseconds, lessThan(50));
  });
}
