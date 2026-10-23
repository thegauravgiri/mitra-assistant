import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../coaching/domain/models/goal.dart';
import '../../../core/constants/app_constants.dart';

class SettingsRepository {
  Future<String> getDeepgramApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.prefDeepgramApiKey) ?? '';
  }

  Future<void> setDeepgramApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefDeepgramApiKey, key);
  }

  Future<String> getGeminiApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.prefGeminiApiKey) ?? '';
  }

  Future<void> setGeminiApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefGeminiApiKey, key);
  }

  Future<int> getAnalysisIntervalSec() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(AppConstants.prefAnalysisInterval) ?? AppConstants.defaultAnalysisIntervalSec;
  }

  Future<void> setAnalysisIntervalSec(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.prefAnalysisInterval, seconds);
  }

  Future<String> getAudioInputDevice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.prefAudioInputDevice) ?? '';
  }

  Future<void> setAudioInputDevice(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefAudioInputDevice, deviceId);
  }

  Future<bool> getCaptureSystemAudio() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.prefCaptureSystemAudio) ?? true;
  }

  Future<void> setCaptureSystemAudio(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefCaptureSystemAudio, enabled);
  }

  Future<String> getMyName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.prefMyName) ?? '';
  }

  Future<void> setMyName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefMyName, name);
  }

  Future<List<Goal>> getGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.prefGoals);
    if (raw == null || raw.isEmpty) return [];
    try {
      return [
        for (final g in jsonDecode(raw) as List<dynamic>)
          if (Goal.fromJson(g as Map<String, dynamic>) != null) Goal.fromJson(g)!,
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> setGoals(List<Goal> goals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefGoals, jsonEncode(goals.map((g) => g.toJson()).toList()));
  }

  Future<bool> getSeparateVoices() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.prefSeparateVoices) ?? true;
  }

  Future<void> setSeparateVoices(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefSeparateVoices, enabled);
  }
}
