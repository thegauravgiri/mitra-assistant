import 'doc_graph.dart';

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

  Map<String, dynamic> toJson() => {'text': text, 'keywords': keywords.toList()};

  factory DocumentChunk.fromJson(Map<String, dynamic> j) => DocumentChunk(
        text: j['text'] as String? ?? '',
        keywords: {for (final k in j['keywords'] as List? ?? const []) k.toString()},
      );
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
  final DocGraph? graph;
  final GraphStatus graphStatus;

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
    this.graph,
    this.graphStatus = GraphStatus.none,
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
    DocGraph? graph,
    GraphStatus? graphStatus,
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
      graph: graph ?? this.graph,
      graphStatus: graphStatus ?? this.graphStatus,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'fileType': fileType,
        'fullText': fullText,
        'chunks': chunks.map((c) => c.toJson()).toList(),
        'keywords': keywords.toList(),
        if (summary != null) 'summary': summary,
        'charCount': charCount,
        'status': status.name,
        'isPinned': isPinned,
        'uploadedAt': uploadedAt.toIso8601String(),
        if (error != null) 'error': error,
        if (graph != null) 'graph': graph!.toJson(),
        'graphStatus': graphStatus.name,
      };

  factory UploadedDocument.fromJson(Map<String, dynamic> j) {
    // A graph build that was interrupted by closing the app is not "building" any more.
    var graphStatus = GraphStatus.values.firstWhere(
      (g) => g.name == j['graphStatus'],
      orElse: () => GraphStatus.none,
    );
    final graph = j['graph'] is Map<String, dynamic> ? DocGraph.fromJson(j['graph'] as Map<String, dynamic>) : null;
    if (graphStatus == GraphStatus.building || (graphStatus == GraphStatus.ready && graph == null)) {
      graphStatus = GraphStatus.none;
    }
    return UploadedDocument(
      id: j['id'] as String? ?? '',
      fileName: j['fileName'] as String? ?? 'document',
      fileType: j['fileType'] as String? ?? 'txt',
      fullText: j['fullText'] as String? ?? '',
      chunks: [for (final c in j['chunks'] as List? ?? const []) DocumentChunk.fromJson(c as Map<String, dynamic>)],
      keywords: {for (final k in j['keywords'] as List? ?? const []) k.toString()},
      summary: j['summary'] as String?,
      charCount: (j['charCount'] as num?)?.toInt() ?? 0,
      status: DocStatus.values.firstWhere((d) => d.name == j['status'], orElse: () => DocStatus.ready),
      isPinned: j['isPinned'] as bool? ?? false,
      uploadedAt: DateTime.tryParse(j['uploadedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      error: j['error'] as String?,
      graph: graph,
      graphStatus: graphStatus,
    );
  }
}
