enum DocStatus {
  parsing,
  summarizing,
  ready,
  error,
}

class DocumentChunk {
  final String text;
  final Set<String> keywords;

  DocumentChunk({
    required this.text,
    required this.keywords,
  });
}

class UploadedDocument {
  final String id;
  final String fileName;
  final String fileType;
  final String fullText;
  final List<DocumentChunk> chunks;
  final Set<String> keywords;
  final String? summary;
  final int charCount;
  final DocStatus status;
  final bool isPinned;
  final DateTime uploadedAt;
  final String? error;

  UploadedDocument({
    required this.id,
    required this.fileName,
    required this.fileType,
    required this.fullText,
    required this.chunks,
    required this.keywords,
    this.summary,
    required this.charCount,
    required this.status,
    this.isPinned = false,
    required this.uploadedAt,
    this.error,
  });

  UploadedDocument copyWith({
    String? id,
    String? fileName,
    String? fileType,
    String? fullText,
    List<DocumentChunk>? chunks,
    Set<String>? keywords,
    String? summary,
    int? charCount,
    DocStatus? status,
    bool? isPinned,
    DateTime? uploadedAt,
    String? error,
  }) {
    return UploadedDocument(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      fullText: fullText ?? this.fullText,
      chunks: chunks ?? this.chunks,
      keywords: keywords ?? this.keywords,
      summary: summary ?? this.summary,
      charCount: charCount ?? this.charCount,
      status: status ?? this.status,
      isPinned: isPinned ?? this.isPinned,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      error: error ?? this.error,
    );
  }
}
