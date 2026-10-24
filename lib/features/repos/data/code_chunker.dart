import '../domain/models/repo_models.dart';
import 'repo_scanner.dart';

/// Splits a file into meaningful chunks (functions, classes, tests, doc
/// sections) with the file path and line range, language-agnostic.
class CodeChunker {
  static const int minChars = 350; // smaller pieces are merged into a neighbour
  static const int maxChars = 1800; // larger pieces are cut at blank lines

  // A declaration starting near the left margin. Works across the common languages.
  static final RegExp _decl = RegExp(
    r'^\s{0,3}(?:export\s+|public\s+|private\s+|protected\s+|internal\s+|static\s+|abstract\s+|final\s+|async\s+|override\s+|default\s+|pub(?:\([a-z]+\))?\s+|@\w+\s+)*'
    r'(?:class|interface|enum|mixin|extension|struct|trait|impl|type|object|func|fn|function|def|void|Future|Widget|const|var|let|test|testWidgets|group|it|describe|describe\.each)\b',
  );
  static final RegExp _nameAfter = RegExp(
    r'\b(?:class|interface|enum|mixin|extension|struct|trait|impl|type|object|func|fn|function|def|test|testWidgets|group|it|describe)\s*[\(\s]?\s*[\x27"`]?([A-Za-z_][\w\.\- ]{0,70})',
  );
  // Dart/Java/TS/C#-style method or function: `ReturnType name(` at the left margin
  static final RegExp _method = RegExp(r'^\s{0,4}(?:[\w<>\[\]\?,\.]+\s+)+([a-z_]\w*)\s*\(');

  static bool isTestPath(String path) {
    final p = path.toLowerCase();
    return p.contains('/test/') ||
        p.startsWith('test/') ||
        p.contains('/tests/') ||
        p.startsWith('tests/') ||
        p.contains('/__tests__/') ||
        p.contains('_test.') ||
        p.contains('.test.') ||
        p.contains('.spec.') ||
        p.contains('_spec.');
  }

  static List<CodeChunk> chunk(String repoId, String path, String content) {
    final lines = content.split('\n');
    if (lines.every((l) => l.trim().isEmpty)) return const [];

    final isDoc = RepoScanner.isDoc(path);
    final kind = isDoc ? ChunkKind.doc : (isTestPath(path) ? ChunkKind.test : ChunkKind.code);

    // 1. boundaries: line indexes where a new piece starts
    final starts = <int>[0];
    for (var i = 1; i < lines.length; i++) {
      final l = lines[i];
      final boundary = isDoc ? RegExp(r'^#{1,4}\s').hasMatch(l) : (_decl.hasMatch(l) || _method.hasMatch(l) && _indent(l) <= 2);
      final afterBlank = lines[i - 1].trim().isEmpty;
      if (boundary && (isDoc || afterBlank || _indent(l) == 0)) starts.add(i);
    }

    // 2. build pieces, attaching leading comments to the declaration below them
    final pieces = <(int, int)>[];
    for (var k = 0; k < starts.length; k++) {
      var s = starts[k];
      final e = k + 1 < starts.length ? starts[k + 1] : lines.length;
      pieces.add((s, e));
    }

    // 3. merge tiny pieces into the previous one, split huge ones at blank lines
    final merged = <(int, int)>[];
    for (final p in pieces) {
      final size = _size(lines, p.$1, p.$2);
      if (merged.isNotEmpty && size < minChars && _size(lines, merged.last.$1, merged.last.$2) + size <= maxChars) {
        merged[merged.length - 1] = (merged.last.$1, p.$2);
      } else {
        merged.add(p);
      }
    }
    final out = <CodeChunk>[];
    for (final p in merged) {
      for (final (s, e) in _splitLarge(lines, p.$1, p.$2)) {
        final text = lines.sublist(s, e).join('\n').trimRight();
        if (text.trim().isEmpty) continue;
        out.add(CodeChunk(
          repoId: repoId,
          path: path,
          startLine: s + 1,
          endLine: e,
          kind: kind,
          symbols: _symbols(lines.sublist(s, e)),
          text: text,
        ));
      }
    }
    return out;
  }

  static int _indent(String l) => l.length - l.trimLeft().length;

  static int _size(List<String> lines, int s, int e) {
    var n = 0;
    for (var i = s; i < e; i++) {
      n += lines[i].length + 1;
    }
    return n;
  }

  static List<(int, int)> _splitLarge(List<String> lines, int s, int e) {
    if (_size(lines, s, e) <= maxChars) return [(s, e)];
    final out = <(int, int)>[];
    var start = s;
    var size = 0;
    var lastBlank = -1;
    for (var i = s; i < e; i++) {
      size += lines[i].length + 1;
      if (lines[i].trim().isEmpty) lastBlank = i;
      if (size > maxChars) {
        final cut = lastBlank > start ? lastBlank + 1 : i + 1;
        out.add((start, cut));
        start = cut;
        size = _size(lines, start, i + 1);
        lastBlank = -1;
      }
    }
    if (start < e) out.add((start, e));
    return out;
  }

  static List<String> _symbols(List<String> lines) {
    final names = <String>{};
    for (final l in lines) {
      if (_indent(l) > 4) continue;
      final m = _nameAfter.firstMatch(l) ?? _method.firstMatch(l);
      final name = m?.group(1)?.trim();
      if (name != null && name.isNotEmpty && name.length >= 3) names.add(name);
      if (names.length >= 12) break;
    }
    return names.toList();
  }
}
