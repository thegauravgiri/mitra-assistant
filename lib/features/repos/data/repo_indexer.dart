import 'dart:convert';
import 'dart:io';
import '../domain/models/repo_models.dart';
import 'code_chunker.dart';
import 'repo_scanner.dart';

/// Reads a repository and turns it into chunks. Incremental: a file whose size
/// and modified time are unchanged keeps its chunks (and any plain-English
/// notes already written for it), so a refresh only re-reads what changed.
class RepoIndexer {
  static const int maxChunksPerRepo = 60000;

  static Future<RepoData> index(
    RepoSource source, {
    RepoData? previous,
    void Function(double fraction, String label)? onProgress,
  }) async {
    final scanned = await RepoScanner.scan(source.path);

    final previousByPath = <String, List<CodeChunk>>{};
    for (final c in previous?.chunks ?? const <CodeChunk>[]) {
      (previousByPath[c.path] ??= []).add(c);
    }

    final chunks = <CodeChunk>[];
    final files = <String, String>{};
    for (var i = 0; i < scanned.length; i++) {
      final f = scanned[i];
      final unchanged = previous?.files[f.relPath] == f.stamp && previousByPath.containsKey(f.relPath);
      if (unchanged) {
        chunks.addAll(previousByPath[f.relPath]!);
        files[f.relPath] = f.stamp;
      } else {
        final text = await _read(f.absPath);
        if (text != null) {
          final cs = CodeChunker.chunk(source.id, f.relPath, text);
          if (cs.isNotEmpty) {
            chunks.addAll(cs);
            files[f.relPath] = f.stamp;
          }
        }
      }
      if (chunks.length >= maxChunksPerRepo) break;
      if (i % 20 == 19) {
        onProgress?.call((i + 1) / scanned.length, 'Reading ${i + 1} of ${scanned.length} files');
        await Future<void>.delayed(Duration.zero); // keep the UI responsive
      }
    }

    // keep ready-made answers only while every file they cite still exists
    final scenarios = [
      for (final s in previous?.scenarios ?? const <ScenarioCard>[])
        if (s.sources.every(files.containsKey)) s,
    ];

    final summarised = {for (final c in chunks) if (c.summary != null) c.path}.length;
    return RepoData(
      source: source.copyWith(
        status: RepoStatus.ready,
        fileCount: files.length,
        chunkCount: chunks.length,
        summarisedFiles: summarised,
        indexedAt: DateTime.now(),
        error: null,
      ),
      chunks: chunks,
      files: files,
      scenarios: scenarios,
    );
  }

  /// UTF-8 text, or null for binary / undecodable files.
  static Future<String?> _read(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      if (bytes.contains(0)) return null; // NUL byte: binary
      return utf8.decode(bytes);
    } catch (_) {
      return null;
    }
  }
}
