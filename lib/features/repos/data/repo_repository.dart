import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../../core/utils/logger.dart';
import '../domain/models/repo_models.dart';

/// One JSON file per repository under `Documents/MitraAssistant/repos/`, so a
/// big repository does not slow down saving the others. Atomic, serialised
/// writes; a damaged file is skipped instead of crashing.
class RepoRepository {
  final Future<Directory> Function() _directory;
  Future<void> _pending = Future.value();

  RepoRepository({Future<Directory> Function()? directory}) : _directory = directory ?? _defaultDirectory;

  static Future<Directory> _defaultDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/MitraAssistant/repos');
  }

  Future<Directory> _dir() async {
    final d = await _directory();
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<List<RepoData>> loadAll() async {
    final out = <RepoData>[];
    try {
      final dir = await _dir();
      await for (final e in dir.list()) {
        if (e is! File || !e.path.endsWith('.json')) continue;
        try {
          out.add(RepoData.fromJson(jsonDecode(await e.readAsString()) as Map<String, dynamic>));
        } catch (err) {
          AppLogger.error('Skipping unreadable repository file ${e.path}', err);
        }
      }
    } catch (e) {
      AppLogger.error('Could not load repositories', e);
    }
    out.sort((a, b) => (a.source.indexedAt ?? DateTime(0)).compareTo(b.source.indexedAt ?? DateTime(0)));
    return out;
  }

  Future<void> save(RepoData data) {
    final json = jsonEncode(data.toJson());
    _pending = _pending.then((_) async {
      try {
        final dir = await _dir();
        final file = File('${dir.path}/${data.source.id}.json');
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(json);
        await tmp.rename(file.path);
      } catch (e) {
        AppLogger.error('Could not save repository ${data.source.name}', e);
      }
    });
    return _pending;
  }

  Future<void> delete(String id) {
    _pending = _pending.then((_) async {
      try {
        final file = File('${(await _dir()).path}/$id.json');
        if (await file.exists()) await file.delete();
      } catch (e) {
        AppLogger.error('Could not delete repository file', e);
      }
    });
    return _pending;
  }
}
