import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/core/utils/text_similarity.dart';
import 'package:mitra_assistant/features/documents/data/document_relevance_service.dart';
import 'package:mitra_assistant/features/documents/domain/models/uploaded_document.dart';

void main() {
  late DocumentRelevanceService relevanceService;

  setUp(() {
    relevanceService = DocumentRelevanceService();
  });

  group('DocumentRelevanceService Tests', () {
    final doc1 = UploadedDocument(
      id: 'doc-1',
      fileName: 'architecture.md',
      fileType: 'md',
      fullText: 'Flutter riverpod state management with deepgram transcription architecture.',
      chunks: [
        DocumentChunk(
          text: 'Flutter riverpod state management with deepgram transcription architecture.',
          keywords: TextSimilarity.tokenize('Flutter riverpod state management with deepgram transcription architecture.'),
        ),
      ],
      keywords: TextSimilarity.tokenize('Flutter riverpod state management with deepgram transcription architecture.'),
      summary: 'Architecture overview of Flutter Riverpod and Deepgram transcription.',
      charCount: 75,
      status: DocStatus.ready,
      uploadedAt: DateTime.now(),
    );

    final doc2 = UploadedDocument(
      id: 'doc-2',
      fileName: 'pricing.txt',
      fileType: 'txt',
      fullText: 'Enterprise license costs five hundred dollars per user monthly.',
      chunks: [
        DocumentChunk(
          text: 'Enterprise license costs five hundred dollars per user monthly.',
          keywords: TextSimilarity.tokenize('Enterprise license costs five hundred dollars per user monthly.'),
        ),
      ],
      keywords: TextSimilarity.tokenize('Enterprise license costs five hundred dollars per user monthly.'),
      summary: 'Pricing details for enterprise monthly user licenses.',
      charCount: 63,
      status: DocStatus.ready,
      uploadedAt: DateTime.now(),
    );

    test('ignores off-topic documents when transcript keywords do not match', () {
      final result = relevanceService.getRelevantContext(
        transcriptWindow: 'Let us discuss the weather and lunch plans for today.',
        documents: [doc1, doc2],
        threshold: 0.1,
      );

      expect(result.hasContext, isFalse);
      expect(result.activeDocumentIds, isEmpty);
      expect(result.activeSignature, isEmpty);
    });

    test('selects matching document when transcript talks about its topics', () {
      final result = relevanceService.getRelevantContext(
        transcriptWindow: 'How are we handling riverpod state management in our Flutter architecture?',
        documents: [doc1, doc2],
        threshold: 0.05,
      );

      expect(result.hasContext, isTrue);
      expect(result.activeDocumentIds, contains('doc-1'));
      expect(result.activeDocumentIds, isNot(contains('doc-2')));
      expect(result.documentContext, contains('architecture.md'));
    });

    test('pinned document is always included regardless of transcript keywords', () {
      final pinnedDoc = doc2.copyWith(isPinned: true);

      final result = relevanceService.getRelevantContext(
        transcriptWindow: 'Random transcript about non-matching topics.',
        documents: [doc1, pinnedDoc],
        threshold: 0.1,
      );

      expect(result.hasContext, isTrue);
      expect(result.activeDocumentIds, contains('doc-2'));
      expect(result.documentContext, contains('pricing.txt'));
    });

    test('respects character budget capping', () {
      final result = relevanceService.getRelevantContext(
        transcriptWindow: 'Flutter riverpod state management deepgram enterprise license costs.',
        documents: [doc1, doc2],
        threshold: 0.01,
        maxContextChars: 100, // Small limit
      );

      expect(result.hasContext, isTrue);
      expect(result.documentContext.length, lessThanOrEqualTo(150));
    });
  });
}
