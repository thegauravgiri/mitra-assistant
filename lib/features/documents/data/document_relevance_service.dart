import '../../../core/constants/app_constants.dart';
import '../../../core/utils/text_similarity.dart';
import '../domain/models/uploaded_document.dart';

class DocumentRelevanceResult {
  final String documentContext;
  final Set<String> activeDocumentIds;
  final String activeSignature;

  DocumentRelevanceResult({
    required this.documentContext,
    required this.activeDocumentIds,
    required this.activeSignature,
  });

  bool get hasContext => documentContext.trim().isNotEmpty;
}

class DocumentRelevanceService {
  /// Evaluates relevant documents against a transcript window (and optional user question)
  /// and constructs an assembled document context string capped by [maxContextChars].
  DocumentRelevanceResult getRelevantContext({
    required String transcriptWindow,
    String? questionText,
    required List<UploadedDocument> documents,
    double threshold = AppConstants.documentRelevanceThreshold,
    int maxContextChars = AppConstants.maxDocumentContextChars,
  }) {
    final readyDocs = documents.where((d) => d.status == DocStatus.ready).toList();
    if (readyDocs.isEmpty) {
      return DocumentRelevanceResult(
        documentContext: '',
        activeDocumentIds: {},
        activeSignature: '',
      );
    }

    final queryText = (questionText != null && questionText.trim().isNotEmpty)
        ? '$transcriptWindow ${questionText.trim()}'
        : transcriptWindow;

    final searchTokens = TextSimilarity.tokenize(queryText);

    final List<_DocMatch> matches = [];

    for (final doc in readyDocs) {
      if (doc.isPinned) {
        matches.add(_DocMatch(doc: doc, score: 1.0, isPinned: true));
        continue;
      }

      if (searchTokens.isEmpty) continue;

      final docScore = TextSimilarity.calculateJaccardSimilarity(searchTokens, doc.keywords);
      if (docScore >= threshold) {
        matches.add(_DocMatch(doc: doc, score: docScore, isPinned: false));
      }
    }

    if (matches.isEmpty) {
      return DocumentRelevanceResult(
        documentContext: '',
        activeDocumentIds: {},
        activeSignature: '',
      );
    }

    // Sort by pinned status first, then highest score
    matches.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.score.compareTo(a.score);
    });

    final StringBuffer contextBuffer = StringBuffer();
    final Set<String> activeDocIds = {};

    for (final match in matches) {
      final doc = match.doc;
      final docHeader = '=== Document: ${doc.fileName} ===\n';
      
      StringBuffer docContentBuffer = StringBuffer();
      if (doc.summary != null && doc.summary!.isNotEmpty) {
        docContentBuffer.writeln('Summary: ${doc.summary}');
      }

      // Find top matching chunks
      if (doc.chunks.isNotEmpty) {
        final ratedChunks = doc.chunks.map((chunk) {
          final chunkScore = searchTokens.isEmpty
              ? 0.0
              : TextSimilarity.calculateJaccardSimilarity(searchTokens, chunk.keywords);
          return _ChunkMatch(chunk: chunk, score: chunkScore);
        }).toList();

        ratedChunks.sort((a, b) => b.score.compareTo(a.score));

        for (final rated in ratedChunks) {
          final candidateText = rated.chunk.text;
          if (docContentBuffer.length + candidateText.length + docHeader.length + contextBuffer.length >
              maxContextChars) {
            // Check if we can include a portion or break
            if (docContentBuffer.isEmpty && contextBuffer.isEmpty) {
              // If empty so far, fit as much as possible
              final remainingChars = maxContextChars - docHeader.length - docContentBuffer.length;
              if (remainingChars > 50) {
                docContentBuffer.writeln(candidateText.substring(0, remainingChars));
              }
            }
            break;
          }
          docContentBuffer.writeln('Excerpt: ${rated.chunk.text}');
        }
      }

      if (docContentBuffer.isNotEmpty) {
        if (contextBuffer.length + docHeader.length + docContentBuffer.length <= maxContextChars) {
          contextBuffer.write(docHeader);
          contextBuffer.write(docContentBuffer.toString());
          contextBuffer.writeln();
          activeDocIds.add(doc.id);
        }
      }
    }

    final activeSignature = activeDocIds.isEmpty
        ? ''
        : (activeDocIds.toList()..sort()).join(':');

    return DocumentRelevanceResult(
      documentContext: contextBuffer.toString().trim(),
      activeDocumentIds: activeDocIds,
      activeSignature: activeSignature,
    );
  }
}

class _DocMatch {
  final UploadedDocument doc;
  final double score;
  final bool isPinned;

  _DocMatch({
    required this.doc,
    required this.score,
    required this.isPinned,
  });
}

class _ChunkMatch {
  final DocumentChunk chunk;
  final double score;

  _ChunkMatch({
    required this.chunk,
    required this.score,
  });
}
