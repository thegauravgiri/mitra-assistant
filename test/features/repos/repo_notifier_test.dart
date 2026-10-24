import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/core/constants/app_constants.dart';
import 'package:mitra_assistant/features/ai_engine/domain/models/insight.dart';
import 'package:mitra_assistant/features/ai_engine/providers/ai_providers.dart';
import 'package:mitra_assistant/features/repos/domain/models/repo_models.dart';
import 'package:mitra_assistant/features/repos/providers/repo_providers.dart';
import 'package:mitra_assistant/features/settings/providers/settings_providers.dart';
import 'package:mitra_assistant/features/transcription/domain/models/transcript_entry.dart';
import 'package:mitra_assistant/features/transcription/providers/transcription_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

String block(String name, String extra) => '''
class $name {
${List.generate(25, (i) => '  int $extra$i = $i; // $name $extra filler number $i').join('\n')}
}
''';

Future<Directory> makeRepo() async {
  final dir = await Directory.systemTemp.createTemp('notifier_repo');
  Future<void> w(String rel, String c) async {
    final f = File('${dir.path}/$rel');
    await f.parent.create(recursive: true);
    await f.writeAsString(c);
  }

  await w('lib/payment_service.dart', 'class PaymentRetryPolicy {\n  final int maxAttempts = 3;\n  bool shouldRetry(int attempt) => attempt < maxAttempts;\n}\n\nFuture<void> chargeCustomer(String id) async {\n  // retries a failed payment up to three times, then emails the customer\n  for (var i = 0; i < 3; i++) { await gateway.charge(id); }\n}\n${block('Padding', 'pad')}');
  await w('lib/refunds.dart', 'Future<void> refundOrder(String orderId) async {\n  await gateway.refund(orderId);\n}\n${block('RefundPadding', 'ref')}');
  return dir;
}

class _FakeTranscription extends TranscriptionNotifier {
  _FakeTranscription(super.ref);
  void push(TranscriptEntry e) => state = state.copyWith(entries: [...state.entries, e]);
}

TranscriptEntry say(String speaker, String text, {String? id}) =>
    TranscriptEntry(id: id ?? '$speaker$text', text: text, timestamp: DateTime(2026, 10, 24), isFinal: true, speaker: speaker);

String notesJson(Iterable<String> paths) => jsonEncode({
      'files': [
        for (final p in paths)
          {
            'path': p,
            'summary': p.contains('payment') ? 'Charges customers and retries failed payments.' : 'Refunds orders.',
            'behaviours': ['Retries three times', 'Then emails the customer'],
            'scenarios': p.contains('payment')
                ? [
                    {'question': 'What happens if a payment fails halfway through?', 'answer': 'We retry it three times and then email the customer, so nothing is lost silently.'},
                  ]
                : [],
          },
      ],
    });

Future<ProviderContainer> container({bool withKey = true, List<Override> overrides = const []}) async {
  SharedPreferences.setMockInitialValues({if (withKey) AppConstants.prefGeminiApiKey: 'test-key'});
  final c = ProviderContainer(overrides: [
    repoNotifierProvider.overrideWith((ref) => RepoNotifier(
          ref,
          persist: false,
          notesGenerator: (system, prompt) async {
            final paths = RegExp(r'=== FILE: (\S+) ===').allMatches(prompt).map((m) => m.group(1)!);
            return notesJson(paths);
          },
        )),
    ...overrides,
  ]);
  addTearDown(c.dispose);
  c.read(settingsNotifierProvider); // start loading the saved key
  await Future<void>.delayed(const Duration(milliseconds: 150));
  return c;
}

void main() {
  test('adding a repository reads it, makes it searchable, and rejects the same folder twice', () async {
    final dir = await makeRepo();
    addTearDown(() => dir.delete(recursive: true));
    final c = await container();
    final n = c.read(repoNotifierProvider.notifier);

    expect(await n.addRepo(dir.path), isTrue);
    final repo = c.read(repoNotifierProvider).repos.single;
    expect(repo.status, RepoStatus.ready);
    expect(repo.fileCount, 2);
    expect(c.read(repoNotifierProvider).busyId, isNull);

    final ctx = n.contextFor('what happens when a payment is retried');
    expect(ctx.isEmpty, isFalse);
    expect(ctx.sources.first.ref, startsWith('lib/payment_service.dart'));

    expect(await n.addRepo(dir.path), isFalse);
    expect(c.read(repoNotifierProvider).error, contains('already connected'));
    expect(c.read(repoNotifierProvider).repos.length, 1);
  });

  test('switching a repository off removes it from searches; removing it deletes it', () async {
    final dir = await makeRepo();
    addTearDown(() => dir.delete(recursive: true));
    final c = await container();
    final n = c.read(repoNotifierProvider.notifier);
    await n.addRepo(dir.path);
    final id = c.read(repoNotifierProvider).repos.single.id;

    expect(n.hasEnabledRepos, isTrue);
    await n.setEnabled(id, false);
    expect(n.hasEnabledRepos, isFalse);
    expect(n.contextFor('refund order').isEmpty, isTrue);
    await n.setEnabled(id, true);
    expect(n.contextFor('refund order').sources.first.ref, startsWith('lib/refunds.dart'));

    await n.remove(id);
    expect(c.read(repoNotifierProvider).repos, isEmpty);
    expect(n.contextFor('refund order').isEmpty, isTrue);
  });

  test('two repositories are searched together', () async {
    final a = await makeRepo();
    final b = await Directory.systemTemp.createTemp('second_repo');
    await File('${b.path}/login.dart').writeAsString('Future<Session> login(String email, String password) async {\n  return sessions.create(email);\n}\n${block('Pad', 'p')}');
    addTearDown(() async {
      await a.delete(recursive: true);
      await b.delete(recursive: true);
    });
    final c = await container();
    final n = c.read(repoNotifierProvider.notifier);
    await n.addRepo(a.path);
    await n.addRepo(b.path);
    expect(c.read(repoNotifierProvider).repos.length, 2);
    final ctx = n.contextFor('payment retry versus login password');
    expect(ctx.sources.map((s) => s.repoName).toSet().length, 2);
  });

  test('a missing folder ends up as an error on that repository, not a crash', () async {
    final c = await container();
    final n = c.read(repoNotifierProvider.notifier);
    await n.addRepo('/definitely/not/a/folder');
    final repo = c.read(repoNotifierProvider).repos.single;
    expect(repo.status, RepoStatus.error);
    expect(repo.error, contains('not found'));
    expect(n.hasEnabledRepos, isFalse);
  });

  test('building notes needs the Gemini key; with it, notes and ready answers are stored', () async {
    final dir = await makeRepo();
    addTearDown(() => dir.delete(recursive: true));

    final noKey = await container(withKey: false);
    await noKey.read(repoNotifierProvider.notifier).addRepo(dir.path);
    await noKey.read(repoNotifierProvider.notifier).buildNotes(noKey.read(repoNotifierProvider).repos.single.id);
    expect(noKey.read(repoNotifierProvider).error, contains('Gemini API key'));

    final c = await container();
    final n = c.read(repoNotifierProvider.notifier);
    await n.addRepo(dir.path);
    await n.buildNotes(c.read(repoNotifierProvider).repos.single.id);
    expect(c.read(repoNotifierProvider).error, isNull);
    expect(c.read(repoNotifierProvider).repos.single.summarisedFiles, greaterThan(0));

    // the prepared answer is now found by a client's own wording, with no AI call
    final ctx = n.contextFor('so what happens if the payment fails on your side');
    expect(ctx.scenario?.answer, contains('retry it three times'));
    // and the plain-English notes sit ahead of the code
    expect(n.contextFor('refund order').text, contains('In plain English: Refunds orders'));

    // running it again has nothing new to explain
    await n.buildNotes(c.read(repoNotifierProvider).repos.single.id);
    expect(c.read(repoNotifierProvider).error, contains('already has notes'));
  });

  test('refresh picks up edited files', () async {
    final dir = await makeRepo();
    addTearDown(() => dir.delete(recursive: true));
    final c = await container();
    final n = c.read(repoNotifierProvider.notifier);
    await n.addRepo(dir.path);
    expect(n.contextFor('invoice reminder emails').sources.any((s) => s.ref.startsWith('lib/reminders.dart')), isFalse);

    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await File('${dir.path}/lib/reminders.dart').writeAsString('Future<void> sendInvoiceReminder(String id) async {\n  await mailer.send(id, "invoice reminder");\n}\n${block('R', 'r')}');
    await n.refresh(c.read(repoNotifierProvider).repos.single.id);
    expect(n.contextFor('invoice reminder emails').sources.first.ref, startsWith('lib/reminders.dart'));
  });

  group('live path: a client asks, the answer appears with no AI call', () {
    Future<(ProviderContainer, _FakeTranscription)> setup() async {
      final dir = await makeRepo();
      addTearDown(() => dir.delete(recursive: true));
      late _FakeTranscription fake;
      final c = await container(overrides: [
        transcriptionNotifierProvider.overrideWith((ref) => fake = _FakeTranscription(ref)),
      ]);
      final repos = c.read(repoNotifierProvider.notifier);
      await repos.addRepo(dir.path);
      await repos.buildNotes(c.read(repoNotifierProvider).repos.single.id);
      c.read(aiNotifierProvider.notifier).startPeriodicAnalysis();
      addTearDown(() => c.read(aiNotifierProvider.notifier).stopPeriodicAnalysis());
      return (c, fake);
    }

    test('a scenario question from the client shows the prepared answer immediately', () async {
      final (c, fake) = await setup();
      fake.push(say('Speaker 2', 'What happens if a payment fails halfway through?'));
      final insights = c.read(aiNotifierProvider).insights;
      expect(insights, isNotEmpty);
      expect(insights.first.category, InsightCategory.answer);
      expect(insights.first.description, contains('retry it three times'));
      expect(insights.first.description, contains('payment_service.dart'));
      c.read(aiNotifierProvider.notifier).stopPeriodicAnalysis(); // before the follow-up model call
    });

    test('the user\'s own words, statements, and switched-off repos do nothing', () async {
      final (c, fake) = await setup();
      fake.push(say('You', 'What happens if a payment fails halfway through?'));
      fake.push(say('Speaker 2', 'Thanks, that sounds good to me.'));
      expect(c.read(aiNotifierProvider).insights, isEmpty);

      await c.read(repoNotifierProvider.notifier).setEnabled(c.read(repoNotifierProvider).repos.single.id, false);
      fake.push(say('Speaker 2', 'And what happens if a payment fails halfway through again?', id: 'second'));
      expect(c.read(aiNotifierProvider).insights, isEmpty);
      c.read(aiNotifierProvider.notifier).stopPeriodicAnalysis();
    });

    test('the same question is not answered twice', () async {
      final (c, fake) = await setup();
      final q = say('Speaker 2', 'What happens if a payment fails halfway through?', id: 'q1');
      fake.push(q);
      fake.push(say('You', 'Good question, let me explain.'));
      expect(c.read(aiNotifierProvider).insights.length, 1);
      c.read(aiNotifierProvider.notifier).stopPeriodicAnalysis();
    });
  });
}
