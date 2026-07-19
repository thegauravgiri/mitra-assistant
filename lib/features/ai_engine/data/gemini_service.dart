import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';
import '../domain/models/insight.dart';
import 'prompt_templates.dart';
import '../../../core/utils/logger.dart';

class GeminiService {
  GenerativeModel? _model;
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
  }) async {
    if (apiKey.trim().isEmpty) {
      throw Exception('Gemini API key missing in Settings');
    }
    if (transcript.trim().isEmpty) return [];

    _initModel(apiKey.trim());

    try {
      final prompt = PromptTemplates.buildAnalysisPrompt(
        transcript,
        existingInsights: existingInsightTitles,
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
  }) async {
    if (apiKey.trim().isEmpty) {
      throw Exception('Gemini API key missing in Settings');
    }
    if (question.trim().isEmpty) return [];

    _initModel(apiKey.trim());

    try {
      final prompt = PromptTemplates.buildQuestionPrompt(transcript, question);
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
}
