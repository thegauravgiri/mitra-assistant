import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/deepgram_service.dart';
import '../data/transcript_merge.dart';
import '../domain/models/transcript_entry.dart';
import '../domain/transcript_formatter.dart';
import '../../audio/data/audio_capture_service.dart';
import '../../settings/providers/settings_providers.dart';

class TranscriptionState {
  final List<TranscriptEntry> entries;
  final String currentInterim;
  final bool isConnected;
  final String? error;

  TranscriptionState({
    required this.entries,
    this.currentInterim = '',
    this.isConnected = false,
    this.error,
  });

  // Sentinel lets copyWith tell "not provided" from an explicit null, so callers
  // can clear the error with `error: null` while other updates preserve it.
  static const Object _sentinel = Object();

  TranscriptionState copyWith({
    List<TranscriptEntry>? entries,
    String? currentInterim,
    bool? isConnected,
    Object? error = _sentinel,
  }) {
    return TranscriptionState(
      entries: entries ?? this.entries,
      currentInterim: currentInterim ?? this.currentInterim,
      isConnected: isConnected ?? this.isConnected,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }

  String get fullTextTranscript {
    final finals = entries.map((e) => e.text).join(' ');
    if (currentInterim.isNotEmpty) {
      return '$finals $currentInterim'.trim();
    }
    return finals.trim();
  }

  /// Final entries as `Speaker N: text` lines (consecutive same-speaker lines
  /// merged), plus any in-flight interim text. Fed to Gemini so it can tell
  /// who asked what.
  String get labelledTranscript =>
      TranscriptFormatter.labelled(entries, interim: currentInterim);
}

class TranscriptionNotifier extends StateNotifier<TranscriptionState> {
  final Ref _ref;
  final DeepgramService _deepgramService = DeepgramService();
  StreamSubscription? _audioSub;
  StreamSubscription? _transcriptSub;

  TranscriptionNotifier(this._ref) : super(TranscriptionState(entries: []));

  Future<void> startTranscription() async {
    final apiKey = _ref.read(settingsNotifierProvider).deepgramApiKey;
    if (apiKey.isEmpty) {
      state = state.copyWith(error: 'Please enter a valid Deepgram API Key in Settings.');
      return;
    }

    state = state.copyWith(error: null);
    final connected = await _deepgramService.connect(
      apiKey,
      separateChannels: _ref.read(settingsNotifierProvider).separateVoices,
    );
    if (!connected) {
      state = state.copyWith(isConnected: false, error: 'Failed to connect to Deepgram transcription service.');
      return;
    }

    state = state.copyWith(isConnected: true);

    // Stream audio chunks to Deepgram
    _audioSub?.cancel();
    _audioSub = AudioCaptureService.instance.audioStream.listen((chunk) {
      _deepgramService.sendAudioChunk(chunk);
    });

    // Listen for live transcript events
    _transcriptSub?.cancel();
    _transcriptSub = _deepgramService.transcriptStream.listen((entry) {
      if (entry.isFinal) {
        // two channels arrive interleaved and the mic can echo the call
        state = state.copyWith(entries: TranscriptMerge.add(state.entries, entry), currentInterim: '');
      } else {
        state = state.copyWith(currentInterim: entry.text);
      }
    });
  }

  Future<void> stopTranscription() async {
    await _audioSub?.cancel();
    _audioSub = null;
    await _transcriptSub?.cancel();
    _transcriptSub = null;

    await _deepgramService.disconnect();
    state = state.copyWith(isConnected: false, currentInterim: '', error: null);
  }

  void clearTranscript() {
    _deepgramService.resetTimeline();
    state = TranscriptionState(entries: []);
  }

  @override
  void dispose() {
    _audioSub?.cancel();
    _transcriptSub?.cancel();
    _deepgramService.dispose();
    super.dispose();
  }
}

final transcriptionNotifierProvider = StateNotifierProvider<TranscriptionNotifier, TranscriptionState>((ref) {
  return TranscriptionNotifier(ref);
});
