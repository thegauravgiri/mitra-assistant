import 'package:shared_preferences/shared_preferences.dart';
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
}
