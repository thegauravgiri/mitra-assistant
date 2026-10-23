// Scores an exported session against a hand-made annotation file.
//
//   dart run tool/evaluate_session.dart <session.json> <annotation.json>
//
// annotation.json:
//   {
//     "talkSeconds": {"Speaker 1": 62.0, "Speaker 2": 41.5},
//     "unansweredQuestions": ["What does the licence cost?"]
//   }
import 'dart:convert';
import 'dart:io';
import 'package:mitra_assistant/features/coaching/data/session_evaluator.dart';
import 'package:mitra_assistant/features/history/domain/models/meeting_session.dart';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('Usage: dart run tool/evaluate_session.dart <session.json> <annotation.json>');
    exit(64);
  }
  final session = MeetingSession.fromJson(
    jsonDecode(File(args[0]).readAsStringSync()) as Map<String, dynamic>,
  );
  final annotation = jsonDecode(File(args[1]).readAsStringSync()) as Map<String, dynamic>;
  stdout.write(SessionEvaluator.evaluate(session, annotation).report());
}
