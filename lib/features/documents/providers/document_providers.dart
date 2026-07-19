import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ai_engine/data/gemini_service.dart';
import '../../settings/providers/settings_providers.dart';
import '../data/document_parser_service.dart';
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

  DocumentNotifier(this._ref) : super(DocumentState(documents: []));

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

        // Transition to ready
        _updateDocStatus(
          doc.id,
          DocStatus.ready,
          summary: summaryText,
        );
      }
    }

    state = state.copyWith(isProcessing: false);
  }

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
