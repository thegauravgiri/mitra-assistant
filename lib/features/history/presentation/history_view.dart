import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/models/meeting_session.dart';
import '../providers/history_providers.dart';

class HistoryView extends ConsumerWidget {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyNotifierProvider);

    return Column(
      children: [
        // Header Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: AppTheme.cardBackground.withValues(alpha: 0.3),
          child: Row(
            children: [
              const Icon(
                Icons.history_rounded,
                size: 14,
                color: AppTheme.primaryAccent,
              ),
              const SizedBox(width: 6),
              const Text(
                'Meeting History',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              if (state.sessions.isNotEmpty)
                IconButton(
                  icon: const Icon(
                    Icons.delete_sweep_rounded,
                    size: 16,
                    color: AppTheme.textMuted,
                  ),
                  tooltip: 'Clear All History',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    _showClearAllDialog(context, ref);
                  },
                ),
            ],
          ),
        ),

        // Main Content Area
        Expanded(
          child: state.isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryAccent,
                    strokeWidth: 2,
                  ),
                )
              : state.sessions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.history_toggle_off_rounded,
                              color: AppTheme.textMuted,
                              size: 40,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No Meeting History',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'When you complete a meeting, its transcript, AI summary, and date/time will be automatically saved here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: state.sessions.length,
                      itemBuilder: (context, index) {
                        final session = state.sessions[index];
                        return _SessionCard(session: session);
                      },
                    ),
        ),
      ],
    );
  }

  void _showClearAllDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text(
          'Clear History',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        ),
        content: const Text(
          'Are you sure you want to clear all meeting history? This action cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.panicAccent,
            ),
            onPressed: () {
              ref.read(historyNotifierProvider.notifier).clearHistory();
              Navigator.of(ctx).pop();
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends ConsumerStatefulWidget {
  final MeetingSession session;

  const _SessionCard({required this.session});

  @override
  ConsumerState<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends ConsumerState<_SessionCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final dateFormat = DateFormat('MMM d, yyyy · h:mm a');
    final dateStr = dateFormat.format(session.startTime);

    final duration = session.endTime.difference(session.startTime);
    final durationStr = duration.inMinutes > 0
        ? '${duration.inMinutes} min'
        : '${duration.inSeconds} sec';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Icon + Title + Delete
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.event_note_rounded,
                  size: 18,
                  color: AppTheme.primaryAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.borderSubtle,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              durationStr,
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: AppTheme.textMuted,
                  ),
                  tooltip: 'Delete Session',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    _showDeleteConfirmationDialog(context, ref, session);
                  },
                ),
              ],
            ),

            const SizedBox(height: 10),

            // AI Summary Box
            if (session.aiSummary.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 12,
                          color: AppTheme.primaryAccent,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'AI Summary',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.aiSummary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Action Buttons Row: Download CSV & Preview Transcript Toggle
            Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 14),
                  label: const Text(
                    'Download CSV',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () async {
                    final path = await ref
                        .read(historyNotifierProvider.notifier)
                        .exportSessionCsv(session);
                    if (context.mounted) {
                      if (path != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('CSV saved to Documents: $path'),
                            backgroundColor: AppTheme.secondaryAccent,
                            duration: const Duration(seconds: 4),
                            action: SnackBarAction(
                              label: 'Copy Path',
                              textColor: Colors.white,
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: path));
                              },
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to export CSV file.'),
                            backgroundColor: AppTheme.panicAccent,
                          ),
                        );
                      }
                    }
                  },
                ),
                const Spacer(),
                InkWell(
                  onTap: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  child: Row(
                    children: [
                      Text(
                        '${session.entries.length} Entries',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppTheme.textMuted,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Expandable Transcript Preview List
            if (_isExpanded) ...[
              const SizedBox(height: 10),
              const Divider(color: AppTheme.borderSubtle, height: 1),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: session.entries.length,
                  itemBuilder: (context, idx) {
                    final entry = session.entries[idx];
                    final timeStr = DateFormat('HH:mm:ss').format(entry.timestamp);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            timeStr,
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppTheme.textMuted,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.text,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(
    BuildContext context,
    WidgetRef ref,
    MeetingSession session,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text(
          'Delete Meeting Session',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${session.title}"?${session.exportedCsvPath != null ? "\n\nThis will also delete the exported CSV file from disk." : ""}',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.panicAccent,
            ),
            onPressed: () {
              ref.read(historyNotifierProvider.notifier).deleteSession(session.id);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Meeting session and exported files deleted.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
