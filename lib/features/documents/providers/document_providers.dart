import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ai_engine/data/gemini_service.dart';
import '../../settings/providers/settings_providers.dart';
import '../data/document_parser_service.dart';
import '../data/document_repository.dart';
import '../data/graph_extractor_service.dart';
import '../domain/models/doc_graph.dart';
import '../domain/models/uploaded_document.dart';

class DocumentState {
  final List<UploadedDocument> documents;
  final bool isProcessing;
  final String? error;

  DocumentState({
    required this.documents,
    this.isProcessing = false,
    this.error,
  });

  DocumentState copyWith({
    List<UploadedDocument>? documents,
    bool? isProcessing,
    String? error,
  }) {
    return DocumentState(
      documents: documents ?? this.documents,
      isProcessing: isProcessing ?? this.isProcessing,
      error: error,
    );
  }
}

class DocumentNotifier extends StateNotifier<DocumentState> {
  final Ref _ref;
  final DocumentParserService _parserService = DocumentParserService();
  final GeminiService _geminiService = GeminiService();
  final GraphExtractorService _graphExtractor = GraphExtractorService();

  final DocumentRepository _repository;
  final bool _persist;
  Timer? _saveTimer;

  /// [persist] false keeps everything in memory (tests, screenshot harness).
  DocumentNotifier(this._ref, {DocumentRepository? repository, bool persist = true})
      : _repository = repository ?? DocumentRepository(),
        // ignore: prefer_initializing_formals
        _persist = persist,
        super(DocumentState(documents: [])) {
    if (_persist) _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await _repository.load();
    if (!mounted || saved.isEmpty) return;
    // anything uploaded while loading stays; saved ones come first
    final ids = {for (final d in state.documents) d.id};
    state = state.copyWith(documents: [...saved.where((d) => !ids.contains(d.id)), ...state.documents]);
  }

  @override
  set state(DocumentState value) {
    final changed = !identical(value.documents, super.state.documents);
    super.state = value;
    if (_persist && changed) {
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(milliseconds: 600), () => _repository.save(super.state.documents));
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  /// User selects files via native file picker dialog.
  Future<void> pickAndAddDocuments() async {
    state = state.copyWith(isProcessing: true, error: null);
    try {
      final parsedDocs = await _parserService.pickAndParseDocuments();
      if (parsedDocs.isEmpty) {
        state = state.copyWith(isProcessing: false);
        return;
      }
      await _processParsedDocuments(parsedDocs);
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: e.toString());
    }
  }

  /// User drops files via drag-and-drop or explicit paths.
  Future<void> addDocumentsFromPaths(List<String> filePaths) async {
    if (filePaths.isEmpty) return;
    state = state.copyWith(isProcessing: true, error: null);

    try {
      final List<UploadedDocument> parsedDocs = [];
      for (final path in filePaths) {
        final doc = await _parserService.parseFilePath(path);
        parsedDocs.add(doc);
      }
      await _processParsedDocuments(parsedDocs);
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: e.toString());
    }
  }

  Future<void> _processParsedDocuments(List<UploadedDocument> newDocs) async {
    // Add new docs to state initially in parsing / error state
    final updatedDocs = List<UploadedDocument>.from(state.documents)..addAll(newDocs);
    state = state.copyWith(documents: updatedDocs);

    final apiKey = _ref.read(settingsNotifierProvider).geminiApiKey.trim();

    // Summarize valid parsed documents
    for (int i = 0; i < state.documents.length; i++) {
      final doc = state.documents[i];
      if (doc.status == DocStatus.parsing) {
        // Transition to summarizing
        _updateDocStatus(doc.id, DocStatus.summarizing);

        String? summaryText;
        if (apiKey.isNotEmpty && doc.fullText.isNotEmpty) {
          try {
            summaryText = await _geminiService.summarizeDocument(
              apiKey: apiKey,
              text: doc.fullText,
            );
          } catch (_) {
            // Graceful fallback: skip summary if API call fails
            summaryText = null;
          }
        }

        // Transition to ready: keyword retrieval works from here on.
        _updateDocStatus(
          doc.id,
          DocStatus.ready,
          summary: summaryText,
        );

        // Graph is built in the background and never blocks the document.
        if (doc.fullText.isNotEmpty) {
          _buildGraph(doc.id);
        }
      }
    }

    state = state.copyWith(isProcessing: false);
  }

  void _setGraph(String id, GraphStatus status, {DocGraph? graph}) {
    state = state.copyWith(
      documents: [
        for (final d in state.documents)
          d.id == id ? d.copyWith(graphStatus: status, graph: graph) : d,
      ],
    );
  }

  /// Extracts entities/relations with Gemini and attaches the graph. Safe to
  /// call again to retry; a failure only marks the graph as failed.
  Future<void> _buildGraph(String id) async {
    final apiKey = _ref.read(settingsNotifierProvider).geminiApiKey.trim();
    if (apiKey.isEmpty) return; // keyword retrieval only

    final matches = state.documents.where((d) => d.id == id);
    if (matches.isEmpty || matches.first.chunks.isEmpty) return;
    final chunks = matches.first.chunks;

    _setGraph(id, GraphStatus.building);
    try {
      final graph = await _graphExtractor.build(
        chunks: chunks,
        generate: (prompt) => _geminiService.generateGraphJson(apiKey: apiKey, prompt: prompt),
      );
      // The document may have been removed while Gemini was working.
      if (!state.documents.any((d) => d.id == id)) return;
      _setGraph(id, graph.isEmpty ? GraphStatus.failed : GraphStatus.ready, graph: graph);
    } catch (_) {
      if (state.documents.any((d) => d.id == id)) _setGraph(id, GraphStatus.failed);
    }
  }

  Future<void> retryGraph(String id) => _buildGraph(id);

  void _updateDocStatus(String id, DocStatus newStatus, {String? summary, String? error}) {
    final updatedList = state.documents.map((doc) {
      if (doc.id == id) {
        return doc.copyWith(
          status: newStatus,
          summary: summary ?? doc.summary,
          error: error ?? doc.error,
        );
      }
      return doc;
    }).toList();
    state = state.copyWith(documents: updatedList);
  }

  void removeDocument(String id) {
    final updatedList = state.documents.where((doc) => doc.id != id).toList();
    state = state.copyWith(documents: updatedList);
  }

  void togglePin(String id) {
    final updatedList = state.documents.map((doc) {
      if (doc.id == id) {
        return doc.copyWith(isPinned: !doc.isPinned);
      }
      return doc;
    }).toList();
    state = state.copyWith(documents: updatedList);
  }

  void clearAll() {
    state = DocumentState(documents: []);
  }
}

final documentNotifierProvider =
    StateNotifierProvider<DocumentNotifier, DocumentState>((ref) {
  return DocumentNotifier(ref);
});
