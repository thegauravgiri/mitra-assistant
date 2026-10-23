import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/text_similarity.dart';
import '../../documents/data/document_relevance_service.dart';
import '../../documents/providers/document_providers.dart';
import '../../meeting_graph/data/meeting_recall_service.dart';
import '../../meeting_graph/providers/meeting_graph_providers.dart';
import '../data/gemini_service.dart';
import '../data/transcript_window.dart';
import '../domain/models/insight.dart';
import '../../transcription/providers/transcription_providers.dart';
import '../../settings/providers/settings_providers.dart';

class AiState {
  final List<Insight> insights;
  final bool isAnalyzing;
  final String? error;

  AiState({required this.insights, this.isAnalyzing = false, this.error});

  AiState copyWith({
    List<Insight>? insights,
    bool? isAnalyzing,
    String? error,
  }) {
    return AiState(
      insights: insights ?? this.insights,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      error: error,
    );
  }
}

class AiNotifier extends StateNotifier<AiState> {
  final Ref _ref;
  final GeminiService _geminiService = GeminiService();
  final DocumentRelevanceService _relevanceService = DocumentRelevanceService();
  Timer? _analysisTimer;
  String _lastAnalyzedTranscript = '';
  String _lastActiveDocSignature = '';

  static const int _maxInsightsCount = 20;
  static const int _maxTranscriptCharLength = 4500; // the "recent conversation" window
  static const int _summaryChunkChars = 2500; // summarise once this much new text has left the window

  // Running notes of the meeting before the recent window, so insights know
  // what was said earlier (needed to catch unanswered questions in long calls).
  String _meetingSummary = '';
  int _summarisedUpTo = 0;
  bool _summarising = false;

  AiNotifier(this._ref) : super(AiState(insights: []));

  void startPeriodicAnalysis() {
    _analysisTimer?.cancel();
    final interval = _ref.read(settingsNotifierProvider).analysisIntervalSec;

    // Run first check immediately, then periodically
    analyzeCurrentTranscript();

    _analysisTimer = Timer.periodic(Duration(seconds: interval), (_) async {
      await analyzeCurrentTranscript();
    });
  }

  Future<void> analyzeCurrentTranscript({bool force = false}) async {
    final apiKey = _ref.read(settingsNotifierProvider).geminiApiKey;
    if (apiKey.trim().isEmpty) {
      state = state.copyWith(
        isAnalyzing: false,
        error:
            'Gemini API key missing in Settings. Please add your Gemini API Key.',
      );
      return;
    }

    final transcriptState = _ref.read(transcriptionNotifierProvider);
    final fullText = transcriptState.labelledTranscript.trim();
    final documentState = _ref.read(documentNotifierProvider);

    // Recent window, starting on a line boundary so no line is cut in half
    final transcriptSlice = _recentWindow(fullText);
    _maybeUpdateMeetingSummary(fullText, apiKey);

    // Evaluate relevant document context
    final relevanceResult = _relevanceService.getRelevantContext(
      transcriptWindow: transcriptSlice,
      documents: documentState.documents,
    );

    // Do NOT send to Gemini if no transcript and no relevant documents
    if (fullText.isEmpty && !relevanceResult.hasContext) {
      if (force) {
        state = state.copyWith(
          isAnalyzing: false,
          error:
              'No transcript or document context available yet.',
        );
      } else {
        state = state.copyWith(isAnalyzing: false);
      }
      return;
    }

    // Do NOT send to Gemini if there is no NEW transcript or document state change since last analysis
    if (!force &&
        fullText == _lastAnalyzedTranscript &&
        relevanceResult.activeSignature == _lastActiveDocSignature) {
      state = state.copyWith(isAnalyzing: false);
      return;
    }

    _lastAnalyzedTranscript = fullText;
    _lastActiveDocSignature = relevanceResult.activeSignature;
    state = state.copyWith(isAnalyzing: true, error: null);

    // Newest final line the insight can be based on; used for latency.
    final latestFinal = transcriptState.entries.isEmpty
        ? null
        : transcriptState.entries.last.timestamp;

    try {
      final existingTitles = state.insights.map((i) => i.title).take(15).toList();
      final newInsights = await _geminiService.analyzeTranscript(
        apiKey: apiKey,
        transcript: transcriptSlice,
        existingInsightTitles: existingTitles,
        documentContext: relevanceResult.documentContext,
        earlierMeetings: MeetingRecallService.recall(
          transcriptSlice,
          _ref.read(meetingGraphProvider),
        ),
        meetingSoFar: _meetingSummary,
      );

      // Client-side multi-pass semantic deduplication fallback
      final latencyMs = latestFinal == null
          ? null
          : DateTime.now().difference(latestFinal).inMilliseconds;
      final uniqueInsights = newInsights
          .where((candidate) => !_isDuplicate(candidate, state.insights))
          .map((i) => i.copyWith(latencyMs: latencyMs))
          .toList();
      if (latencyMs != null && uniqueInsights.isNotEmpty) {
        AppLogger.log('Insight latency: ${latencyMs}ms');
      }

      if (uniqueInsights.isNotEmpty) {
        var updatedList = List<Insight>.from(uniqueInsights)
          ..addAll(state.insights);

        // Cap maximum accumulated active insights
        if (updatedList.length > _maxInsightsCount) {
          updatedList = updatedList.sublist(0, _maxInsightsCount);
        }

        state = state.copyWith(
          insights: updatedList,
          isAnalyzing: false,
          error: null,
        );
      } else {
        state = state.copyWith(isAnalyzing: false, error: null);
      }
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(isAnalyzing: false, error: msg);
    }
  }

  bool _isDuplicate(Insight candidate, List<Insight> existingInsights) {
    final candidateTitleNorm = TextSimilarity.normalize(candidate.title);
    final candidateDescNorm = TextSimilarity.normalize(candidate.description);

    final candidateTitleTokens = TextSimilarity.tokenize(candidate.title);
    final candidateDescTokens = TextSimilarity.tokenize(candidate.description);

    for (final existing in existingInsights) {
      final existingTitleNorm = TextSimilarity.normalize(existing.title);
      final existingDescNorm = TextSimilarity.normalize(existing.description);

      // 1. Direct equality or substring containment check for titles
      if (candidateTitleNorm == existingTitleNorm ||
          (candidateTitleNorm.length > 5 &&
              existingTitleNorm.contains(candidateTitleNorm)) ||
          (existingTitleNorm.length > 5 &&
              candidateTitleNorm.contains(existingTitleNorm))) {
        return true;
      }

      // 2. Direct equality or substring containment for descriptions
      if (candidateDescNorm.length > 10 && existingDescNorm.length > 10) {
        if (candidateDescNorm == existingDescNorm ||
            candidateDescNorm.contains(existingDescNorm) ||
            existingDescNorm.contains(candidateDescNorm)) {
          return true;
        }
      }

      // 3. Jaccard Token Overlap Similarity check
      final existingTitleTokens = TextSimilarity.tokenize(existing.title);
      final titleSim = TextSimilarity.calculateJaccardSimilarity(
          candidateTitleTokens, existingTitleTokens);
      if (titleSim >= 0.45) {
        return true;
      }

      final existingDescTokens = TextSimilarity.tokenize(existing.description);
      final descSim = TextSimilarity.calculateJaccardSimilarity(
          candidateDescTokens, existingDescTokens);
      if (descSim >= 0.45) {
        return true;
      }
    }
    return false;
  }

  Future<void> askQuestion(String question) async {
    if (question.trim().isEmpty) return;

    final apiKey = _ref.read(settingsNotifierProvider).geminiApiKey;
    if (apiKey.trim().isEmpty) {
      state = state.copyWith(
        isAnalyzing: false,
        error:
            'Gemini API key missing in Settings. Please add your Gemini API Key.',
      );
      return;
    }

    final transcriptState = _ref.read(transcriptionNotifierProvider);
    final labelled = transcriptState.labelledTranscript;
    final recent = _recentWindow(labelled);
    final fullText = transcriptState.fullTextTranscript;
    final documentState = _ref.read(documentNotifierProvider);

    final relevanceResult = _relevanceService.getRelevantContext(
      transcriptWindow: fullText,
      questionText: question,
      documents: documentState.documents,
    );

    state = state.copyWith(isAnalyzing: true, error: null);

    try {
      final newInsights = await _geminiService.askCopilotQuestion(
        apiKey: apiKey,
        transcript: recent,
        question: question,
        documentContext: relevanceResult.documentContext,
        earlierMeetings: MeetingRecallService.recall(
          '$recent $question',
          _ref.read(meetingGraphProvider),
        ),
        meetingSoFar: _meetingSummary,
      );

      final uniqueInsights = newInsights
          .where((candidate) => !_isDuplicate(candidate, state.insights))
          .toList();

      if (uniqueInsights.isNotEmpty) {
        var updatedList = List<Insight>.from(uniqueInsights)
          ..addAll(state.insights);

        if (updatedList.length > _maxInsightsCount) {
          updatedList = updatedList.sublist(0, _maxInsightsCount);
        }

        state = state.copyWith(
          insights: updatedList,
          isAnalyzing: false,
          error: null,
        );
      } else {
        state = state.copyWith(isAnalyzing: false, error: null);
      }
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(isAnalyzing: false, error: msg);
    }
  }

  void stopPeriodicAnalysis() {
    _analysisTimer?.cancel();
    _analysisTimer = null;
  }

  String _recentWindow(String fullText) => TranscriptWindow.recent(fullText, _maxTranscriptCharLength);

  /// Folds text that has just left the recent window into the running notes.
  /// Runs in the background; the analysis never waits for it.
  void _maybeUpdateMeetingSummary(String fullText, String apiKey) {
    if (_summarising ||
        !TranscriptWindow.shouldSummarise(
          fullText,
          max: _maxTranscriptCharLength,
          summarisedUpTo: _summarisedUpTo,
          chunk: _summaryChunkChars,
        )) {
      return;
    }

    final upTo = TranscriptWindow.recentStart(fullText, _maxTranscriptCharLength);
    final portion = fullText.substring(_summarisedUpTo, upTo);
    _summarising = true;
    _geminiService
        .updateMeetingSummary(apiKey: apiKey, previousNotes: _meetingSummary, newTranscript: portion)
        .then((notes) {
      if (!mounted) return;
      if (notes.isNotEmpty) {
        _meetingSummary = notes;
        _summarisedUpTo = upTo;
      }
    }).whenComplete(() => _summarising = false);
  }

  void clearInsights() {
    _lastAnalyzedTranscript = '';
    _lastActiveDocSignature = '';
    _meetingSummary = '';
    _summarisedUpTo = 0;
    state = AiState(insights: [], error: null);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _analysisTimer?.cancel();
    super.dispose();
  }
}

final aiNotifierProvider = StateNotifierProvider<AiNotifier, AiState>((ref) {
  return AiNotifier(ref);
});
