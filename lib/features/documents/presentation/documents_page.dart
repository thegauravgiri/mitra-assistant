import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../domain/models/doc_graph.dart';
import '../domain/models/uploaded_document.dart';
import '../providers/document_providers.dart';

/// Workspace page: manage reference documents and see their graph status.
class DocumentsPage extends ConsumerWidget {
  final VoidCallback onOpenGraph;

  const DocumentsPage({super.key, required this.onOpenGraph});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(documentNotifierProvider);
    final notifier = ref.read(documentNotifierProvider.notifier);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const Text(
                'Reference documents',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const Spacer(),
              if (state.documents.isNotEmpty)
                TextButton(onPressed: notifier.clearAll, child: const Text('Remove all')),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.icon(
                onPressed: state.isProcessing ? null : notifier.pickAndAddDocuments,
                icon: const Icon(Icons.upload_file_rounded, size: 16),
                label: Text(state.isProcessing ? 'Processing…' : 'Upload'),
              ),
            ],
          ),
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(state.error!, style: const TextStyle(fontSize: 11, color: AppTheme.panicAccent)),
          ),
        Expanded(
          child: state.documents.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.description_outlined,
                  title: 'No documents',
                  description: 'Upload PDF, DOCX, TXT or MD files. Relevant parts are shared with the AI during a meeting, and a knowledge graph is built from each document.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  itemCount: state.documents.length,
                  itemBuilder: (context, i) => _DocCard(
                    doc: state.documents[i],
                    onOpenGraph: onOpenGraph,
                  ),
                ),
        ),
      ],
    );
  }
}

class _DocCard extends ConsumerWidget {
  final UploadedDocument doc;
  final VoidCallback onOpenGraph;

  const _DocCard({required this.doc, required this.onOpenGraph});

  String get _graphLabel {
    switch (doc.graphStatus) {
      case GraphStatus.none:
        return 'Graph: not built';
      case GraphStatus.building:
        return 'Graph: building…';
      case GraphStatus.ready:
        return 'Graph: ${doc.graph?.nodes.length ?? 0} entities';
      case GraphStatus.failed:
        return 'Graph: failed';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(documentNotifierProvider.notifier);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_rounded, size: 20, color: AppTheme.primaryAccent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.fileName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${doc.status.name} · ${doc.chunks.length} chunks · ${doc.charCount} chars · $_graphLabel',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
                if (doc.summary != null && doc.summary!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    doc.summary!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
                if (doc.error != null)
                  Text(doc.error!, style: const TextStyle(fontSize: 11, color: AppTheme.panicAccent)),
              ],
            ),
          ),
          if (doc.graphStatus == GraphStatus.ready)
            IconButton(
              icon: const Icon(Icons.hub_rounded, size: 18),
              tooltip: 'View graph',
              onPressed: onOpenGraph,
            ),
          if (doc.graphStatus == GraphStatus.failed || doc.graphStatus == GraphStatus.none)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              tooltip: 'Build graph',
              onPressed: doc.status == DocStatus.ready ? () => notifier.retryGraph(doc.id) : null,
            ),
          IconButton(
            icon: Icon(
              doc.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              size: 18,
              color: doc.isPinned ? AppTheme.warningAccent : null,
            ),
            tooltip: doc.isPinned ? 'Unpin (only used when relevant)' : 'Pin (always use as context)',
            onPressed: () => notifier.togglePin(doc.id),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            tooltip: 'Remove',
            onPressed: () => notifier.removeDocument(doc.id),
          ),
        ],
      ),
    );
  }
}
