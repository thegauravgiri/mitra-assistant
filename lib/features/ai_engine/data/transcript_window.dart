/// Which part of a long live transcript goes to the model raw, and when the
/// older part should be folded into the running notes.
class TranscriptWindow {
  /// The last [max] characters, starting at a line boundary so no line is cut in half.
  static String recent(String fullText, int max) {
    if (fullText.length <= max) return fullText;
    final cut = fullText.length - max;
    final nl = fullText.indexOf('\n', cut);
    return nl == -1 ? fullText.substring(cut) : fullText.substring(nl + 1);
  }

  /// Offset where the recent window begins (everything before it is "older").
  static int recentStart(String fullText, int max) => fullText.length - recent(fullText, max).length;

  /// True when at least [chunk] characters of new text have left the recent
  /// window since the notes were last updated.
  static bool shouldSummarise(String fullText, {required int max, required int summarisedUpTo, required int chunk}) =>
      recentStart(fullText, max) - summarisedUpTo >= chunk;
}
