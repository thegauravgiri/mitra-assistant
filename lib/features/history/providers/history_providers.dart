import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/csv_export_service.dart';
import '../data/history_repository.dart';
import '../domain/models/meeting_session.dart';
import '../../../features/transcription/domain/models/transcript_entry.dart';

class HistoryState {
  final List<MeetingSession> sessions;
  final bool isLoading;
  final String? error;
  final String? lastExportedPath;

  HistoryState({
    required this.sessions,
    this.isLoading = false,
    this.error,
    this.lastExportedPath,
  });

  HistoryState copyWith({
    List<MeetingSession>? sessions,
    bool? isLoading,
    String? error,
    String? lastExportedPath,
  }) {
    return HistoryState(
      sessions: sessions ?? this.sessions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastExportedPath: lastExportedPath ?? this.lastExportedPath,
    );
  }
}

class HistoryNotifier extends StateNotifier<HistoryState> {
  final HistoryRepository _repository = HistoryRepository();

  HistoryNotifier() : super(HistoryState(sessions: [])) {
    loadHistory();
  }

  Future<void> loadHistory() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await _repository.getHistory();
      state = state.copyWith(sessions: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load history: ${e.toString()}',
      );
    }
  }

  Future<void> saveCurrentMeeting({
    required String title,
    required String aiSummary,
    required DateTime startTime,
    required List<TranscriptEntry> entries,
  }) async {
    if (entries.isEmpty) return; // Don't save empty meetings

    final session = MeetingSession(
      id: const Uuid().v4(),
      title: title.trim().isEmpty ? 'Meeting — ${_formatDefaultTitle(startTime)}' : title.trim(),
      aiSummary: aiSummary.trim(),
      startTime: startTime,
      endTime: DateTime.now(),
      entries: entries,
    );

    await _repository.saveSession(session);
    await loadHistory();
  }

  Future<void> deleteSession(String id) async {
    await _repository.deleteSession(id);
    await loadHistory();
  }

  Future<void> clearHistory() async {
    await _repository.clearHistory();
    state = state.copyWith(sessions: []);
  }

  Future<String?> exportSessionCsv(MeetingSession session) async {
    final file = await CsvExportService.exportSessionToCsv(session);
    if (file != null) {
      final updatedSession = session.copyWith(exportedCsvPath: file.path);
      await _repository.saveSession(updatedSession);
      await loadHistory();
      state = state.copyWith(lastExportedPath: file.path);
      return file.path;
    }
    return null;
  }

  String _formatDefaultTitle(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

final historyNotifierProvider =
    StateNotifierProvider<HistoryNotifier, HistoryState>((ref) {
  return HistoryNotifier();
});
