import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/utils/logger.dart';
import '../../ai_engine/domain/models/insight.dart';
import '../../history/domain/models/meeting_session.dart';
import '../domain/models/coaching_feedback.dart';
import 'session_metrics.dart';

/// Writes per-meeting artefacts under `<Documents>/MitraAssistant/`:
/// - `reports/*.md`  coaching report; the folder can be fed to Graphify offline
/// - `sessions/*.json` full session (timings, insights, latency) for evaluation
class ReportExportService {
  static String buildMarkdown(MeetingSession session) {
    final date = DateFormat('yyyy-MM-dd HH:mm').format(session.startTime);
    final mins = session.endTime.difference(session.startTime).inMinutes;
    final b = StringBuffer()
      ..writeln('# ${session.title}')
      ..writeln()
      ..writeln('- Date: $date')
      ..writeln('- Duration: $mins min')
      ..writeln();

    final report = session.coachingReport;
    final allMetrics = metricsOf(session);
    if (allMetrics.isNotEmpty) {
      b
        ..writeln('## Participation')
        ..writeln()
        ..writeln('| Speaker | Talk share | Talk time (s) | Turns | Words | Interrupted others | Was interrupted |')
        ..writeln('|---|---|---|---|---|---|---|');
      for (final m in allMetrics) {
        b.writeln(
          '| ${session.nameFor(m.speakerKey)} | ${m.talkSharePct.toStringAsFixed(0)}% | '
          '${m.talkTimeSec.toStringAsFixed(0)} | ${m.turnCount} | ${m.wordCount} | '
          '${m.interruptionsMade} | ${m.interruptionsReceived} |',
        );
      }
      b
        ..writeln()
        ..writeln('_Interruptions are estimated from a single mixed audio stream._')
        ..writeln();

      if (report != null && report.reviews.isNotEmpty) {
        b
          ..writeln('## Speaker reviews')
          ..writeln();
        for (final m in allMetrics) {
          final r = report.reviews[m.speakerKey];
          if (r == null) continue;
          b
            ..writeln('### ${session.nameFor(m.speakerKey)}')
            ..writeln()
            ..writeln(r)
            ..writeln();
        }
      }
    }

    final feedback = session.feedback;
    if (feedback != null && !feedback.isEmpty) {
      final who = session.meSpeakerKey == null ? 'You' : session.nameFor(session.meSpeakerKey!);
      b
        ..writeln('## Coaching for $who')
        ..writeln();
      void items(String heading, List<FeedbackItem> list) {
        if (list.isEmpty) return;
        b.writeln('**$heading**');
        for (final i in list) {
          b.writeln('- ${i.title}');
          if (i.evidence != null) b.writeln('  - Said: "${i.evidence}"');
          if (i.tip != null) b.writeln('  - Try: ${i.tip}');
        }
        b.writeln();
      }

      items('Strengths', feedback.strengths);
      items('To work on', feedback.improvements);
      for (final n in feedback.goalNotes) {
        b.writeln('- Goal: $n');
      }
      if (feedback.goalNotes.isNotEmpty) b.writeln();
    }

    final digest = session.digest;
    if (digest != null) {
      b
        ..writeln('## Meeting notes')
        ..writeln();
      if (digest.summary.isNotEmpty) b..writeln(digest.summary)..writeln();
      if (digest.topics.isNotEmpty) {
        b..writeln('### What was discussed')..writeln();
        for (final t in digest.topics) {
          b.writeln('**${t.name}**${t.raisedBy == null ? '' : ' (raised by ${t.raisedBy})'}');
          if (t.summary != null) b.writeln(t.summary);
          b.writeln();
        }
      }
      void list(String heading, List<String> items) {
        if (items.isEmpty) return;
        b.writeln('### $heading');
        b.writeln();
        for (final i in items) {
          b.writeln('- $i');
        }
        b.writeln();
      }

      list('Decisions', [
        for (final d in digest.decisions)
          '${d.text}${d.rationale == null ? '' : ' — ${d.rationale}'}${d.evidence == null ? '' : ' ("${d.evidence}")'}',
      ]);
      list('Action items', [
        for (final a in digest.actionItems)
          '${a.owner == null ? '' : '${a.owner}: '}${a.task}${a.due == null ? '' : ' (due ${a.due})'}',
      ]);
      list('Left unanswered', [
        for (final q in digest.openQuestions)
          '${q.asker == null ? '' : '${q.asker} asked: '}${q.question}${q.context == null ? '' : ' — ${q.context}'}',
      ]);
      list('Risks and concerns', digest.risks);
      list('Key facts', digest.keyFacts);
    }

    final unanswered = session.insights
        .where((i) => i.category == InsightCategory.unansweredQuestion)
        .toList();
    if (unanswered.isNotEmpty) {
      b
        ..writeln('## Unanswered questions')
        ..writeln();
      for (final i in unanswered) {
        b.writeln('- **${i.title}**: ${i.description}');
      }
      b.writeln();
    }

    final actions = session.insights
        .where((i) => i.category == InsightCategory.actionItem)
        .toList();
    if (actions.isNotEmpty) {
      b
        ..writeln('## Action items')
        ..writeln();
      for (final i in actions) {
        b.writeln('- **${i.title}**: ${i.description}');
      }
      b.writeln();
    }

    return b.toString();
  }

  static String buildSessionJson(MeetingSession session) =>
      const JsonEncoder.withIndent('  ').convert(session.toJson());

  static Future<File?> exportMarkdown(MeetingSession session) =>
      _write(session, 'reports', 'md', buildMarkdown(session));

  static Future<File?> exportSessionJson(MeetingSession session) =>
      _write(session, 'sessions', 'json', buildSessionJson(session));

  static Future<File?> _write(
    MeetingSession session,
    String subdir,
    String ext,
    String content,
  ) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/MitraAssistant/$subdir');
      if (!await dir.exists()) await dir.create(recursive: true);

      final stamp = DateFormat('yyyyMMdd_HHmmss').format(session.startTime);
      final title = session.title
          .replaceAll(RegExp(r'[^\w\s\-]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .trim();
      final file = File('${dir.path}/${title.isEmpty ? "meeting" : title}_$stamp.$ext');
      await file.writeAsString(content);
      AppLogger.log('Exported $subdir file to ${file.path}');
      return file;
    } catch (e) {
      AppLogger.error('Error exporting $subdir file', e);
      return null;
    }
  }
}
