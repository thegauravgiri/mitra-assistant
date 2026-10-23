import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/features/coaching/data/digest_service.dart';
import 'package:mitra_assistant/features/coaching/domain/models/coaching_feedback.dart';
import 'package:mitra_assistant/features/coaching/domain/models/meeting_digest.dart';
import 'package:mitra_assistant/features/history/domain/models/meeting_session.dart';

const good = '''
{"overview":"Budget review. Raj asked for two hires; the group agreed to wait for the forecast.",
 "topics":[{"name":"Q3 budget","summary":"Forecast shows a 12% shortfall.","raisedBy":"Sneha"},"Hiring"],
 "decisions":[{"decision":"Freeze hiring until Q4","rationale":"Shortfall in the forecast","evidence":"we freeze hiring until Q4"},"Open a pricing review"],
 "actionItems":[{"owner":"Raj","task":"Send forecast","due":"by Friday","evidence":"I will send the forecast"},{"owner":null,"task":"Book room"}],
 "openQuestions":[{"asker":"Sneha","question":"Who approves the spend?","context":"raised after the shortfall"}],
 "risks":["Launch may slip"],
 "keyFacts":["Shortfall: 12%"]}
''';

const transcriptShort = 'Sneha: we freeze hiring until Q4. Raj: I will send the forecast. Sneha: Who approves the spend?';

void main() {
  group('DigestService.parse (v2)', () {
    test('parses the full schema, including rationale, due dates, context, risks and key facts', () {
      final d = DigestService.parse(good)!;
      expect(d.summary, startsWith('Budget review.'));
      expect(d.topics.first.summary, 'Forecast shows a 12% shortfall.');
      expect(d.topics.map((t) => t.name), ['Q3 budget', 'Hiring']);
      expect(d.decisions.first.rationale, 'Shortfall in the forecast');
      expect(d.decisions.last.text, 'Open a pricing review'); // plain string accepted
      expect(d.actionItems.first.due, 'by Friday');
      expect(d.actionItems.last.owner, isNull);
      expect(d.openQuestions.single.context, 'raised after the shortfall');
      expect(d.risks, ['Launch may slip']);
      expect(d.keyFacts, ['Shortfall: 12%']);
    });

    test('still reads the older, thinner format ("summary" + string decisions)', () {
      final d = DigestService.parse('{"summary":"Old notes","decisions":["Ship Friday"],"topics":["Hiring"]}')!;
      expect(d.summary, 'Old notes');
      expect(d.decisions.single.text, 'Ship Friday');
      expect(d.topics.single.name, 'Hiring');
    });

    test('handles fences, prose, the string "null", wrong types, caps and garbage', () {
      expect(DigestService.parse('```json\n$good\n```'), isNotNull);
      expect(DigestService.parse('Here: $good Thanks'), isNotNull);
      expect(DigestService.parse('{"overview":"x","actionItems":[{"owner":"null","task":"t","due":"null"}]}')!.actionItems.single.owner, isNull);
      final many = '{"decisions":[${List.generate(30, (i) => '"d$i"').join(',')}]}';
      expect(DigestService.parse(many)!.decisions.length, 15);
      expect(DigestService.parse('nope'), isNull);
      expect(DigestService.parse(''), isNull);
      expect(DigestService.parse('{"overview":"","topics":[]}'), isNull);
    });
  });

  group('evidence is verified against the transcript', () {
    test('an invented quote is removed, a real one kept, the item stays', () {
      final d = DigestService.verifyEvidence(DigestService.parse(good)!, transcriptShort);
      expect(d.decisions.first.evidence, 'we freeze hiring until Q4'); // real
      expect(d.actionItems.first.evidence, 'I will send the forecast'); // real
      final fake = DigestService.verifyEvidence(
        MeetingDigest(
          decisions: const [DigestDecision('Hire two', evidence: 'we absolutely must hire two people now')],
          generatedAt: DateTime(2026),
        ),
        transcriptShort,
      );
      expect(fake.decisions.single.text, 'Hire two');
      expect(fake.decisions.single.evidence, isNull);
    });
  });

  group('long meetings', () {
    String lines(int n, {String prefix = 'line'}) => List.generate(n, (i) => 'Sneha: $prefix $i ${'word ' * 20}').join('\n');

    test('splitSegments keeps short transcripts whole, splits long ones on line boundaries with overlap', () {
      expect(DigestService.splitSegments('short', maxChars: 100), ['short']);
      final t = lines(400);
      final parts = DigestService.splitSegments(t, maxChars: 5000, overlapChars: 600);
      expect(parts.length, greaterThan(3));
      expect(parts.every((p) => p.length <= 5000 + 200), isTrue);
      // every original line appears somewhere (nothing is lost to trimming)
      final joined = parts.join('\n');
      for (var i = 0; i < 400; i += 37) {
        expect(joined, contains('line $i '));
      }
      // consecutive parts share their boundary lines
      final lastLineOfFirst = parts.first.split('\n').last;
      expect(parts[1], contains(lastLineOfFirst));
    });

    test('a long meeting is read in parts, then merged by a final call', () async {
      final calls = <String>[];
      final digest = await DigestService().generate(
        labelledTranscript: lines(400),
        singlePassMaxChars: 5000,
        segmentChars: 5000,
        generate: (system, prompt) async {
          if (system.contains('CONSECUTIVE PARTS')) {
            calls.add('merge');
            expect(prompt, contains('Part 1 notes:'));
            return '{"overview":"Whole meeting overview","topics":[{"name":"Merged topic","summary":"across parts"}]}';
          }
          calls.add('part');
          expect(system, contains('ONE PART'));
          return '{"overview":"part","topics":[{"name":"T${calls.length}","summary":"s"}],"openQuestions":[{"question":"q${calls.length}"}]}';
        },
      );
      expect(calls.where((c) => c == 'part').length, greaterThan(2));
      expect(calls.last, 'merge');
      expect(digest.summary, 'Whole meeting overview');
      expect(digest.topics.single.name, 'Merged topic');
    });

    test('if the merge call fails the parts are merged in code, so nothing is lost', () async {
      var n = 0;
      final digest = await DigestService().generate(
        labelledTranscript: lines(400),
        singlePassMaxChars: 5000,
        segmentChars: 5000,
        generate: (system, prompt) async {
          if (system.contains('CONSECUTIVE PARTS')) throw Exception('rate limited');
          n++;
          return jsonEncode({
            'overview': 'part $n',
            'topics': [
              {'name': 'Budget', 'summary': 'said in part $n'},
              {'name': 'Topic $n', 'summary': 's'},
            ],
            'decisions': [
              {'decision': 'Same decision'},
              {'decision': 'Decision $n'},
            ],
            'openQuestions': [
              {'question': 'only last part counts $n'},
            ],
          });
        },
      );
      expect(digest.topics.where((t) => t.name == 'Budget').length, 1); // same topic merged
      expect(digest.topics.firstWhere((t) => t.name == 'Budget').summary, contains('part 1'));
      expect(digest.topics.firstWhere((t) => t.name == 'Budget').summary, contains('part 2'));
      expect(digest.decisions.where((d) => d.text == 'Same decision').length, 1); // deduped
      expect(digest.openQuestions.length, 1); // an earlier part's question may be answered later
      expect(digest.summary, contains('part 1'));
    });

    test('a part that fails is skipped; all parts failing throws', () async {
      var i = 0;
      final ok = await DigestService().generate(
        labelledTranscript: lines(400),
        singlePassMaxChars: 5000,
        segmentChars: 5000,
        generate: (system, prompt) async {
          if (system.contains('CONSECUTIVE PARTS')) throw Exception('x');
          if (i++ == 0) throw Exception('first part failed');
          return '{"overview":"ok","topics":["T"]}';
        },
      );
      expect(ok.topics, isNotEmpty);

      expect(
        () => DigestService().generate(
          labelledTranscript: lines(400),
          singlePassMaxChars: 5000,
          segmentChars: 5000,
          generate: (_, _) async => throw Exception('down'),
        ),
        throwsException,
      );
    });
  });

  test('a short meeting is one call and returns verified notes', () async {
    var calls = 0;
    final d = await DigestService().generate(
      labelledTranscript: transcriptShort,
      generate: (system, prompt) async {
        calls++;
        expect(prompt, contains('Meeting transcript:'));
        return good;
      },
    );
    expect(calls, 1);
    expect(d.decisions.first.evidence, isNotNull);
  });

  test('generate throws when the model returns nothing usable', () async {
    expect(
      () => DigestService().generate(labelledTranscript: 'A: hi', generate: (_, _) async => 'nope'),
      throwsException,
    );
  });

  test('session JSON round-trips the richer digest; old JSON still loads', () {
    final s = MeetingSession(
      id: 's',
      title: 'T',
      aiSummary: '',
      startTime: DateTime(2026),
      endTime: DateTime(2026),
      entries: const [],
      digest: MeetingDigest(
        summary: 'x',
        topics: const [DigestTopic('A', summary: 'said things')],
        decisions: const [DigestDecision('d', rationale: 'because', evidence: 'quote')],
        actionItems: const [DigestAction('t', owner: 'Raj', due: 'Friday')],
        openQuestions: const [DigestQuestion('q', context: 'ctx')],
        risks: const ['r'],
        keyFacts: const ['f'],
        generatedAt: DateTime(2026),
      ),
      meSpeakerKey: 'Speaker 1',
      feedback: CoachingFeedback(
        strengths: const [FeedbackItem('Clear', evidence: 'we should ship')],
        improvements: const [FeedbackItem('Slow down', tip: 'pause')],
        generatedAt: DateTime(2026),
      ),
    );
    final back = MeetingSession.fromJson(s.toJson());
    expect(back.digest!.decisions.single.rationale, 'because');
    expect(back.digest!.actionItems.single.due, 'Friday');
    expect(back.digest!.topics.single.summary, 'said things');
    expect(back.digest!.risks, ['r']);
    expect(back.digest!.keyFacts, ['f']);
    expect(back.feedback!.improvements.single.tip, 'pause');

    // notes saved before this change: decisions were plain strings
    final old = MeetingSession.fromJson({
      'id': 'o',
      'title': 'Old',
      'aiSummary': '',
      'startTime': DateTime(2026).toIso8601String(),
      'endTime': DateTime(2026).toIso8601String(),
      'digest': {
        'summary': 'old',
        'decisions': ['Ship Friday'],
        'topics': [{'name': 'X'}],
        'actionItems': [{'task': 't'}],
        'openQuestions': [{'question': 'q'}],
        'generatedAt': DateTime(2026).toIso8601String(),
      },
    });
    expect(old.digest!.decisions.single.text, 'Ship Friday');
    expect(old.feedback, isNull);
  });
}
