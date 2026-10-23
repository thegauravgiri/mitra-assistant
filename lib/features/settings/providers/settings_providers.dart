import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../coaching/domain/models/goal.dart';
import '../data/settings_repository.dart';

class SettingsState {
  final String deepgramApiKey;
  final String geminiApiKey;
  final int analysisIntervalSec;
  final String selectedAudioDevice;
  final bool captureSystemAudio;
  final bool isLoaded;
  final String myName;
  final List<Goal> goals;

  /// Send the mic and the call on separate channels, so "you" is known exactly.
  /// Off = one mixed channel (cheaper, but speakers are only guessed).
  final bool separateVoices;

  SettingsState({
    required this.deepgramApiKey,
    required this.geminiApiKey,
    required this.analysisIntervalSec,
    this.selectedAudioDevice = '',
    this.captureSystemAudio = true,
    this.isLoaded = false,
    this.myName = '',
    this.goals = const [],
    this.separateVoices = true,
  });

  SettingsState copyWith({
    String? deepgramApiKey,
    String? geminiApiKey,
    int? analysisIntervalSec,
    String? selectedAudioDevice,
    bool? captureSystemAudio,
    bool? isLoaded,
    String? myName,
    List<Goal>? goals,
    bool? separateVoices,
  }) {
    return SettingsState(
      deepgramApiKey: deepgramApiKey ?? this.deepgramApiKey,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      analysisIntervalSec: analysisIntervalSec ?? this.analysisIntervalSec,
      selectedAudioDevice: selectedAudioDevice ?? this.selectedAudioDevice,
      captureSystemAudio: captureSystemAudio ?? this.captureSystemAudio,
      isLoaded: isLoaded ?? this.isLoaded,
      myName: myName ?? this.myName,
      goals: goals ?? this.goals,
      separateVoices: separateVoices ?? this.separateVoices,
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
    final myName = await _repository.getMyName();
    final goals = await _repository.getGoals();
    final separate = await _repository.getSeparateVoices();

    state = SettingsState(
      deepgramApiKey: deepgram,
      geminiApiKey: gemini,
      analysisIntervalSec: interval,
      selectedAudioDevice: device,
      captureSystemAudio: systemAudio,
      isLoaded: true,
      myName: myName,
      goals: goals,
      separateVoices: separate,
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

  Future<void> updateSeparateVoices(bool enabled) async {
    await _repository.setSeparateVoices(enabled);
    state = state.copyWith(separateVoices: enabled);
  }

  Future<void> updateMyName(String name) async {
    await _repository.setMyName(name.trim());
    state = state.copyWith(myName: name.trim());
  }

  /// Replaces the goal list (max [AppConstants.maxGoals], one per type).
  Future<void> updateGoals(List<Goal> goals) async {
    final seen = <GoalType>{};
    final unique = [for (final g in goals) if (seen.add(g.type)) g].take(AppConstants.maxGoals).toList();
    await _repository.setGoals(unique);
    state = state.copyWith(goals: unique);
  }

  Future<void> updateCaptureSystemAudio(bool enabled) async {
    await _repository.setCaptureSystemAudio(enabled);
    state = state.copyWith(captureSystemAudio: enabled);
  }
}

final settingsNotifierProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
