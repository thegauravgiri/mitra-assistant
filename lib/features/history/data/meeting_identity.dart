import '../../transcription/data/transcript_merge.dart';
import '../../transcription/domain/models/transcript_entry.dart';

/// Who "me" is in a freshly recorded meeting. With the mic on its own channel
/// the user is simply the speaker "You", so no "which speaker are you?" step.
class MeetingIdentity {
  static ({String? meKey, Map<String, String> names}) forEntries(
    List<TranscriptEntry> entries,
    String myName,
  ) {
    if (!entries.any((e) => e.speaker == TranscriptMerge.me)) {
      return (meKey: null, names: const {});
    }
    final name = myName.trim();
    return (meKey: TranscriptMerge.me, names: {TranscriptMerge.me: name.isEmpty ? 'You' : name});
  }
}
