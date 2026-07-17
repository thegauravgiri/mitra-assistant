import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/settings_repository.dart';

class SettingsState {
  final String deepgramApiKey;
  final String geminiApiKey;
  final int analysisIntervalSec;
  final String selectedAudioDevice;
  final bool captureSystemAudio;
  final bool isLoaded;

  SettingsState({
    required this.deepgramApiKey,
    required this.geminiApiKey,
    required this.analysisIntervalSec,
    this.selectedAudioDevice = '',
    this.captureSystemAudio = true,
    this.isLoaded = false,
  });

  SettingsState copyWith({
    String? deepgramApiKey,
    String? geminiApiKey,
    int? analysisIntervalSec,
    String? selectedAudioDevice,
    bool? captureSystemAudio,
    bool? isLoaded,
  }) {
    return SettingsState(
      deepgramApiKey: deepgramApiKey ?? this.deepgramApiKey,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      analysisIntervalSec: analysisIntervalSec ?? this.analysisIntervalSec,
      selectedAudioDevice: selectedAudioDevice ?? this.selectedAudioDevice,
      captureSystemAudio: captureSystemAudio ?? this.captureSystemAudio,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsRepository _repository = SettingsRepository();

  SettingsNotifier()
      : super(SettingsState(
          deepgramApiKey: '',
          geminiApiKey: '',
          analysisIntervalSec: 12,
          isLoaded: false,
        )) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final deepgram = await _repository.getDeepgramApiKey();
    final gemini = await _repository.getGeminiApiKey();
    final interval = await _repository.getAnalysisIntervalSec();
    final device = await _repository.getAudioInputDevice();
    final systemAudio = await _repository.getCaptureSystemAudio();

    state = SettingsState(
      deepgramApiKey: deepgram,
      geminiApiKey: gemini,
      analysisIntervalSec: interval,
      selectedAudioDevice: device,
      captureSystemAudio: systemAudio,
      isLoaded: true,
    );
  }

  Future<void> updateDeepgramApiKey(String key) async {
    await _repository.setDeepgramApiKey(key);
    state = state.copyWith(deepgramApiKey: key);
  }

  Future<void> updateGeminiApiKey(String key) async {
    await _repository.setGeminiApiKey(key);
    state = state.copyWith(geminiApiKey: key);
  }

  Future<void> updateAnalysisIntervalSec(int seconds) async {
    await _repository.setAnalysisIntervalSec(seconds);
    state = state.copyWith(analysisIntervalSec: seconds);
  }

  Future<void> updateSelectedAudioDevice(String deviceId) async {
    await _repository.setAudioInputDevice(deviceId);
    state = state.copyWith(selectedAudioDevice: deviceId);
  }

  Future<void> updateCaptureSystemAudio(bool enabled) async {
    await _repository.setCaptureSystemAudio(enabled);
    state = state.copyWith(captureSystemAudio: enabled);
  }
}

final settingsNotifierProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
