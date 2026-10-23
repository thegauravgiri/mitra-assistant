import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/features/transcription/data/deepgram_message_parser.dart';

Map<String, dynamic> _msg({
  String transcript = 'hello there how are you',
  bool isFinal = true,
  List<Map<String, dynamic>>? words,
}) =>
    {
      'is_final': isFinal,
      'channel': {
        'alternatives': [
          {
            'transcript': transcript,
            'words': ?words,
          },
        ],
      },
    };

Map<String, dynamic> _w(int speaker, double start, double end) =>
    {'word': 'w', 'speaker': speaker, 'start': start, 'end': end};

void main() {
  group('DeepgramMessageParser', () {
    test('picks majority speaker and first/last word timings', () {
      final e = DeepgramMessageParser.parse(_msg(words: [
        _w(1, 2.0, 2.4),
        _w(0, 2.4, 2.8),
        _w(1, 2.8, 3.5),
      ]))!;
      expect(e.speakerIndex, 1);
      expect(e.speaker, 'Speaker 2');
      expect(e.startSec, 2.0);
      expect(e.endSec, 3.5);
      expect(e.isFinal, isTrue);
    });

    test('applies time offset', () {
      final e = DeepgramMessageParser.parse(
        _msg(words: [_w(0, 1.0, 2.0)]),
        timeOffsetSec: 10,
      )!;
      expect(e.startSec, 11.0);
      expect(e.endSec, 12.0);
    });

    test('falls back to placeholder speaker when words are missing', () {
      final e = DeepgramMessageParser.parse(_msg())!;
      expect(e.speaker, 'Meeting Participant');
      expect(e.speakerIndex, isNull);
      expect(e.startSec, isNull);
    });

    test('returns null for empty transcript or missing channel', () {
      expect(DeepgramMessageParser.parse(_msg(transcript: '  ')), isNull);
      expect(DeepgramMessageParser.parse({'type': 'Metadata'}), isNull);
    });
  });

  group('DeepgramMessageParser.parseAll (one entry per speaker run)', () {
    Map<String, dynamic> w(String word, int? sp, double s, double e) => {
          'word': word.toLowerCase(),
          'punctuated_word': word,
          'speaker': ?sp,
          'start': s,
          'end': e,
        };

    test('a result containing two voices becomes two lines with the right speakers and times', () {
      final out = DeepgramMessageParser.parseAll(_msg(
        transcript: 'Can we ship Friday? Yes we can.',
        words: [
          w('Can', 0, 1.0, 1.2),
          w('we', 0, 1.2, 1.3),
          w('ship', 0, 1.3, 1.6),
          w('Friday?', 0, 1.6, 2.0),
          w('Yes', 1, 2.3, 2.5),
          w('we', 1, 2.5, 2.6),
          w('can.', 1, 2.6, 2.9),
        ],
      ));
      expect(out.length, 2);
      expect(out[0].speaker, 'Speaker 1');
      expect(out[0].text, 'Can we ship Friday?');
      expect(out[0].startSec, 1.0);
      expect(out[0].endSec, 2.0);
      expect(out[1].speaker, 'Speaker 2');
      expect(out[1].text, 'Yes we can.');
      expect(out[1].startSec, 2.3);
      expect(out.every((e) => e.isFinal), isTrue);
    });

    test('a single speaker stays one entry', () {
      final out = DeepgramMessageParser.parseAll(_msg(words: [w('hello', 0, 0, 1), w('there', 0, 1, 2)]));
      expect(out.length, 1);
      expect(out.single.speaker, 'Speaker 1');
    });

    test('a very short lone word between the same speaker is flicker; a real one-word reply is kept', () {
      final flicker = DeepgramMessageParser.parseAll(_msg(words: [
        w('so', 0, 0, 1), w('I', 0, 1, 2), w('think', 1, 2.0, 2.2), w('we', 0, 2.2, 3), w('should', 0, 3, 4),
      ]));
      expect(flicker.length, 1);
      expect(flicker.single.speaker, 'Speaker 1');

      final reply = DeepgramMessageParser.parseAll(_msg(words: [
        w('Ready?', 0, 0, 1), w('Yes.', 1, 1.5, 2.0), w('Great.', 0, 2.5, 3),
      ]));
      expect(reply.length, 3, reason: 'a 0.5 s "Yes." from the other person is a real turn');
      expect(reply[1].speaker, 'Speaker 2');
      expect(reply[1].text, 'Yes.');
    });

    test('time offset is applied to every run; words without a label inherit the previous speaker', () {
      final out = DeepgramMessageParser.parseAll(
        _msg(words: [w('a', 0, 0, 1), w('b', null, 1, 2), w('c', 1, 2, 3), w('d', 1, 3, 4)]),
        timeOffsetSec: 10,
      );
      expect(out.length, 2);
      expect(out[0].text, 'a b');
      expect(out[1].startSec, 12.0);
      expect(out[1].endSec, 14.0);
    });

    test('interim results stay a single entry; no words or no speaker labels fall back to one entry', () {
      final interim = DeepgramMessageParser.parseAll(_msg(isFinal: false, words: [w('a', 0, 0, 1), w('b', 1, 1, 2)]));
      expect(interim.length, 1);
      expect(interim.single.isFinal, isFalse);
      expect(DeepgramMessageParser.parseAll(_msg()).length, 1);
      expect(DeepgramMessageParser.parseAll(_msg(words: [w('a', null, 0, 1), w('b', null, 1, 2)])).length, 1);
      expect(DeepgramMessageParser.parseAll({'type': 'Metadata'}), isEmpty);
    });
  });
}
