import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../ai_engine/data/gemini_service.dart';
import '../../settings/providers/settings_providers.dart';
import '../data/bm25_index.dart';
import '../data/repo_indexer.dart';
import '../data/repo_repository.dart';
import '../data/repo_retrieval.dart';
import '../data/repo_summarizer.dart';
import '../domain/models/repo_models.dart';

class RepoState {
  final List<RepoSource> repos;
  final String? busyId; // repository being indexed or explained
  final String busyLabel;
  final double? progress; // 0..1, null = unknown
  final String? error;

  const RepoState({this.repos = const [], this.busyId, this.busyLabel = '', this.progress, this.error});

  RepoState copyWith({
    List<RepoSource>? repos,
    Object? busyId = _keep,
    String? busyLabel,
    Object? progress = _keep,
    Object? error = _keep,
  }) =>
      RepoState(
        repos: repos ?? this.repos,
        busyId: identical(busyId, _keep) ? this.busyId : busyId as String?,
        busyLabel: busyLabel ?? this.busyLabel,
        progress: identical(progress, _keep) ? this.progress : progress as double?,
        error: identical(error, _keep) ? this.error : error as String?,
      );

  static const Object _keep = Object();

  int get enabledCount => repos.where((r) => r.enabled && r.status == RepoStatus.ready).length;
}

/// Owns the connected repositories and the in-memory search index over them.
/// Searching ([contextFor]) is synchronous and takes milliseconds, so the live
/// analysis can call it on every question.
class RepoNotifier extends StateNotifier<RepoState> {
  final Ref _ref;
  final RepoRepository _repository;
  final bool _persist;
  final NotesGenerate? _notesGenerator; // tests inject a fake model
  final GeminiService _gemini = GeminiService();

  final Map<String, RepoData> _data = {};
  RepoRetrieval? _retrieval;
  int _rebuildToken = 0;

  RepoNotifier(this._ref, {RepoRepository? repository, bool persist = true, NotesGenerate? notesGenerator})
      : _repository = repository ?? RepoRepository(),
        // ignore: prefer_initializing_formals
        _notesGenerator = notesGenerator,
        // ignore: prefer_initializing_formals
        _persist = persist,
        super(const RepoState()) {
    if (_persist) _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await _repository.loadAll();
    if (!mounted || saved.isEmpty) return;
    for (final d in saved) {
      _data.putIfAbsent(d.source.id, () => d);
    }
    state = state.copyWith(repos: [for (final d in _data.values) d.source]);
    await _rebuild();
  }

  /// Connects a folder, then reads it. Returns false if it was already connected.
  Future<bool> addRepo(String path) async {
    final clean = path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    if (_data.values.any((d) => d.source.path == clean)) {
      state = state.copyWith(error: 'That folder is already connected.');
      return false;
    }
    final name = clean.split(RegExp(r'[/\\]')).where((p) => p.isNotEmpty).last;
    final source = RepoSource(id: const Uuid().v4(), name: name, path: clean);
    _data[source.id] = RepoData(source: source);
    state = state.copyWith(repos: [...state.repos, source], error: null);
    await _index(source.id);
    return true;
  }

  Future<void> refresh(String id) => _index(id);

  Future<void> _index(String id) async {
    final previous = _data[id];
    if (previous == null) return;
    _setSource(id, previous.source.copyWith(status: RepoStatus.indexing, error: null));
    state = state.copyWith(busyId: id, busyLabel: 'Reading files', progress: 0.0, error: null);
    try {
      final data = await RepoIndexer.index(
        previous.source,
        previous: previous,
        onProgress: (f, label) {
          if (mounted) state = state.copyWith(progress: f, busyLabel: label);
        },
      );
      _data[id] = data;
      _setSource(id, data.source);
      if (_persist) await _repository.save(data);
      await _rebuild();
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      _setSource(id, previous.source.copyWith(status: RepoStatus.error, error: msg));
      state = state.copyWith(error: msg);
    } finally {
      if (mounted) state = state.copyWith(busyId: null, busyLabel: '', progress: null);
    }
  }

  /// Writes plain-English notes and ready-made scenario answers for the most
  /// important files. Sends file contents to Gemini once; needs the Gemini key.
  Future<void> buildNotes(String id, {bool force = false}) async {
    final data = _data[id];
    if (data == null) return;
    final apiKey = _ref.read(settingsNotifierProvider).geminiApiKey;
    if (apiKey.trim().isEmpty) {
      state = state.copyWith(error: 'Add your Gemini API key in Settings to build plain-English notes.');
      return;
    }
    final files = RepoSummarizer.selectFiles(data, force: force);
    if (files.isEmpty) {
      state = state.copyWith(error: 'Nothing new to explain: every important file already has notes.');
      return;
    }

    state = state.copyWith(busyId: id, busyLabel: 'Writing notes', progress: 0.0, error: null);
    try {
      final result = await RepoSummarizer.run(
        data.source.name,
        files,
        generate: _notesGenerator ?? (system, prompt) => _gemini.generateStructured(apiKey: apiKey, systemPrompt: system, prompt: prompt),
        onProgress: (done, total) {
          if (mounted) state = state.copyWith(progress: done / total, busyLabel: 'Writing notes ($done of $total)');
        },
      );
      if (result.notes.isEmpty) {
        throw Exception('Gemini returned no usable notes${result.failedBatches > 0 ? ' (${result.failedBatches} requests failed)' : ''}.');
      }
      final updated = RepoSummarizer.apply(_data[id] ?? data, result.notes);
      _data[id] = updated;
      _setSource(id, updated.source);
      if (_persist) await _repository.save(updated);
      await _rebuild();
      if (result.failedBatches > 0) {
        state = state.copyWith(error: '${result.failedBatches} of the requests failed; run it again to finish the rest.');
      }
    } catch (e) {
      state = state.copyWith(error: e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) state = state.copyWith(busyId: null, busyLabel: '', progress: null);
    }
  }

  Future<void> setEnabled(String id, bool enabled) async {
    final d = _data[id];
    if (d == null) return;
    final updated = d.copyWith(source: d.source.copyWith(enabled: enabled));
    _data[id] = updated;
    _setSource(id, updated.source);
    if (_persist) await _repository.save(updated);
    await _rebuild();
  }

  Future<void> remove(String id) async {
    _data.remove(id);
    state = state.copyWith(repos: [for (final r in state.repos) if (r.id != id) r]);
    if (_persist) await _repository.delete(id);
    await _rebuild();
  }

  void clearError() => state = state.copyWith(error: null);

  bool get hasEnabledRepos => state.enabledCount > 0;

  /// What the switched-on repositories know about [query]. Synchronous and fast.
  RepoContext contextFor(String query, {int maxChars = 2000}) {
    final r = _retrieval;
    if (r == null || query.trim().isEmpty) return RepoContext.none;
    return r.retrieve(query, maxChars: maxChars, repoIds: _enabledIds());
  }

  Set<String> _enabledIds() => {
        for (final d in _data.values)
          if (d.source.enabled && d.source.status == RepoStatus.ready) d.source.id,
      };

  void _setSource(String id, RepoSource source) {
    if (!mounted) return;
    final d = _data[id];
    if (d != null) _data[id] = d.copyWith(source: source);
    state = state.copyWith(repos: [for (final r in state.repos) r.id == id ? source : r]);
  }

  /// Rebuilds the search index over the enabled repositories, yielding to the UI
  /// as it goes. A newer rebuild supersedes an older one still in progress.
  Future<void> _rebuild() async {
    final token = ++_rebuildToken;
    final enabled = [
      for (final d in _data.values)
        if (d.source.enabled && d.source.status == RepoStatus.ready) d,
    ];
    final chunks = [for (final d in enabled) ...d.chunks];
    final index = chunks.isEmpty ? Bm25Index.empty : await Bm25Index.buildAsync(chunks);
    if (token != _rebuildToken) return;
    _retrieval = RepoRetrieval(
      index: index,
      repoNames: {for (final d in _data.values) d.source.id: d.source.name},
      scenarios: [
        for (final d in enabled)
          for (final s in d.scenarios) (d.source.id, s),
      ],
    );
  }
}

final repoNotifierProvider = StateNotifierProvider<RepoNotifier, RepoState>((ref) => RepoNotifier(ref));
