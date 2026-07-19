import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/gemini_service.dart';
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
  Timer? _analysisTimer;
  String _lastAnalyzedTranscript = '';

  static const int _maxInsightsCount = 20;
  static const int _maxTranscriptCharLength = 3000;

  static const Set<String> _stopWords = {
    'the', 'a', 'an', 'and', 'to', 'in', 'of', 'for', 'with', 'on', 'at',
    'by', 'from', 'is', 'are', 'was', 'were', 'be', 'been', 'should', 'could',
    'would', 'that', 'this', 'it', 'as', 'or', 'we', 'you', 'i', 'our', 'your',
  };

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
    final fullText = transcriptState.fullTextTranscript.trim();

    // Do NOT send to Gemini if there is no transcript captured
    if (fullText.isEmpty) {
      if (force) {
        state = state.copyWith(
          isAnalyzing: false,
          error:
              'No transcript captured yet. Start a meeting or speak into the microphone.',
        );
      } else {
        state = state.copyWith(isAnalyzing: false);
      }
      return;
    }

    // Do NOT send to Gemini if there is no NEW transcript since last analysis
    if (!force && fullText == _lastAnalyzedTranscript) {
      state = state.copyWith(isAnalyzing: false);
      return;
    }

    _lastAnalyzedTranscript = fullText;
    state = state.copyWith(isAnalyzing: true, error: null);

    // Sliding window: slice recent portion of transcript if very long
    String transcriptSlice = fullText;
    if (fullText.length > _maxTranscriptCharLength) {
      transcriptSlice = fullText.substring(fullText.length - _maxTranscriptCharLength);
    }

    try {
      final existingTitles = state.insights.map((i) => i.title).take(15).toList();
      final newInsights = await _geminiService.analyzeTranscript(
        apiKey: apiKey,
        transcript: transcriptSlice,
        existingInsightTitles: existingTitles,
      );

      // Client-side multi-pass semantic deduplication fallback
      final uniqueInsights = newInsights
          .where((candidate) => !_isDuplicate(candidate, state.insights))
          .toList();

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
    final candidateTitleNorm = _normalize(candidate.title);
    final candidateDescNorm = _normalize(candidate.description);

    final candidateTitleTokens = _tokenize(candidate.title);
    final candidateDescTokens = _tokenize(candidate.description);

    for (final existing in existingInsights) {
      final existingTitleNorm = _normalize(existing.title);
      final existingDescNorm = _normalize(existing.description);

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
      final existingTitleTokens = _tokenize(existing.title);
      final titleSim = _calculateJaccardSimilarity(candidateTitleTokens, existingTitleTokens);
      if (titleSim >= 0.45) {
        return true;
      }

      final existingDescTokens = _tokenize(existing.description);
      final descSim = _calculateJaccardSimilarity(candidateDescTokens, existingDescTokens);
      if (descSim >= 0.45) {
        return true;
      }
    }
    return false;
  }

  Set<String> _tokenize(String text) {
    final normalized = _normalize(text);
    return normalized
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty && !_stopWords.contains(word))
        .toSet();
  }

  double _calculateJaccardSimilarity(Set<String> setA, Set<String> setB) {
    if (setA.isEmpty || setB.isEmpty) return 0.0;
    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;
    if (union == 0) return 0.0;
    return intersection / union;
  }

  String _normalize(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
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
    final fullText = transcriptState.fullTextTranscript;

    state = state.copyWith(isAnalyzing: true, error: null);

    try {
      final newInsights = await _geminiService.askCopilotQuestion(
        apiKey: apiKey,
        transcript: fullText,
        question: question,
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

  void clearInsights() {
    _lastAnalyzedTranscript = '';
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
