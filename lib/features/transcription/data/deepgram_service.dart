import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../domain/models/transcript_entry.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/logger.dart';

class DeepgramService {
  WebSocketChannel? _channel;
  final StreamController<TranscriptEntry> _transcriptController = StreamController<TranscriptEntry>.broadcast();
  Stream<TranscriptEntry> get transcriptStream => _transcriptController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  Future<bool> connect(String apiKey) async {
    if (apiKey.trim().isEmpty) return false;

    final uri = Uri.parse(
      'wss://api.deepgram.com/v1/listen?'
      'encoding=linear16&sample_rate=16000&channels=1&'
      'interim_results=true&punctuate=true&smart_format=true',
    );

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
      _channel?.sink.add(chunk);
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final jsonMap = jsonDecode(message as String);
      final isFinal = jsonMap['is_final'] as bool? ?? false;
      final channel = jsonMap['channel'] as Map<String, dynamic>?;
      if (channel == null) return;

      final alternatives = channel['alternatives'] as List<dynamic>?;
      if (alternatives == null || alternatives.isEmpty) return;

      final transcriptText = alternatives[0]['transcript'] as String? ?? '';
      if (transcriptText.trim().isEmpty) return;

      final entry = TranscriptEntry(
        id: const Uuid().v4(),
        text: transcriptText,
        timestamp: DateTime.now(),
        isFinal: isFinal,
      );

      _transcriptController.add(entry);
    } catch (e) {
      AppLogger.error('Error parsing Deepgram message', e);
    }
  }

  Future<void> disconnect() async {
    _isConnected = false;
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _transcriptController.close();
  }
}
