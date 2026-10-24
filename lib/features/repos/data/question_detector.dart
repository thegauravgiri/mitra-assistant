import '../../transcription/domain/models/transcript_entry.dart';

/// Spots a client asking how the product behaves ("what happens if...", "can it
/// handle..."), so the repositories are searched at that moment instead of on a
/// timer. Cheap, runs on every new line.
class QuestionDetector {
  static final RegExp _phrases = RegExp(
    r"\b(what happens|what if|what would happen|what will happen|what about|how does|how do you|how do we|how would|how can|how is|how are|"
    r"can it|can you|can we|could it|could you|does it|does the|do you|will it|would it|is it possible|is there a way|are you able|"
    r"walk me through|explain|suppose|in case|in the event|scenario|supports?|handle[sd]?)\b",
    caseSensitive: false,
  );

  /// Is [text] a question or scenario about how something works?
  static bool isScenarioQuestion(String text) {
    final t = text.trim();
    if (t.split(RegExp(r'\s+')).length < 4) return false;
    if (_phrases.hasMatch(t) && (t.contains('?') || RegExp(r'^(what|how|can|could|does|do|will|would|is|are|suppose|walk|explain)\b', caseSensitive: false).hasMatch(t) || t.toLowerCase().contains('what if') || t.toLowerCase().contains('what happens'))) {
      return true;
    }
    return t.endsWith('?') && t.split(RegExp(r'\s+')).length >= 5;
  }

  /// The most recent line, from someone other than the user, that asks such a
  /// question, looking only at the last [lastN] lines. Null when there is none.
  static TranscriptEntry? latest(List<TranscriptEntry> entries, {int lastN = 3}) {
    final recent = entries.length > lastN ? entries.sublist(entries.length - lastN) : entries;
    for (final e in recent.reversed) {
      if (e.speaker == 'You' || !e.isFinal) continue;
      if (isScenarioQuestion(e.text)) return e;
    }
    return null;
  }
}
