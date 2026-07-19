import 'dart:io';
import 'dart:typed_data';
import 'package:docx_to_text/docx_to_text.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/text_similarity.dart';
import '../domain/models/uploaded_document.dart';

class DocumentParserService {
  final _uuid = const Uuid();

  /// Opens the native file picker dialog and parses selected files.
  Future<List<UploadedDocument>> pickAndParseDocuments() async {
    await FilePicker.skipEntitlementsChecks();
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: AppConstants.supportedDocumentExtensions,
      allowMultiple: true,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return [];
    }

    final List<UploadedDocument> documents = [];
    for (final file in result.files) {
      final doc = await parsePlatformFile(file);
      documents.add(doc);
    }
    return documents;
  }

  /// Parses a single [PlatformFile] picked via file_picker.
  Future<UploadedDocument> parsePlatformFile(PlatformFile file) async {
    final fileName = file.name;
    final ext = file.extension?.toLowerCase() ??
        path.extension(fileName).replaceAll('.', '').toLowerCase();

    Uint8List? bytes = file.bytes;
    if (bytes == null && file.path != null) {
      final fileObj = File(file.path!);
      if (await fileObj.exists()) {
        bytes = await fileObj.readAsBytes();
      }
    }

    return parseBytes(
      bytes: bytes,
      fileName: fileName,
      fileExtension: ext,
      filePath: file.path,
    );
  }

  /// Parses a file path directly (e.g. from desktop drag-and-drop).
  Future<UploadedDocument> parseFilePath(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return UploadedDocument(
        id: _uuid.v4(),
        fileName: path.basename(filePath),
        fileType: path.extension(filePath).replaceAll('.', '').toLowerCase(),
        fullText: '',
        chunks: [],
        keywords: {},
        charCount: 0,
        status: DocStatus.error,
        uploadedAt: DateTime.now(),
        error: 'File does not exist.',
      );
    }

    final bytes = await file.readAsBytes();
    final fileName = path.basename(filePath);
    final ext = path.extension(filePath).replaceAll('.', '').toLowerCase();

    return parseBytes(
      bytes: bytes,
      fileName: fileName,
      fileExtension: ext,
      filePath: filePath,
    );
  }

  /// Parses raw file bytes and extracts text, chunks, and keywords.
  Future<UploadedDocument> parseBytes({
    required Uint8List? bytes,
    required String fileName,
    required String fileExtension,
    String? filePath,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    if (!AppConstants.supportedDocumentExtensions.contains(fileExtension)) {
      return UploadedDocument(
        id: id,
        fileName: fileName,
        fileType: fileExtension,
        fullText: '',
        chunks: [],
        keywords: {},
        charCount: 0,
        status: DocStatus.error,
        uploadedAt: now,
        error: 'Unsupported file extension: .$fileExtension',
      );
    }

    if (bytes == null || bytes.isEmpty) {
      return UploadedDocument(
        id: id,
        fileName: fileName,
        fileType: fileExtension,
        fullText: '',
        chunks: [],
        keywords: {},
        charCount: 0,
        status: DocStatus.error,
        uploadedAt: now,
        error: 'File is empty or could not be read.',
      );
    }

    if (bytes.length > AppConstants.maxDocumentSizeBytes) {
      return UploadedDocument(
        id: id,
        fileName: fileName,
        fileType: fileExtension,
        fullText: '',
        chunks: [],
        keywords: {},
        charCount: 0,
        status: DocStatus.error,
        uploadedAt: now,
        error: 'File size exceeds 10 MB limit.',
      );
    }

    try {
      String extractedText = '';
      if (fileExtension == 'txt' || fileExtension == 'md') {
        extractedText = String.fromCharCodes(bytes);
      } else if (fileExtension == 'pdf') {
        final PdfDocument pdfDoc = PdfDocument(inputBytes: bytes);
        extractedText = PdfTextExtractor(pdfDoc).extractText();
        pdfDoc.dispose();
      } else if (fileExtension == 'docx') {
        extractedText = docxToText(bytes);
      }

      extractedText = extractedText.trim();
      if (extractedText.isEmpty) {
        return UploadedDocument(
          id: id,
          fileName: fileName,
          fileType: fileExtension,
          fullText: '',
          chunks: [],
          keywords: {},
          charCount: 0,
          status: DocStatus.error,
          uploadedAt: now,
          error: 'No readable text extracted from document.',
        );
      }

      final chunks = chunkText(extractedText);
      final docKeywords = <String>{};
      for (final chunk in chunks) {
        docKeywords.addAll(chunk.keywords);
      }

      return UploadedDocument(
        id: id,
        fileName: fileName,
        fileType: fileExtension,
        fullText: extractedText,
        chunks: chunks,
        keywords: docKeywords,
        charCount: extractedText.length,
        status: DocStatus.parsing,
        uploadedAt: now,
      );
    } catch (e) {
      return UploadedDocument(
        id: id,
        fileName: fileName,
        fileType: fileExtension,
        fullText: '',
        chunks: [],
        keywords: {},
        charCount: 0,
        status: DocStatus.error,
        uploadedAt: now,
        error: 'Failed to parse document: ${e.toString()}',
      );
    }
  }

  /// Splits [text] into chunks of ~[AppConstants.documentChunkSize] characters
  /// respecting sentence/paragraph boundaries where possible.
  List<DocumentChunk> chunkText(String text, {int targetChunkSize = AppConstants.documentChunkSize}) {
    if (text.isEmpty) return [];

    final paragraphs = text.split(RegExp(r'\n+'));
    final List<DocumentChunk> chunks = [];
    StringBuffer currentBuffer = StringBuffer();

    for (final paragraph in paragraphs) {
      final trimmedPara = paragraph.trim();
      if (trimmedPara.isEmpty) continue;

      if (currentBuffer.length + trimmedPara.length + 1 <= targetChunkSize) {
        if (currentBuffer.isNotEmpty) currentBuffer.write('\n');
        currentBuffer.write(trimmedPara);
      } else {
        if (currentBuffer.isNotEmpty) {
          final chunkText = currentBuffer.toString();
          chunks.add(DocumentChunk(
            text: chunkText,
            keywords: TextSimilarity.tokenize(chunkText),
          ));
          currentBuffer.clear();
        }

        // If the paragraph itself is larger than targetChunkSize, split by sentence or fixed size
        if (trimmedPara.length > targetChunkSize) {
          final sentences = trimmedPara.split(RegExp(r'(?<=[.!?])\s+'));
          for (final sentence in sentences) {
            if (currentBuffer.length + sentence.length + 1 <= targetChunkSize) {
              if (currentBuffer.isNotEmpty) currentBuffer.write(' ');
              currentBuffer.write(sentence);
            } else {
              if (currentBuffer.isNotEmpty) {
                final chunkText = currentBuffer.toString();
                chunks.add(DocumentChunk(
                  text: chunkText,
                  keywords: TextSimilarity.tokenize(chunkText),
                ));
                currentBuffer.clear();
              }
              if (sentence.length > targetChunkSize) {
                // Hard chunk long sentences
                for (int i = 0; i < sentence.length; i += targetChunkSize) {
                  final end = (i + targetChunkSize < sentence.length)
                      ? i + targetChunkSize
                      : sentence.length;
                  final sub = sentence.substring(i, end);
                  chunks.add(DocumentChunk(
                    text: sub,
                    keywords: TextSimilarity.tokenize(sub),
                  ));
                }
              } else {
                currentBuffer.write(sentence);
              }
            }
          }
        } else {
          currentBuffer.write(trimmedPara);
        }
      }
    }

    if (currentBuffer.isNotEmpty) {
      final chunkText = currentBuffer.toString();
      chunks.add(DocumentChunk(
        text: chunkText,
        keywords: TextSimilarity.tokenize(chunkText),
      ));
    }

    return chunks;
  }
}
