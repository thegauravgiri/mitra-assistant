enum RepoStatus { indexing, ready, error }

enum ChunkKind { code, test, doc }

/// One piece of a repository: a function, class, test or doc section.
class CodeChunk {
  final String repoId;
  final String path; // relative to the repo root
  final int startLine;
  final int endLine;
  final ChunkKind kind;
  final List<String> symbols; // names declared in this chunk
  final String text;

  /// Plain-English account of the file this chunk is in (filled by the notes
  /// step; links business wording to code). Null until then.
  final String? summary;

  const CodeChunk({
    required this.repoId,
    required this.path,
    required this.startLine,
    required this.endLine,
    required this.kind,
    required this.symbols,
    required this.text,
    this.summary,
  });

  String get ref => '$path:$startLine-$endLine';

  CodeChunk withSummary(String? s) => CodeChunk(
        repoId: repoId,
        path: path,
        startLine: startLine,
        endLine: endLine,
        kind: kind,
        symbols: symbols,
        text: text,
        summary: s,
      );

  Map<String, dynamic> toJson() => {
        'p': path,
        's': startLine,
        'e': endLine,
        'k': kind.name,
        if (symbols.isNotEmpty) 'y': symbols,
        't': text,
        if (summary != null) 'u': summary,
      };

  factory CodeChunk.fromJson(String repoId, Map<String, dynamic> j) => CodeChunk(
        repoId: repoId,
        path: j['p'] as String? ?? '',
        startLine: (j['s'] as num?)?.toInt() ?? 1,
        endLine: (j['e'] as num?)?.toInt() ?? 1,
        kind: ChunkKind.values.firstWhere((k) => k.name == j['k'], orElse: () => ChunkKind.code),
        symbols: [for (final s in j['y'] as List? ?? const []) s.toString()],
        text: j['t'] as String? ?? '',
        summary: j['u'] as String?,
      );
}

/// A likely client question with a ready answer, written when the notes are
/// built, so it can be shown instantly with no AI call during the meeting.
class ScenarioCard {
  final String question;
  final String answer;
  final List<String> sources; // file paths

  const ScenarioCard({required this.question, required this.answer, this.sources = const []});

  Map<String, dynamic> toJson() => {'q': question, 'a': answer, if (sources.isNotEmpty) 's': sources};

  factory ScenarioCard.fromJson(Map<String, dynamic> j) => ScenarioCard(
        question: j['q'] as String? ?? '',
        answer: j['a'] as String? ?? '',
        sources: [for (final s in j['s'] as List? ?? const []) s.toString()],
      );
}

class RepoSource {
  final String id;
  final String name;
  final String path; // absolute folder on this machine
  final bool enabled; // used in meetings
  final RepoStatus status;
  final int fileCount;
  final int chunkCount;
  final int summarisedFiles;
  final DateTime? indexedAt;
  final String? error;

  const RepoSource({
    required this.id,
    required this.name,
    required this.path,
    this.enabled = true,
    this.status = RepoStatus.indexing,
    this.fileCount = 0,
    this.chunkCount = 0,
    this.summarisedFiles = 0,
    this.indexedAt,
    this.error,
  });

  RepoSource copyWith({
    String? name,
    bool? enabled,
    RepoStatus? status,
    int? fileCount,
    int? chunkCount,
    int? summarisedFiles,
    DateTime? indexedAt,
    Object? error = _keep,
  }) =>
      RepoSource(
        id: id,
        name: name ?? this.name,
        path: path,
        enabled: enabled ?? this.enabled,
        status: status ?? this.status,
        fileCount: fileCount ?? this.fileCount,
        chunkCount: chunkCount ?? this.chunkCount,
        summarisedFiles: summarisedFiles ?? this.summarisedFiles,
        indexedAt: indexedAt ?? this.indexedAt,
        error: identical(error, _keep) ? this.error : error as String?,
      );

  static const Object _keep = Object();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'enabled': enabled,
        'status': status.name,
        'fileCount': fileCount,
        'chunkCount': chunkCount,
        'summarisedFiles': summarisedFiles,
        if (indexedAt != null) 'indexedAt': indexedAt!.toIso8601String(),
        if (error != null) 'error': error,
      };

  factory RepoSource.fromJson(Map<String, dynamic> j) {
    var status = RepoStatus.values.firstWhere((s) => s.name == j['status'], orElse: () => RepoStatus.ready);
    if (status == RepoStatus.indexing) status = RepoStatus.error; // interrupted by quitting
    return RepoSource(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? 'repository',
      path: j['path'] as String? ?? '',
      enabled: j['enabled'] as bool? ?? true,
      status: status,
      fileCount: (j['fileCount'] as num?)?.toInt() ?? 0,
      chunkCount: (j['chunkCount'] as num?)?.toInt() ?? 0,
      summarisedFiles: (j['summarisedFiles'] as num?)?.toInt() ?? 0,
      indexedAt: DateTime.tryParse(j['indexedAt'] as String? ?? ''),
      error: status == RepoStatus.error && j['status'] == 'indexing'
          ? 'Indexing was interrupted. Refresh to finish.'
          : j['error'] as String?,
    );
  }
}

/// Everything stored for one repository.
class RepoData {
  final RepoSource source;
  final List<CodeChunk> chunks;

  /// relative path -> "size:modified", to re-index only changed files.
  final Map<String, String> files;
  final List<ScenarioCard> scenarios;

  const RepoData({
    required this.source,
    this.chunks = const [],
    this.files = const {},
    this.scenarios = const [],
  });

  RepoData copyWith({RepoSource? source, List<CodeChunk>? chunks, Map<String, String>? files, List<ScenarioCard>? scenarios}) =>
      RepoData(
        source: source ?? this.source,
        chunks: chunks ?? this.chunks,
        files: files ?? this.files,
        scenarios: scenarios ?? this.scenarios,
      );

  Map<String, dynamic> toJson() => {
        'source': source.toJson(),
        'files': files,
        'chunks': chunks.map((c) => c.toJson()).toList(),
        if (scenarios.isNotEmpty) 'scenarios': scenarios.map((s) => s.toJson()).toList(),
      };

  factory RepoData.fromJson(Map<String, dynamic> j) {
    final source = RepoSource.fromJson(j['source'] as Map<String, dynamic>);
    return RepoData(
      source: source,
      files: (j['files'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, v.toString())),
      chunks: [for (final c in j['chunks'] as List? ?? const []) CodeChunk.fromJson(source.id, c as Map<String, dynamic>)],
      scenarios: [for (final s in j['scenarios'] as List? ?? const []) ScenarioCard.fromJson(s as Map<String, dynamic>)],
    );
  }
}
