import 'models/transcript_entry.dart';

class TranscriptFormatter {
  /// `Speaker N: text` lines; consecutive same-speaker entries are merged.
  static String labelled(
    List<TranscriptEntry> entries, {
    String interim = '',
    String Function(String speaker)? nameFor,
  }) {
    final buf = StringBuffer();
    String? last;
    for (final e in entries) {
      if (e.speaker == last) {
        buf.write(' ${e.text}');
      } else {
        if (last != null) buf.write('\n');
        buf.write('${nameFor?.call(e.speaker) ?? e.speaker}: ${e.text}');
        last = e.speaker;
      }
    }
    if (interim.isNotEmpty) {
      buf.write(last == null ? interim : ' $interim');
    }
    return buf.toString().trim();
  }
}
