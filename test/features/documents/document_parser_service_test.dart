import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra_assistant/features/documents/data/document_parser_service.dart';
import 'package:mitra_assistant/features/documents/domain/models/uploaded_document.dart';

void main() {
  late DocumentParserService parserService;

  setUp(() {
    parserService = DocumentParserService();
  });

  group('DocumentParserService Tests', () {
    test('parseBytes handles plain TXT file correctly', () async {
      final sampleText = 'Hello world. This is a test document for Mitra Assistant.';
      final bytes = Uint8List.fromList(sampleText.codeUnits);

      final doc = await parserService.parseBytes(
        bytes: bytes,
        fileName: 'test.txt',
        fileExtension: 'txt',
      );

      expect(doc.status, equals(DocStatus.parsing));
      expect(doc.fileName, equals('test.txt'));
      expect(doc.fileType, equals('txt'));
      expect(doc.fullText, equals(sampleText));
      expect(doc.chunks, isNotEmpty);
      expect(doc.keywords, containsAll({'hello', 'world', 'test', 'document'}));
    });

    test('parseBytes rejects unsupported file extensions', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);

      final doc = await parserService.parseBytes(
        bytes: bytes,
        fileName: 'invalid.exe',
        fileExtension: 'exe',
      );

      expect(doc.status, equals(DocStatus.error));
      expect(doc.error, contains('Unsupported file extension'));
    });

    test('chunkText splits text respecting paragraph and sentence boundaries', () {
      final longText = 'Paragraph 1 sentence 1. Paragraph 1 sentence 2.\n\nParagraph 2 sentence 1. Paragraph 2 sentence 2.';

      final chunks = parserService.chunkText(longText, targetChunkSize: 50);

      expect(chunks, isNotEmpty);
      for (final chunk in chunks) {
        expect(chunk.text.length, lessThanOrEqualTo(100)); // reasonably sized
        expect(chunk.keywords, isNotEmpty);
      }
    });
  });
}
