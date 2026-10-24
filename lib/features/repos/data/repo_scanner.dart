import 'dart:io';

class ScannedFile {
  final String relPath; // always with '/'
  final String absPath;
  final String stamp; // "size:modifiedMillis", cheap change detection

  const ScannedFile(this.relPath, this.absPath, this.stamp);
}

/// Finds the files in a repository worth indexing. Skips dependencies, build
/// output, binaries, lockfiles, huge or minified files, and anything that looks
/// like a secret, so none of those are ever read, stored or sent anywhere.
class RepoScanner {
  static const int maxFileBytes = 200 * 1024;
  static const int maxFiles = 6000;

  static const Set<String> _skipDirs = {
    '.git', '.hg', '.svn', 'node_modules', 'build', 'dist', 'out', 'target', 'vendor', 'venv', '.venv', 'env',
    '__pycache__', '.dart_tool', '.idea', '.vscode', '.gradle', 'Pods', 'DerivedData', '.next', '.nuxt',
    'coverage', '.pytest_cache', '.mypy_cache', 'bin', 'obj', '.terraform', 'ephemeral', 'generated', 'scratch',
  };

  static const Set<String> _codeExt = {
    'dart', 'ts', 'tsx', 'js', 'jsx', 'mjs', 'py', 'java', 'kt', 'kts', 'swift', 'go', 'rs', 'rb', 'php', 'cs',
    'cpp', 'cc', 'c', 'h', 'hpp', 'm', 'mm', 'scala', 'sql', 'sh', 'yaml', 'yml', 'toml', 'gradle', 'proto',
    'graphql', 'vue', 'svelte',
  };
  static const Set<String> _docExt = {'md', 'mdx', 'rst', 'txt', 'adoc'};

  static const List<String> _secretNames = [
    '.env', 'id_rsa', 'id_ed25519', 'credentials', 'secrets', 'serviceaccount', 'keystore', '.npmrc', '.pypirc',
  ];
  static const Set<String> _secretExt = {'pem', 'key', 'p12', 'pfx', 'jks', 'keystore', 'crt', 'cer'};

  static const Set<String> _lockNames = {
    'package-lock.json', 'yarn.lock', 'pnpm-lock.yaml', 'pubspec.lock', 'poetry.lock', 'cargo.lock', 'gemfile.lock',
    'composer.lock', 'podfile.lock', 'go.sum',
  };

  static bool isDoc(String path) => _docExt.contains(_ext(path));

  static String _ext(String path) {
    final name = path.split('/').last;
    final i = name.lastIndexOf('.');
    return i <= 0 ? '' : name.substring(i + 1).toLowerCase();
  }

  /// Should this file (path relative to the repo root, '/'-separated) be indexed?
  static bool wanted(String relPath) {
    final parts = relPath.split('/');
    for (final dir in parts.take(parts.length - 1)) {
      // hidden folders (.git, .idea, .agents, .docs, ...) are tooling, not product code
      if (_skipDirs.contains(dir) || dir.startsWith('.')) return false;
    }
    final name = parts.last;
    final lower = name.toLowerCase();
    if (_lockNames.contains(lower)) return false;
    if (_secretExt.contains(_ext(name))) return false;
    for (final s in _secretNames) {
      if (lower == s || lower.startsWith('$s.') || lower.startsWith('${s}_')) return false;
    }
    if (lower.contains('.min.') || lower.endsWith('.g.dart') || lower.endsWith('.freezed.dart') || lower.endsWith('.pb.dart')) {
      return false;
    }
    final ext = _ext(name);
    return _codeExt.contains(ext) || _docExt.contains(ext) || lower == 'dockerfile' || lower == 'makefile';
  }

  /// Walks [root]. Never follows symlinks, never throws on unreadable entries.
  static Future<List<ScannedFile>> scan(String root) async {
    final dir = Directory(root);
    if (!await dir.exists()) throw Exception('Folder not found: $root');
    final prefix = root.endsWith(Platform.pathSeparator) ? root : '$root${Platform.pathSeparator}';
    final out = <ScannedFile>[];

    final stream = dir.list(recursive: true, followLinks: false);
    await for (final e in stream.handleError((_) {})) {
      if (e is! File) continue;
      if (!e.path.startsWith(prefix)) continue;
      final rel = e.path.substring(prefix.length).replaceAll(Platform.pathSeparator, '/');
      if (!wanted(rel)) continue;
      try {
        final stat = await e.stat();
        if (stat.size == 0 || stat.size > maxFileBytes) continue;
        out.add(ScannedFile(rel, e.path, '${stat.size}:${stat.modified.millisecondsSinceEpoch}'));
      } catch (_) {
        continue;
      }
      if (out.length >= maxFiles) break;
    }
    out.sort((a, b) => a.relPath.compareTo(b.relPath));
    return out;
  }
}
