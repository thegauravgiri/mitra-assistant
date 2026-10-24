import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';
import '../domain/models/insight.dart';
import 'prompt_templates.dart';
import '../../../core/utils/logger.dart';

class GeminiService {
  GenerativeModel? _model;
  GenerativeModel? _graphModel;
  String? _graphApiKey;
  String? _currentApiKey;

  void _initModel(String apiKey) {
    final cleanKey = apiKey.trim();
    if (_model != null && _currentApiKey == cleanKey) return;
    _currentApiKey = cleanKey;
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: cleanKey,
      systemInstruction: Content.system(PromptTemplates.systemPrompt),
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.2,
      ),
    );
  }

  String _cleanJsonString(String rawText) {
    var text = rawText.trim();
    // Remove markdown code fence if present
    if (text.startsWith('```')) {
      text = text.replaceAll(
        RegExp(r'^```(json)?\s*', caseSensitive: false),
        '',
      );
      text = text.replaceAll(RegExp(r'\s*```$'), '');
    }
    return text.trim();
  }

  List<Insight> _parseInsightsJson(String text) {
    final cleanedText = _cleanJsonString(text);
    if (cleanedText.isEmpty) return [];

    dynamic parsed;
    try {
      parsed = jsonDecode(cleanedText);
    } catch (_) {
      // Fallback: search for JSON array or object inside string
      final match = RegExp(
        r'\[\s*\{.*\}\s*\]',
        dotAll: true,
      ).firstMatch(cleanedText);
      if (match != null) {
        try {
          parsed = jsonDecode(match.group(0)!);
        } catch (_) {}
      }
    }

    if (parsed == null) return [];

    List<dynamic> itemsList = [];
    if (parsed is List) {
      itemsList = parsed;
    } else if (parsed is Map<String, dynamic>) {
      // If output is wrapped inside a key e.g. {"insights": [...]}
      for (final val in parsed.values) {
        if (val is List) {
          itemsList = val;
          break;
        }
      }
    }

    final List<Insight> insights = [];
    for (final item in itemsList) {
      if (item is Map<String, dynamic>) {
        final catString = item['category'] as String? ?? 'suggestion';
        InsightCategory category;
        switch (catString) {
          case 'keyPoint':
            category = InsightCategory.keyPoint;
            break;
          case 'question':
            category = InsightCategory.question;
            break;
          case 'actionItem':
            category = InsightCategory.actionItem;
            break;
          case 'answer':
            category = InsightCategory.answer;
            break;
          case 'unansweredQuestion':
            category = InsightCategory.unansweredQuestion;
            break;
          default:
            category = InsightCategory.suggestion;
        }

        insights.add(
          Insight(
            id: const Uuid().v4(),
            category: category,
            title: item['title'] as String? ?? 'Context Insight',
            description: item['description'] as String? ?? '',
            timestamp: DateTime.now(),
          ),
        );
      }
    }

    return insights;
  }

  Future<List<Insight>> analyzeTranscript({
    required String apiKey,
    required String transcript,
    List<String> existingInsightTitles = const [],
    String documentContext = '',
    String earlierMeetings = '',
    String meetingSoFar = '',
    String repoContext = '',
  }) async {
    if (apiKey.trim().isEmpty) {
      throw Exception('Gemini API key missing in Settings');
    }
    if (transcript.trim().isEmpty && documentContext.trim().isEmpty) return [];

    _initModel(apiKey.trim());

    try {
      final prompt = PromptTemplates.buildAnalysisPrompt(
        transcript,
        existingInsights: existingInsightTitles,
        documentContext: documentContext,
        earlierMeetings: earlierMeetings,
        meetingSoFar: meetingSoFar,
        repoContext: repoContext,
      );
      final response = await _model?.generateContent([Content.text(prompt)]);
      final text = response?.text;

      if (text == null || text.trim().isEmpty) return [];

      return _parseInsightsJson(text);
    } catch (e) {
      AppLogger.error('Error during Gemini transcript analysis', e);
      final errStr = e.toString();
      if (errStr.contains('API_KEY_INVALID') ||
          errStr.toLowerCase().contains('api key')) {
        throw Exception(
          'Invalid Gemini API Key. Please check your key in Settings.',
        );
      }
      throw Exception(
        'Gemini AI Error: ${errStr.replaceAll('Exception: ', '')}',
      );
    }
  }

  Future<List<Insight>> askCopilotQuestion({
    required String apiKey,
    required String transcript,
    required String question,
    String documentContext = '',
    String earlierMeetings = '',
    String meetingSoFar = '',
    String repoContext = '',
  }) async {
    if (apiKey.trim().isEmpty) {
      throw Exception('Gemini API key missing in Settings');
    }
    if (question.trim().isEmpty) return [];

    _initModel(apiKey.trim());

    try {
      final prompt = PromptTemplates.buildQuestionPrompt(
        transcript,
        question,
        documentContext: documentContext,
        earlierMeetings: earlierMeetings,
        meetingSoFar: meetingSoFar,
        repoContext: repoContext,
      );
      final response = await _model?.generateContent([Content.text(prompt)]);
      final text = response?.text;

      if (text == null || text.trim().isEmpty) return [];

      return _parseInsightsJson(text);
    } catch (e) {
      AppLogger.error('Error during Gemini user question query', e);
      throw Exception(
        'Gemini AI Error: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }

  /// One-shot plain-text call with its own system prompt (running notes,
  /// document summaries). Returns '' on failure instead of throwing, because
  /// these are enrichment steps that must never block the meeting.
  Future<String> generateText({
    required String apiKey,
    required String systemPrompt,
    required String prompt,
    double temperature = 0.2,
  }) async {
    if (apiKey.trim().isEmpty || prompt.trim().isEmpty) return '';
    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey.trim(),
        systemInstruction: Content.system(systemPrompt),
        generationConfig: GenerationConfig(temperature: temperature),
      );
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? '';
    } catch (e) {
      AppLogger.error('Text generation failed', e);
      return '';
    }
  }

  /// Updates the running notes of a live meeting with a new stretch of transcript.
  Future<String> updateMeetingSummary({
    required String apiKey,
    required String previousNotes,
    required String newTranscript,
  }) =>
      generateText(
        apiKey: apiKey,
        systemPrompt: PromptTemplates.meetingSummarySystemPrompt,
        prompt: PromptTemplates.buildMeetingSummaryPrompt(previousNotes, newTranscript),
      );

  /// Summary of an uploaded document. Very long documents are summarised from
  /// their start and end, so the call stays within limits.
  Future<String> summarizeDocument({
    required String apiKey,
    required String text,
  }) {
    const max = 60000;
    final body = text.length <= max ? text : '${text.substring(0, max ~/ 2)}\n[...]\n${text.substring(text.length - max ~/ 2)}';
    return generateText(
      apiKey: apiKey,
      systemPrompt: PromptTemplates.documentSummarySystemPrompt,
      prompt: PromptTemplates.buildDocumentSummaryPrompt(body),
    );
  }

  /// Raw JSON text for one graph-extraction batch (parsed by
  /// `GraphExtractorService`). Own model: low temperature, graph system prompt.
  Future<String> generateGraphJson({
    required String apiKey,
    required String prompt,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) throw Exception('Gemini API key missing in Settings');
    if (_graphModel == null || _graphApiKey != key) {
      _graphApiKey = key;
      _graphModel = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: key,
        systemInstruction: Content.system(PromptTemplates.graphSystemPrompt),
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.1,
        ),
      );
    }
    final response = await _graphModel?.generateContent([Content.text(prompt)]);
    return response?.text ?? '';
  }

  /// One-off JSON-mode call with its own system prompt (digest, coaching).
  /// Low frequency, so the model object is not cached.
  Future<String> generateStructured({
    required String apiKey,
    required String systemPrompt,
    required String prompt,
    double temperature = 0.2,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) throw Exception('Gemini API key missing in Settings');
    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: key,
      systemInstruction: Content.system(systemPrompt),
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: temperature,
      ),
    );
    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? '';
    } catch (e) {
      AppLogger.error('Structured Gemini call failed', e);
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
