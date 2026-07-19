import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/logger.dart';
import '../domain/models/meeting_session.dart';

class HistoryRepository {
  static const int maxStoredSessions = 50;

  Future<List<MeetingSession>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(AppConstants.prefMeetingHistory);
      if (rawJson == null || rawJson.trim().isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(rawJson) as List<dynamic>;
      return jsonList
          .map((item) => MeetingSession.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Error reading meeting history from SharedPreferences', e);
      return [];
    }
  }

  Future<void> saveSession(MeetingSession session) async {
    try {
      final currentList = await getHistory();
      // Prepend newest session or replace existing
      final updatedList = [session, ...currentList.where((s) => s.id != session.id)];

      // Keep up to maxStoredSessions
      if (updatedList.length > maxStoredSessions) {
        final removed = updatedList.sublist(maxStoredSessions);
        for (final item in removed) {
          _deleteCsvFromDisk(item.exportedCsvPath);
        }
        updatedList.removeRange(maxStoredSessions, updatedList.length);
      }

      final rawJson = jsonEncode(updatedList.map((s) => s.toJson()).toList());
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.prefMeetingHistory, rawJson);
    } catch (e) {
      AppLogger.error('Error saving meeting session to history', e);
    }
  }

  Future<void> deleteSession(String id) async {
    try {
      final currentList = await getHistory();
      for (final session in currentList) {
        if (session.id == id) {
          _deleteCsvFromDisk(session.exportedCsvPath);
        }
      }

      final updatedList = currentList.where((s) => s.id != id).toList();

      final rawJson = jsonEncode(updatedList.map((s) => s.toJson()).toList());
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.prefMeetingHistory, rawJson);
    } catch (e) {
      AppLogger.error('Error deleting meeting session from history', e);
    }
  }

  Future<void> clearHistory() async {
    try {
      final currentList = await getHistory();
      for (final session in currentList) {
        _deleteCsvFromDisk(session.exportedCsvPath);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.prefMeetingHistory);
    } catch (e) {
      AppLogger.error('Error clearing meeting history', e);
    }
  }

  void _deleteCsvFromDisk(String? path) {
    if (path != null && path.trim().isNotEmpty) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          file.deleteSync();
          AppLogger.log('Deleted exported CSV file from disk: $path');
        }
      } catch (e) {
        AppLogger.error('Failed to delete CSV file from disk: $path', e);
      }
    }
  }
}
