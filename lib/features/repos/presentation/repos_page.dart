import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../settings/providers/settings_providers.dart';
import '../domain/models/repo_models.dart';
import '../providers/repo_providers.dart';

/// Workspace page: connect repositories so that when a client asks how the
/// product behaves, the answer can come from your own code and tests.
class ReposPage extends ConsumerWidget {
  const ReposPage({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final path = await FilePicker.getDirectoryPath(dialogTitle: 'Choose a repository folder');
    if (path == null) return;
    await ref.read(repoNotifierProvider.notifier).addRepo(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(repoNotifierProvider);

    return ListView(
      primary: false,
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Repositories',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
            ),
            FilledButton.icon(
              onPressed: state.busyId != null ? null : () => _add(context, ref),
              icon: const Icon(Icons.create_new_folder_rounded, size: 17),
              label: const Text('Add repository'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'When a client asks "what happens if…", the answer can come from your own code and tests. '
          'Searching happens on this computer and takes milliseconds; only the few matching excerpts are sent to Gemini during a call.',
          style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.5),
        ),
        const SizedBox(height: AppSpacing.md),
        _InfoCard(),
        if (state.error != null) ...[
          const SizedBox(height: AppSpacing.md),
          _ErrorBanner(message: state.error!, onClose: () => ref.read(repoNotifierProvider.notifier).clearError()),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (state.repos.isEmpty)
          const SizedBox(
            height: 260,
            child: EmptyStateWidget(
              icon: Icons.source_outlined,
              title: 'No repositories yet',
              description: 'Add a folder that holds a project you demo. Connect as many as you need and switch each on or off per meeting.',
            ),
          )
        else ...[
          for (final r in state.repos) _RepoCard(repo: r),
          const SizedBox(height: AppSpacing.lg),
          const _TrySearch(),
        ],
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: AppTheme.primaryAccent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '$title  ', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    TextSpan(text: body, style: const TextStyle(color: AppTheme.textSecondary)),
                  ]),
                  style: const TextStyle(fontSize: 12, height: 1.45),
                ),
              ),
            ],
          ),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        children: [
          row(Icons.search_rounded, 'Search is local.', 'Files are read and indexed on this computer. Secrets (.env, keys, certificates), dependencies and build output are skipped.'),
          row(Icons.menu_book_rounded, 'Plain-English notes (optional).', 'One pass through Gemini explains each important file in plain words and writes ready answers to likely client questions. It sends those files to Gemini once; skip it to keep everything local.'),
          row(Icons.bolt_rounded, 'Fast in the meeting.', 'A prepared answer shows instantly; the AI then adds a polished one with sources like [repo/path:lines].'),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onClose;

  const _ErrorBanner({required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppTheme.panicAccent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppTheme.panicAccent.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, size: 16, color: AppTheme.panicAccent),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary))),
            IconButton(icon: const Icon(Icons.close_rounded, size: 16), onPressed: onClose, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          ],
        ),
      );
}

class _Pill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? color;

  const _Pill(this.text, {this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: c), const SizedBox(width: 4)],
          Text(text, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _RepoCard extends ConsumerWidget {
  final RepoSource repo;

  const _RepoCard({required this.repo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(repoNotifierProvider);
    final notifier = ref.read(repoNotifierProvider.notifier);
    final hasKey = ref.watch(settingsNotifierProvider.select((s) => s.geminiApiKey.trim().isNotEmpty));
    final busy = state.busyId == repo.id;
    final anyBusy = state.busyId != null;
    final ready = repo.status == RepoStatus.ready;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_rounded, size: 22, color: AppTheme.primaryAccent),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(repo.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    Text(repo.path, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                children: [
                  Switch(value: repo.enabled, onChanged: ready ? (v) => notifier.setEnabled(repo.id, v) : null),
                  const Text('Use in meetings', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (ready) _Pill('Ready', icon: Icons.check_circle_rounded, color: const Color(0xFF0CA30C)),
              if (repo.status == RepoStatus.indexing) const _Pill('Reading…', icon: Icons.hourglass_top_rounded, color: AppTheme.warningAccent),
              if (repo.status == RepoStatus.error) const _Pill('Needs attention', icon: Icons.error_rounded, color: AppTheme.panicAccent),
              if (ready) _Pill('${repo.fileCount} files · ${repo.chunkCount} sections'),
              if (ready)
                _Pill(
                  repo.summarisedFiles == 0 ? 'No plain-English notes yet' : 'Notes for ${repo.summarisedFiles} files',
                  icon: Icons.menu_book_rounded,
                  color: repo.summarisedFiles == 0 ? AppTheme.textMuted : AppTheme.primaryAccent,
                ),
              if (repo.indexedAt != null) _Pill('Updated ${DateFormat('d MMM, HH:mm').format(repo.indexedAt!)}'),
            ],
          ),
          if (repo.error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(repo.error!, style: const TextStyle(fontSize: 11.5, color: AppTheme.panicAccent)),
          ],
          if (busy) ...[
            const SizedBox(height: AppSpacing.md),
            LinearProgressIndicator(value: state.progress, minHeight: 4),
            const SizedBox(height: 4),
            Text(state.busyLabel, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: anyBusy ? null : () => notifier.refresh(repo.id),
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: const Text('Refresh'),
              ),
              Tooltip(
                message: hasKey ? 'Explain the important files in plain English (sends them to Gemini once)' : 'Add your Gemini API key in Settings first',
                child: FilledButton.tonalIcon(
                  onPressed: anyBusy || !ready || !hasKey ? null : () => notifier.buildNotes(repo.id),
                  icon: const Icon(Icons.menu_book_rounded, size: 15),
                  label: Text(repo.summarisedFiles == 0 ? 'Build plain-English notes' : 'Add notes for new files'),
                ),
              ),
              TextButton.icon(
                onPressed: anyBusy
                    ? null
                    : () async {
                        final ok = await confirmDelete(
                          context,
                          title: 'Remove "${repo.name}"?',
                          message: 'This removes the repository and its notes from the app. Your files on disk are not touched.',
                          confirmLabel: 'Remove',
                        );
                        if (ok) await notifier.remove(repo.id);
                      },
                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.panicAccent),
                label: const Text('Remove', style: TextStyle(color: AppTheme.panicAccent)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Type a question to see what the app would pull from the connected repos,
/// and how long it took. A rehearsal tool for the demo.
class _TrySearch extends ConsumerStatefulWidget {
  const _TrySearch();

  @override
  ConsumerState<_TrySearch> createState() => _TrySearchState();
}

class _TrySearchState extends ConsumerState<_TrySearch> {
  final TextEditingController _q = TextEditingController();
  String _result = '';
  List<String> _sources = const [];
  String? _scenario;
  String? _notes;
  int? _micros;
  bool _searched = false;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _run() {
    final sw = Stopwatch()..start();
    final ctx = ref.read(repoNotifierProvider.notifier).contextFor(_q.text);
    sw.stop();
    setState(() {
      _searched = true;
      _micros = sw.elapsedMicroseconds;
      _result = ctx.text;
      _sources = [for (final s in ctx.sources) s.toString()];
      _scenario = ctx.scenario == null ? null : '${ctx.scenario!.answer}  (${ctx.scenarioRepo ?? 'repo'})';
      _notes = ctx.leadNotes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(repoNotifierProvider.select((s) => s.enabledCount)) > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.science_rounded, size: 16, color: AppTheme.primaryAccent),
              SizedBox(width: AppSpacing.sm),
              Text('Try a question', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _q,
            enabled: enabled,
            onSubmitted: (_) => _run(),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              hintText: enabled ? 'e.g. What happens if a payment fails halfway?' : 'Switch on at least one repository above',
              suffixIcon: IconButton(icon: const Icon(Icons.search_rounded, size: 18), onPressed: enabled ? _run : null),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
          if (_searched) ...[
            const SizedBox(height: AppSpacing.md),
            if (_micros != null)
              Text(
                _result.isEmpty && _scenario == null
                    ? 'Nothing relevant found (${(_micros! / 1000).toStringAsFixed(1)} ms).'
                    : 'Found in ${(_micros! / 1000).toStringAsFixed(1)} ms',
                style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
              ),
            if (_scenario != null) ...[
              const SizedBox(height: AppSpacing.sm),
              const Text('Ready answer', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
              Text(_scenario!, style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary, height: 1.45)),
            ] else if (_notes != null) ...[
              const SizedBox(height: AppSpacing.sm),
              const Text('In plain English', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
              Text(_notes!, style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary, height: 1.45)),
            ],
            if (_sources.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final s in _sources) _Pill(s, icon: Icons.code_rounded)]),
            ],
            if (_result.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 220),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(color: AppTheme.backgroundPureDark, borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: SingleChildScrollView(
                  primary: false,
                  child: SelectableText(_result, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.textSecondary, height: 1.4)),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
