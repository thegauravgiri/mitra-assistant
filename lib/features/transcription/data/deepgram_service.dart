import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../domain/models/transcript_entry.dart';
import 'deepgram_message_parser.dart';
import 'pcm_downmix.dart';
import '../../../core/utils/logger.dart';

class DeepgramService {
  WebSocketChannel? _channel;
  final StreamController<TranscriptEntry> _transcriptController = StreamController<TranscriptEntry>.broadcast();
  Stream<TranscriptEntry> get transcriptStream => _transcriptController.stream;

  bool _isConnected = false;
  bool _separateChannels = true;
  // Deepgram word timings restart at 0 on every connection; these keep the
  // session timeline monotonic across stop/start within one meeting.
  double _timeOffsetSec = 0;
  double _lastEndSec = 0;
  bool get isConnected => _isConnected;

  /// Connection URL. The native layer always sends stereo (left = microphone,
  /// right = the call): with [separateChannels] Deepgram transcribes each channel
  /// on its own (multichannel) and diarize then splits the people on the call
  /// channel; without it the two are folded down to one channel.
  static Uri listenUri({required bool separateChannels}) => Uri.parse(
        'wss://api.deepgram.com/v1/listen?'
        'model=nova-2&encoding=linear16&sample_rate=16000&'
        '${separateChannels ? 'channels=2&multichannel=true' : 'channels=1'}&'
        'interim_results=true&punctuate=true&smart_format=true&diarize=true&filler_words=true',
      );

  Future<bool> connect(String apiKey, {bool separateChannels = true}) async {
    if (apiKey.trim().isEmpty) return false;
    _separateChannels = separateChannels;

    final uri = listenUri(separateChannels: separateChannels);

    try {
      _channel = WebSocketChannel.connect(
        uri,
        protocols: ['token', apiKey.trim()],
      );

      await _channel?.ready;
      _isConnected = true;

      _channel?.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          AppLogger.error('Deepgram WebSocket error', error);
          _isConnected = false;
        },
        onDone: () {
          AppLogger.log('Deepgram WebSocket connection closed');
          _isConnected = false;
        },
      );

      return true;
    } catch (e) {
      AppLogger.error('Deepgram connection exception', e);
      _isConnected = false;
      return false;
    }
  }

  void sendAudioChunk(Uint8List chunk) {
    if (_isConnected && _channel != null) {
      _channel?.sink.add(_separateChannels ? chunk : PcmDownmix.stereoToMono(chunk));
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final jsonMap = jsonDecode(message as String) as Map<String, dynamic>;
      final entries = DeepgramMessageParser.parseAll(
        jsonMap,
        timeOffsetSec: _timeOffsetSec,
      );
      if (entries.isEmpty) return;
      for (final entry in entries) {
        if (entry.endSec != null) _lastEndSec = entry.endSec! - _timeOffsetSec;
        _transcriptController.add(entry);
      }
    } catch (e) {
      AppLogger.error('Error parsing Deepgram message', e);
    }
  }

  /// Call when a new meeting starts so timings begin at 0 again.
  void resetTimeline() {
    _timeOffsetSec = 0;
    _lastEndSec = 0;
  }

  Future<void> disconnect() async {
    if (_channel != null) {
      _timeOffsetSec += _lastEndSec;
      _lastEndSec = 0;
    }
    _isConnected = false;
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _transcriptController.close();
  }
}
