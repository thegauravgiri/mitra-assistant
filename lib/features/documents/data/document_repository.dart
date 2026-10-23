import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../../core/utils/logger.dart';
import '../domain/models/uploaded_document.dart';

/// Keeps uploaded documents (text, chunks, summary, graph) between launches in
/// one JSON file under the app documents folder. A file rather than
/// shared_preferences: documents can be megabytes.
class DocumentRepository {
  final Future<Directory> Function() _directory;
  Future<void> _pending = Future.value(); // serialises writes

  DocumentRepository({Future<Directory> Function()? directory})
      : _directory = directory ?? _defaultDirectory;

  static Future<Directory> _defaultDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/MitraAssistant');
  }

  Future<File> _file() async {
    final dir = await _directory();
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/documents.json');
  }

  Future<List<UploadedDocument>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return [];
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return [];
      return [
        for (final d in jsonDecode(raw) as List<dynamic>) UploadedDocument.fromJson(d as Map<String, dynamic>),
      ];
    } catch (e) {
      AppLogger.error('Could not load saved documents', e);
      return [];
    }
  }

  /// Saves finished documents only; ones still parsing/summarising are skipped.
  Future<void> save(List<UploadedDocument> documents) {
    final snapshot = [
      for (final d in documents)
        if (d.status == DocStatus.ready || d.status == DocStatus.error) d.toJson(),
    ];
    _pending = _pending.then((_) async {
      try {
        final file = await _file();
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(jsonEncode(snapshot));
        await tmp.rename(file.path); // atomic replace, so a crash never leaves half a file
      } catch (e) {
        AppLogger.error('Could not save documents', e);
      }
    });
    return _pending;
  }
}
