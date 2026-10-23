import 'dart:convert';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/name_canonicalizer.dart';
import '../../../core/utils/text_similarity.dart';
import '../../ai_engine/data/prompt_templates.dart';
import '../domain/models/meeting_digest.dart';

typedef GenerateFn = Future<String> Function(String systemPrompt, String prompt);

/// Builds a [MeetingDigest] from a speaker-labelled transcript. The LLM call is
/// injected so everything else is testable without network.
///
/// Short meetings take one pass. Long ones are split into parts (so nothing in
/// the middle is lost to trimming), each part is analysed in full detail, and a
/// final step merges the parts. If that merge fails, the parts are merged in
/// code, so a long meeting still gets complete notes.
class DigestService {
  Future<MeetingDigest> generate({
    required String labelledTranscript,
    required GenerateFn generate,
    DateTime? now,
    int singlePassMaxChars = AppConstants.digestSinglePassChars,
    int segmentChars = AppConstants.digestSegmentChars,
  }) async {
    final transcript = labelledTranscript.trim();
    MeetingDigest? digest;

    if (transcript.length <= singlePassMaxChars) {
      digest = parse(
        await generate(PromptTemplates.digestSystemPrompt, PromptTemplates.buildDigestPrompt(transcript)),
        now: now,
      );
    } else {
      final parts = splitSegments(transcript, maxChars: segmentChars);
      final partNotes = <MeetingDigest>[];
      final partJson = <String>[];
      for (var i = 0; i < parts.length; i++) {
        try {
          final raw = await generate(
            PromptTemplates.digestSegmentSystemPrompt,
            PromptTemplates.buildDigestSegmentPrompt(i + 1, parts.length, parts[i]),
          );
          final d = parse(raw, now: now);
          if (d != null) {
            partNotes.add(d);
            partJson.add(jsonEncode(d.toJson()..remove('generatedAt')));
          }
        } catch (e) {
          AppLogger.error('Digest part ${i + 1}/${parts.length} failed', e);
        }
      }
      if (partNotes.isEmpty) throw Exception('Gemini returned no usable meeting notes');

      if (partNotes.length == 1) {
        digest = partNotes.first;
      } else {
        try {
          digest = parse(
            await generate(PromptTemplates.digestMergeSystemPrompt, PromptTemplates.buildDigestMergePrompt(partJson)),
            now: now,
          );
        } catch (e) {
          AppLogger.error('Digest merge failed, merging in code', e);
        }
        digest ??= mergeDigests(partNotes, now: now);
      }
    }

    if (digest == null) throw Exception('Gemini returned no usable meeting notes');
    return verifyEvidence(digest, transcript);
  }

  /// Keeps the start and end of a very long transcript (used by coaching, which
  /// needs the person's own lines more than the whole meeting).
  static String trim(String t, {int max = 60000}) {
    if (t.length <= max) return t;
    final half = max ~/ 2;
    return '${t.substring(0, half)}\n[...]\n${t.substring(t.length - half)}';
  }

  /// Splits on line boundaries into parts of at most [maxChars], each starting
  /// with a little of the previous part so a point made across the boundary is
  /// not cut in half.
  static List<String> splitSegments(String transcript, {int maxChars = 22000, int overlapChars = 1500}) {
    if (transcript.length <= maxChars) return [transcript];
    final lines = transcript.split('\n');
    final parts = <String>[];
    var current = <String>[];
    var size = 0;
    for (final line in lines) {
      if (size + line.length + 1 > maxChars && current.isNotEmpty) {
        parts.add(current.join('\n'));
        // carry whole lines from the end of this part into the next
        final carry = <String>[];
        var carried = 0;
        for (var i = current.length - 1; i >= 0 && carried + current[i].length <= overlapChars; i--) {
          carry.insert(0, current[i]);
          carried += current[i].length + 1;
        }
        current = carry;
        size = carried;
      }
      current.add(line);
      size += line.length + 1;
    }
    if (current.isNotEmpty) parts.add(current.join('\n'));
    return parts;
  }

  /// Code-side merge, used if the model's merge step fails.
  static MeetingDigest mergeDigests(List<MeetingDigest> parts, {DateTime? now}) {
    final topicNames = NameCanonicalizer();
    final topics = <String, DigestTopic>{};
    String norm(String t) => TextSimilarity.normalize(t);

    for (final p in parts) {
      for (final t in p.topics) {
        final key = topicNames.canonical(t.name);
        if (key.isEmpty) continue;
        final existing = topics[key];
        topics[key] = existing == null
            ? t
            : DigestTopic(
                existing.name,
                raisedBy: existing.raisedBy ?? t.raisedBy,
                summary: [existing.summary, t.summary].whereType<String>().join(' '),
              );
      }
    }

    List<T> dedupe<T>(Iterable<T> items, String Function(T) key) {
      final seen = <String>{};
      return [for (final i in items) if (seen.add(norm(key(i)))) i];
    }

    return MeetingDigest(
      summary: parts.map((p) => p.summary).where((s) => s.isNotEmpty).join(' '),
      topics: topics.values.take(15).toList(),
      decisions: dedupe(parts.expand((p) => p.decisions), (d) => d.text).take(15).toList(),
      actionItems: dedupe(parts.expand((p) => p.actionItems), (a) => a.task).take(20).toList(),
      // unanswered in the last part only is the safe reading of "still open"
      openQuestions: dedupe(parts.last.openQuestions, (q) => q.question).take(12).toList(),
      risks: dedupe(parts.expand((p) => p.risks), (r) => r).take(8).toList(),
      keyFacts: dedupe(parts.expand((p) => p.keyFacts), (f) => f).take(15).toList(),
      generatedAt: now ?? DateTime.now(),
    );
  }

  /// Removes any evidence quote that is not actually in the transcript, so an
  /// invented quote is never shown. The item itself is kept.
  static MeetingDigest verifyEvidence(MeetingDigest d, String transcript) {
    final hay = TextSimilarity.normalize(transcript);
    String? ok(String? quote) {
      if (quote == null) return null;
      final n = TextSimilarity.normalize(quote);
      if (n.isEmpty || n.split(RegExp(r'\s+')).length > 20) return null;
      return hay.contains(n) ? quote : null;
    }

    return MeetingDigest(
      summary: d.summary,
      topics: d.topics,
      decisions: [for (final x in d.decisions) DigestDecision(x.text, rationale: x.rationale, evidence: ok(x.evidence))],
      actionItems: [
        for (final a in d.actionItems) DigestAction(a.task, owner: a.owner, due: a.due, evidence: ok(a.evidence)),
      ],
      openQuestions: d.openQuestions,
      risks: d.risks,
      keyFacts: d.keyFacts,
      generatedAt: d.generatedAt,
    );
  }

  /// Defensive like the other Gemini parsers: strips fences, falls back to the
  /// first `{...}` block, tolerates wrong types. Null if nothing usable.
  static MeetingDigest? parse(String raw, {DateTime? now}) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    text = text
        .replaceAll(RegExp(r'^```(json)?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*```$'), '');

    dynamic parsed;
    try {
      parsed = jsonDecode(text);
    } catch (_) {
      final m = RegExp(r'\{.*\}', dotAll: true).firstMatch(text);
      if (m != null) {
        try {
          parsed = jsonDecode(m.group(0)!);
        } catch (_) {}
      }
    }
    if (parsed is! Map) return null;

    String? clean(dynamic v) {
      if (v is! String) return null;
      final t = v.trim();
      return t.isEmpty || t.toLowerCase() == 'null' ? null : t;
    }

    List<T> mapList<T>(dynamic v, T? Function(dynamic) f, int max) {
      if (v is! List) return [];
      return [
        for (final item in v)
          if (f(item) != null) f(item) as T,
      ].take(max).toList();
    }

    final digest = MeetingDigest(
      summary: clean(parsed['overview']) ?? clean(parsed['summary']) ?? '',
      topics: mapList(parsed['topics'], (t) {
        if (t is String) return clean(t) == null ? null : DigestTopic(clean(t)!);
        if (t is Map && clean(t['name']) != null) {
          return DigestTopic(clean(t['name'])!, raisedBy: clean(t['raisedBy']), summary: clean(t['summary']));
        }
        return null;
      }, 15),
      decisions: mapList(parsed['decisions'], (d) {
        if (d is String) return clean(d) == null ? null : DigestDecision(clean(d)!);
        if (d is Map) {
          final text = clean(d['decision']) ?? clean(d['text']);
          return text == null ? null : DigestDecision(text, rationale: clean(d['rationale']), evidence: clean(d['evidence']));
        }
        return null;
      }, 15),
      actionItems: mapList(parsed['actionItems'], (a) {
        if (a is String) return clean(a) == null ? null : DigestAction(clean(a)!);
        if (a is Map && clean(a['task']) != null) {
          return DigestAction(clean(a['task'])!, owner: clean(a['owner']), due: clean(a['due']), evidence: clean(a['evidence']));
        }
        return null;
      }, 20),
      openQuestions: mapList(parsed['openQuestions'], (q) {
        if (q is String) return clean(q) == null ? null : DigestQuestion(clean(q)!);
        if (q is Map && clean(q['question']) != null) {
          return DigestQuestion(clean(q['question'])!, asker: clean(q['asker']), context: clean(q['context']));
        }
        return null;
      }, 12),
      risks: mapList(parsed['risks'], (r) => clean(r), 8),
      keyFacts: mapList(parsed['keyFacts'], (f) => clean(f), 15),
      generatedAt: now ?? DateTime.now(),
    );
    return digest.isEmpty ? null : digest;
  }
}
