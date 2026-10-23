import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/features/history/data/meeting_identity.dart';
import 'package:mitra_assistant/features/transcription/data/deepgram_message_parser.dart';
import 'package:mitra_assistant/features/transcription/data/deepgram_service.dart';
import 'package:mitra_assistant/features/transcription/data/pcm_downmix.dart';
import 'package:mitra_assistant/features/transcription/data/transcript_merge.dart';
import 'package:mitra_assistant/features/transcription/domain/models/transcript_entry.dart';

Map<String, dynamic> msg(int channel, List<Map<String, dynamic>> words, {int total = 2, bool fin = true}) => {
      'is_final': fin,
      'channel_index': [channel, total],
      'channel': {
        'alternatives': [
          {'transcript': words.map((w) => w['punctuated_word']).join(' '), 'words': words},
        ],
      },
    };

Map<String, dynamic> w(String word, int sp, double s, double e) =>
    {'word': word.toLowerCase(), 'punctuated_word': word, 'speaker': sp, 'start': s, 'end': e};

TranscriptEntry entry(String speaker, String text, {double? s, double? e, DateTime? at}) => TranscriptEntry(
      id: '$speaker$text$s',
      text: text,
      timestamp: at ?? DateTime(2026, 10, 21, 10),
      isFinal: true,
      speaker: speaker,
      startSec: s,
      endSec: e,
    );

void main() {
  group('two channels: microphone is "You", the call is Speaker 2, 3...', () {
    test('channel 0 is always You, whatever diarisation says', () {
      final out = DeepgramMessageParser.parseAll(msg(0, [w('Hello', 0, 0, 0.5), w('team', 1, 0.5, 1.0)]));
      expect(out.length, 1); // the mic is one person: no splitting
      expect(out.single.speaker, 'You');
      expect(out.single.speakerIndex, 0);
    });

    test('channel 1 is the call; its first diarised speaker is Speaker 2', () {
      final out = DeepgramMessageParser.parseAll(msg(1, [w('Sounds', 0, 2, 2.4), w('good', 0, 2.4, 2.8)]));
      expect(out.single.speaker, 'Speaker 2');
      expect(out.single.speakerIndex, 1);
    });

    test('several people on the call are split and numbered after "You"', () {
      final out = DeepgramMessageParser.parseAll(msg(1, [
        w('Can', 0, 1, 1.2), w('we', 0, 1.2, 1.4), w('ship?', 0, 1.4, 1.9),
        w('Yes', 1, 2.4, 2.8), w('absolutely.', 1, 2.8, 3.4),
      ]));
      expect(out.map((e) => e.speaker), ['Speaker 2', 'Speaker 3']);
    });

    test('single-channel audio keeps the old numbering', () {
      final out = DeepgramMessageParser.parseAll(msg(0, [w('Hi', 0, 0, 1), w('there', 0, 1, 2)], total: 1));
      expect(out.single.speaker, 'Speaker 1');
    });

    test('a result with no channel_index is treated as single-channel', () {
      final m = msg(0, [w('Hi', 1, 0, 1)]);
      m.remove('channel_index');
      expect(DeepgramMessageParser.parseAll(m).single.speaker, 'Speaker 2'); // diarised 1 => Speaker 2, as before
    });
  });

  test('connection URL: multichannel with 2 channels, or folded to 1', () {
    final sep = DeepgramService.listenUri(separateChannels: true).queryParameters;
    expect(sep['channels'], '2');
    expect(sep['multichannel'], 'true');
    expect(sep['diarize'], 'true');
    expect(sep['encoding'], 'linear16');
    final mono = DeepgramService.listenUri(separateChannels: false).queryParameters;
    expect(mono['channels'], '1');
    expect(mono.containsKey('multichannel'), isFalse);
  });

  test('PcmDownmix adds left and right, clipped, and ignores a trailing partial frame', () {
    final bytes = ByteData(10)
      ..setInt16(0, 100, Endian.little)
      ..setInt16(2, 200, Endian.little)
      ..setInt16(4, 30000, Endian.little)
      ..setInt16(6, 30000, Endian.little)
      ..setInt16(8, 7, Endian.little); // half a frame
    final mono = PcmDownmix.stereoToMono(bytes.buffer.asUint8List());
    final v = ByteData.sublistView(mono);
    expect(mono.length, 4);
    expect(v.getInt16(0, Endian.little), 300);
    expect(v.getInt16(2, Endian.little), 32767);
  });

  group('TranscriptMerge', () {
    test('a "You" line that repeats what the call just said is dropped (speaker echo)', () {
      final call = entry('Speaker 2', 'We need to finalise the budget forecast before Friday', s: 10, e: 14);
      final echo = entry('You', 'we need to finalise the budget forecast before friday', s: 10.3, e: 14.2);
      final merged = TranscriptMerge.add([call], echo);
      expect(merged.map((e) => e.speaker), ['Speaker 2']);
    });

    test('if the echo arrived first, the call line replaces it', () {
      final echo = entry('You', 'we need to finalise the budget forecast before friday', s: 10.3, e: 14.2);
      final call = entry('Speaker 2', 'We need to finalise the budget forecast before Friday', s: 10, e: 14);
      final merged = TranscriptMerge.add([echo], call);
      expect(merged.map((e) => e.speaker), ['Speaker 2']);
    });

    test('real replies are kept: different words, short lines, or far apart in time', () {
      final call = entry('Speaker 2', 'We need to finalise the budget forecast before Friday', s: 10, e: 14);
      expect(TranscriptMerge.add([call], entry('You', 'I will send the numbers tomorrow morning', s: 15, e: 18)).length, 2);
      expect(TranscriptMerge.add([call], entry('You', 'budget forecast', s: 10.2, e: 11)).length, 2); // too short to be sure
      expect(TranscriptMerge.add([call], entry('You', 'we need to finalise the budget forecast before friday', s: 40, e: 44)).length, 2);
    });

    test('lines from two channels are kept in start-time order', () {
      var list = <TranscriptEntry>[];
      list = TranscriptMerge.add(list, entry('You', 'first thing I said', s: 1, e: 3));
      list = TranscriptMerge.add(list, entry('Speaker 2', 'a later reply from them', s: 8, e: 10));
      list = TranscriptMerge.add(list, entry('You', 'my answer in between', s: 4, e: 6)); // arrives late
      expect(list.map((e) => e.startSec), [1, 4, 8]);
    });

    test('entries without timings are simply appended', () {
      var list = <TranscriptEntry>[];
      list = TranscriptMerge.add(list, entry('Speaker 1', 'one two three four'));
      list = TranscriptMerge.add(list, entry('Speaker 2', 'five six seven eight'));
      expect(list.length, 2);
      expect(list.last.speaker, 'Speaker 2');
    });
  });

  group('MeetingIdentity', () {
    test('with a "You" channel the user is identified and named', () {
      final id = MeetingIdentity.forEntries([entry('You', 'hi'), entry('Speaker 2', 'hello')], ' John ');
      expect(id.meKey, 'You');
      expect(id.names, {'You': 'John'});
    });

    test('without a name it stays "You"; without a You channel nothing is assumed', () {
      expect(MeetingIdentity.forEntries([entry('You', 'hi')], '').names, {'You': 'You'});
      final none = MeetingIdentity.forEntries([entry('Speaker 1', 'hi')], 'John');
      expect(none.meKey, isNull);
      expect(none.names, isEmpty);
    });
  });
}
