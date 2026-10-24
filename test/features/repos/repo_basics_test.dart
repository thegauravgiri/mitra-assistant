import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/features/repos/data/code_chunker.dart';
import 'package:mitra_assistant/features/repos/data/identifier_tokenizer.dart';
import 'package:mitra_assistant/features/repos/data/repo_scanner.dart';
import 'package:mitra_assistant/features/repos/domain/models/repo_models.dart';

void main() {
  group('IdentifierTokenizer', () {
    test('camelCase, snake_case, kebab and plain English meet at the same stems', () {
      final a = IdentifierTokenizer.tokens('PaymentRetryPolicy');
      expect(a, IdentifierTokenizer.tokens('payment_retry_policy'));
      expect(a, IdentifierTokenizer.tokens('payment-retry-policy'));
      expect(a, IdentifierTokenizer.tokens('Payment retry policy'));
      expect(a.length, 3);
    });

    test('acronyms split sensibly and plurals/tenses join', () {
      expect(IdentifierTokenizer.tokens('parseHTTPResponse'), ['pars', 'http', 'respons']);
      expect(IdentifierTokenizer.tokens('retries').single, IdentifierTokenizer.tokens('retry').single);
      expect(IdentifierTokenizer.tokens('retrying').single, IdentifierTokenizer.tokens('retry').single);
      expect(IdentifierTokenizer.tokens('retried').single, IdentifierTokenizer.tokens('retry').single);
      expect(IdentifierTokenizer.tokens('payments').single, IdentifierTokenizer.tokens('payment').single);
      expect(IdentifierTokenizer.tokens('failed').single, IdentifierTokenizer.tokens('fails').single);
      expect(IdentifierTokenizer.tokens('handling').single, IdentifierTokenizer.tokens('handle').single);
    });

    test('stop words, one-letter pieces and empty input are dropped', () {
      expect(IdentifierTokenizer.tokens('what happens if the payment fails'), ['happen', 'payment', 'fail']);
      expect(IdentifierTokenizer.tokens(''), isEmpty);
      expect(IdentifierTokenizer.tokens('a b c'), isEmpty);
    });
  });

  group('RepoScanner.wanted', () {
    test('keeps code and docs', () {
      for (final p in ['lib/main.dart', 'src/app.ts', 'README.md', 'docs/guide.rst', 'Dockerfile', 'pkg/server.go']) {
        expect(RepoScanner.wanted(p), isTrue, reason: p);
      }
    });

    test('skips dependencies, build output, lockfiles, generated and minified files', () {
      for (final p in [
        'node_modules/x/index.js', 'build/app.js', '.git/config', 'pubspec.lock', 'package-lock.json',
        'lib/model.g.dart', 'web/app.min.js', 'android/.gradle/x.gradle', 'ios/Pods/a.m', 'assets/logo.png',
      ]) {
        expect(RepoScanner.wanted(p), isFalse, reason: p);
      }
    });

    test('never reads anything that looks like a secret', () {
      for (final p in ['.env', '.env.production', 'config/credentials.json', 'keys/server.pem', 'id_rsa', 'secrets.yaml', 'deploy/app.key']) {
        expect(RepoScanner.wanted(p), isFalse, reason: p);
      }
    });
  });

  test('scan walks a folder, applies the rules, skips big files, and gives stable relative paths', () async {
    final dir = await Directory.systemTemp.createTemp('scan_test');
    addTearDown(() => dir.delete(recursive: true));
    Future<void> write(String rel, String content) async {
      final f = File('${dir.path}/$rel');
      await f.parent.create(recursive: true);
      await f.writeAsString(content);
    }

    await write('lib/a.dart', 'class A {}');
    await write('lib/sub/b.dart', 'class B {}');
    await write('README.md', '# Hi');
    await write('node_modules/x.js', 'x');
    await write('.env', 'SECRET=1');
    await write('big.dart', 'a' * (RepoScanner.maxFileBytes + 1));
    await write('empty.dart', '');

    final files = await RepoScanner.scan(dir.path);
    expect(files.map((f) => f.relPath), ['README.md', 'lib/a.dart', 'lib/sub/b.dart']);
    expect(files.first.stamp, contains(':'));
    expect(() => RepoScanner.scan('${dir.path}/missing'), throwsException);
  });

  group('CodeChunker', () {
    const dartFile = '''
import 'dart:io';

/// Retries a failed payment up to three times.
class PaymentRetryPolicy {
  final int maxAttempts;

  PaymentRetryPolicy(this.maxAttempts);

  Future<bool> shouldRetry(int attempt, Exception error) async {
    if (attempt >= maxAttempts) return false;
    return error is SocketException;
  }
}

Future<void> chargeCustomer(String id, int cents) async {
  final policy = PaymentRetryPolicy(3);
  for (var i = 0; i < 3; i++) {
    try {
      await sendCharge(id, cents);
      return;
    } on Exception catch (e) {
      if (!await policy.shouldRetry(i, e)) rethrow;
    }
  }
}
''';

    test('chunks carry path, 1-based line ranges, kind and declared symbols', () {
      final chunks = CodeChunker.chunk('r1', 'lib/payments.dart', dartFile);
      expect(chunks, isNotEmpty);
      expect(chunks.first.path, 'lib/payments.dart');
      expect(chunks.first.startLine, 1);
      expect(chunks.last.endLine, dartFile.split('\n').length);
      expect(chunks.every((c) => c.kind == ChunkKind.code), isTrue);
      final all = chunks.expand((c) => c.symbols).toSet();
      expect(all, contains('PaymentRetryPolicy'));
      expect(all, contains('chargeCustomer'));
      expect(chunks.map((c) => c.text).join('\n'), contains('class PaymentRetryPolicy'));
    });

    test('chunks tile the file without gaps or overlaps', () {
      final chunks = CodeChunker.chunk('r1', 'lib/payments.dart', dartFile);
      for (var i = 1; i < chunks.length; i++) {
        expect(chunks[i].startLine, chunks[i - 1].endLine + 1, reason: 'chunk $i follows chunk ${i - 1}');
      }
    });

    test('tests are recognised, and their test names become symbols', () {
      const t = '''
void main() {
  test('retries three times when the payment fails', () {
    expect(true, isTrue);
  });

  test('gives up after the third failure', () {
    expect(true, isTrue);
  });
}
''';
      final chunks = CodeChunker.chunk('r1', 'test/payments_test.dart', t);
      expect(chunks.every((c) => c.kind == ChunkKind.test), isTrue);
      final syms = chunks.expand((c) => c.symbols).join(' ');
      expect(syms, contains('retries three times'));
    });

    test('markdown is split at headings and marked as docs', () {
      const md = '# Billing\nIntro text.\n\n## Retries\nWe retry failed payments three times.\n\n## Refunds\nRefunds take five days.\n';
      final chunks = CodeChunker.chunk('r1', 'docs/billing.md', md);
      expect(chunks.every((c) => c.kind == ChunkKind.doc), isTrue);
      expect(chunks.map((c) => c.text).join('\n'), contains('Refunds take five days'));
    });

    test('very long pieces are cut at blank lines within the size cap', () {
      final big = List.generate(200, (i) => 'final value$i = compute($i); // some filler text to take up room').join('\n');
      final chunks = CodeChunker.chunk('r1', 'lib/big.dart', 'class Big {\n$big\n}\n');
      expect(chunks.length, greaterThan(3));
      expect(chunks.every((c) => c.text.length <= CodeChunker.maxChars + 200), isTrue);
    });

    test('empty and whitespace-only files give no chunks', () {
      expect(CodeChunker.chunk('r1', 'a.dart', ''), isEmpty);
      expect(CodeChunker.chunk('r1', 'a.dart', '\n  \n\n'), isEmpty);
    });
  });

  test('models round-trip through JSON, and an interrupted index is not restored as "indexing"', () {
    final data = RepoData(
      source: RepoSource(id: 'r1', name: 'billing', path: '/x/billing', status: RepoStatus.ready, fileCount: 2, chunkCount: 1, indexedAt: DateTime(2026, 10, 24)),
      chunks: [
        const CodeChunk(repoId: 'r1', path: 'a.dart', startLine: 1, endLine: 9, kind: ChunkKind.test, symbols: ['x'], text: 'code', summary: 'does a thing'),
      ],
      files: const {'a.dart': '10:20'},
      scenarios: const [ScenarioCard(question: 'What if it fails?', answer: 'It retries.', sources: ['a.dart'])],
    );
    final back = RepoData.fromJson(data.toJson());
    expect(back.source.name, 'billing');
    expect(back.chunks.single.repoId, 'r1');
    expect(back.chunks.single.summary, 'does a thing');
    expect(back.chunks.single.ref, 'a.dart:1-9');
    expect(back.files['a.dart'], '10:20');
    expect(back.scenarios.single.answer, 'It retries.');

    final interrupted = RepoSource.fromJson(const RepoSource(id: 'i', name: 'n', path: '/p').toJson());
    expect(interrupted.status, RepoStatus.error);
    expect(interrupted.error, contains('interrupted'));
  });
}
