import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/audio_capture_service.dart';
import '../domain/audio_device.dart';

class AudioState {
  final bool isRecording;
  final double audioLevel; // 0.0 to 1.0 RMS power
  final List<AudioDevice> availableDevices;
  final String? selectedDeviceId;
  final bool captureSystemAudio;
  final String? error;

  AudioState({
    required this.isRecording,
    this.audioLevel = 0.0,
    this.availableDevices = const [],
    this.selectedDeviceId,
    this.captureSystemAudio = true,
    this.error,
  });

  AudioState copyWith({
    bool? isRecording,
    double? audioLevel,
    List<AudioDevice>? availableDevices,
    String? selectedDeviceId,
    bool? captureSystemAudio,
    String? error,
  }) {
    return AudioState(
      isRecording: isRecording ?? this.isRecording,
      audioLevel: audioLevel ?? this.audioLevel,
      availableDevices: availableDevices ?? this.availableDevices,
      selectedDeviceId: selectedDeviceId ?? this.selectedDeviceId,
      captureSystemAudio: captureSystemAudio ?? this.captureSystemAudio,
      error: error,
    );
  }
}

class AudioNotifier extends StateNotifier<AudioState> {
  AudioNotifier() : super(AudioState(isRecording: false)) {
    refreshDevices();
  }

  StreamSubscription<Uint8List>? _audioSub;

  Future<void> refreshDevices() async {
    final devices = await AudioCaptureService.instance.listInputDevices();
    String? defaultId = state.selectedDeviceId;
    if (defaultId == null && devices.isNotEmpty) {
      final defaultDev = devices.firstWhere((d) => d.isDefault, orElse: () => devices.first);
      defaultId = defaultDev.id;
    }
    state = state.copyWith(availableDevices: devices, selectedDeviceId: defaultId);
  }

  Future<void> selectDevice(String deviceId) async {
    state = state.copyWith(selectedDeviceId: deviceId);
    await AudioCaptureService.instance.setInputDevice(deviceId);
  }

  Future<void> toggleSystemAudio(bool enabled) async {
    state = state.copyWith(captureSystemAudio: enabled);
    await AudioCaptureService.instance.setSystemAudioEnabled(enabled);
  }

  Future<bool> startRecording() async {
    state = state.copyWith(isRecording: false, error: null);

    if (state.selectedDeviceId != null) {
      await AudioCaptureService.instance.setInputDevice(state.selectedDeviceId!);
    }
    await AudioCaptureService.instance.setSystemAudioEnabled(state.captureSystemAudio);

    final success = await AudioCaptureService.instance.startCapture();
    if (!success) {
      state = state.copyWith(
        isRecording: false, 
        error: 'Microphone permission denied. Please allow microphone access in macOS System Settings.',
      );
      return false;
    }

    state = state.copyWith(isRecording: true, error: null);

    _audioSub?.cancel();
    _audioSub = AudioCaptureService.instance.audioStream.listen(
      (data) {
        final rms = _calculateRmsLevel(data);
        state = state.copyWith(audioLevel: rms);
      },
      onError: (err) {
        state = state.copyWith(error: err.toString());
      },
    );
    return true;
  }

  Future<void> stopRecording() async {
    await AudioCaptureService.instance.stopCapture();
    await _audioSub?.cancel();
    _audioSub = null;
    state = state.copyWith(isRecording: false, audioLevel: 0.0);
  }

  Future<void> openMicrophoneSettings() async {
    await AudioCaptureService.instance.openMicrophoneSettings();
  }

  double _calculateRmsLevel(Uint8List bytes) {
    if (bytes.length < 2) return 0.0;
    final alignedBytes = (bytes.offsetInBytes % 2 == 0)
        ? bytes
        : Uint8List.fromList(bytes);
    final int16List = Int16List.view(
      alignedBytes.buffer,
      alignedBytes.offsetInBytes,
      alignedBytes.lengthInBytes ~/ 2,
    );
    if (int16List.isEmpty) return 0.0;

    double sum = 0.0;
    for (int sample in int16List) {
      sum += sample * sample;
    }
    double meanSquare = sum / int16List.length;
    double rms = sqrt(meanSquare) / 32768.0;
    return rms.clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _audioSub?.cancel();
    super.dispose();
  }
}

final audioNotifierProvider = StateNotifierProvider<AudioNotifier, AudioState>((ref) {
  return AudioNotifier();
});

