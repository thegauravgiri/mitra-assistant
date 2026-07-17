import 'dart:async';
import 'package:flutter/services.dart';
import '../domain/audio_device.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/logger.dart';

class AudioCaptureService {
  static final AudioCaptureService instance = AudioCaptureService._();
  AudioCaptureService._();

  final MethodChannel _controlChannel = const MethodChannel(AppConstants.audioCaptureChannel);
  final EventChannel _streamChannel = const EventChannel(AppConstants.audioStreamChannel);

  Stream<Uint8List>? _audioStream;

  Stream<Uint8List> get audioStream {
    _audioStream ??= _streamChannel.receiveBroadcastStream().map((dynamic event) => event as Uint8List);
    return _audioStream!;
  }

  Future<bool> startCapture() async {
    try {
      final bool success = await _controlChannel.invokeMethod('startCapture');
      return success;
    } on PlatformException catch (e) {
      AppLogger.error('Audio capture start error', e.message);
      return false;
    }
  }

  Future<bool> stopCapture() async {
    try {
      final bool success = await _controlChannel.invokeMethod('stopCapture');
      _audioStream = null;
      return success;
    } on PlatformException catch (e) {
      AppLogger.error('Audio capture stop error', e.message);
      _audioStream = null;
      return false;
    }
  }

  Future<bool> isCapturing() async {
    try {
      final bool status = await _controlChannel.invokeMethod('isCapturing');
      return status;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<List<AudioDevice>> listInputDevices() async {
    try {
      final List<dynamic>? devices = await _controlChannel.invokeListMethod('listInputDevices');
      if (devices == null) return [];
      return devices.map((item) => AudioDevice.fromMap(Map<String, dynamic>.from(item as Map))).toList();
    } on PlatformException catch (e) {
      AppLogger.error('List input devices error', e.message);
      return [];
    }
  }

  Future<bool> setInputDevice(String deviceId) async {
    try {
      final bool success = await _controlChannel.invokeMethod('setInputDevice', deviceId);
      return success;
    } on PlatformException catch (e) {
      AppLogger.error('Set input device error', e.message);
      return false;
    }
  }

  Future<bool> setSystemAudioEnabled(bool enabled) async {
    try {
      final bool success = await _controlChannel.invokeMethod('setSystemAudioEnabled', enabled);
      return success;
    } on PlatformException catch (e) {
      AppLogger.error('Set system audio enabled error', e.message);
      return false;
    }
  }

  Future<String> checkMicrophonePermission() async {
    try {
      final String status = await _controlChannel.invokeMethod('checkMicrophonePermission');
      return status;
    } on PlatformException catch (e) {
      AppLogger.error('Check microphone permission error', e.message);
      return 'unknown';
    }
  }

  Future<bool> requestMicrophonePermission() async {
    try {
      final bool granted = await _controlChannel.invokeMethod('requestMicrophonePermission');
      return granted;
    } on PlatformException catch (e) {
      AppLogger.error('Request microphone permission error', e.message);
      return false;
    }
  }

  Future<bool> openMicrophoneSettings() async {
    try {
      final bool opened = await _controlChannel.invokeMethod('openMicrophoneSettings');
      return opened;
    } on PlatformException catch (e) {
      AppLogger.error('Open microphone settings error', e.message);
      return false;
    }
  }
}

