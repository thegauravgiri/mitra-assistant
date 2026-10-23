import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../coaching/presentation/backfill_bar.dart';
import '../../history/providers/history_providers.dart';
import '../../meeting_graph/data/graph_filter.dart';
import '../../meeting_graph/providers/meeting_graph_providers.dart';
import 'graph_3d_view.dart';
import '../../../core/theme/graph_palette.dart';
import '../domain/models/doc_graph.dart';
import '../domain/models/uploaded_document.dart';
import '../providers/document_providers.dart';

/// Pick a document and explore the entity graph used for retrieval.
class _DocumentGraphView extends ConsumerStatefulWidget {
  const _DocumentGraphView();

  @override
  ConsumerState<_DocumentGraphView> createState() => _DocumentGraphViewState();
}

class _DocumentGraphViewState extends ConsumerState<_DocumentGraphView> {
  String? _docId;

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(documentNotifierProvider).documents
        .where((d) => d.status == DocStatus.ready)
        .toList();

    if (docs.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.hub_outlined,
        title: 'No documents yet',
        description: 'Upload a document in the Documents page. Its knowledge graph appears here once it has been built.',
      );
    }

    final doc = docs.firstWhere((d) => d.id == _docId, orElse: () => docs.first);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const Icon(Icons.hub_rounded, size: 16, color: AppTheme.primaryAccent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: DropdownButton<String>(
                  value: doc.id,
                  isExpanded: true,
                  dropdownColor: AppTheme.backgroundPureDark,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                  items: [for (final d in docs) DropdownMenuItem(value: d.id, child: Text(d.fileName))],
                  onChanged: (v) => setState(() => _docId = v),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              if (doc.graph != null)
                Text(
                  '${doc.graph!.nodes.length} entities · ${doc.graph!.edges.length} relations',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
            ],
          ),
        ),
        Expanded(child: _body(doc)),
      ],
    );
  }

  Widget _body(UploadedDocument doc) {
    switch (doc.graphStatus) {
      case GraphStatus.building:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 2),
              SizedBox(height: AppSpacing.md),
              Text('Building graph…', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              SizedBox(height: 4),
              Text(
                'Search already works with keywords meanwhile.',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ),
        );
      case GraphStatus.failed:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Could not build a graph for this document.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => ref.read(documentNotifierProvider.notifier).retryGraph(doc.id),
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('Retry'),
              ),
            ],
          ),
        );
      case GraphStatus.none:
        return const EmptyStateWidget(
          icon: Icons.key_off_rounded,
          title: 'No graph yet',
          description: 'Add your Gemini API key in Settings, then upload the document again (or press retry) to build its graph.',
        );
      case GraphStatus.ready:
        return Graph3DCanvas(
          key: ValueKey(doc.id),
          graph: doc.graph!,
          detailsBuilder: (id, onClose) => _NodeDetails(doc: doc, nodeId: id, onClose: onClose),
        );
    }
  }
}

class _NodeDetails extends StatelessWidget {
  final UploadedDocument doc;
  final String nodeId;
  final VoidCallback onClose;

  const _NodeDetails({required this.doc, required this.nodeId, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final graph = doc.graph!;
    final node = graph.node(nodeId);
    if (node == null) return const SizedBox.shrink();

    final relations = [
      for (final e in graph.edges)
        if (e.from == nodeId || e.to == nodeId)
          e.from == nodeId
              ? '${node.name} — ${e.relation} → ${graph.node(e.to)?.name ?? '?'}'
              : '${graph.node(e.from)?.name ?? '?'} — ${e.relation} → ${node.name}',
    ];
    final chunks = node.chunkIndexes.toList()..sort();

    return Container(
      width: 300,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppTheme.cardBackground,
        border: Border(left: BorderSide(color: AppTheme.borderSubtle)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    node.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            Row(children: [ShapeGlyph(node.type, size: 13), const SizedBox(width: 6), Text(NodeStyles.of(node.type).label, style: TextStyle(fontSize: 11, color: NodeStyles.of(node.type).color))]),
            const SizedBox(height: AppSpacing.md),
            const Text('Relations', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
            const SizedBox(height: AppSpacing.xs),
            if (relations.isEmpty)
              const Text('None', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            for (final r in relations)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(r, style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary)),
              ),
            const SizedBox(height: AppSpacing.md),
            const Text('Mentioned in', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
            const SizedBox(height: AppSpacing.xs),
            for (final i in chunks)
              if (i < doc.chunks.length)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundPureDark,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    doc.chunks[i].text,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, height: 1.35),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}


/// Workspace page: explore the knowledge graphs. "Documents" shows the entity
/// graph of each uploaded document (used for retrieval); "Meetings" shows how
/// topics, people, decisions and action items connect across all past meetings.
class GraphView extends StatefulWidget {
  /// Screenshot harness only.
  static bool debugStartOnDocuments = false;

  const GraphView({super.key});

  @override
  State<GraphView> createState() => _GraphViewState();
}

enum _GraphMode { all, meetings, documents }

class _GraphViewState extends State<GraphView> {
  _GraphMode _mode = GraphView.debugStartOnDocuments ? _GraphMode.documents : _GraphMode.all;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
          child: Row(
            children: [
              SegmentedButton<_GraphMode>(
                segments: const [
                  ButtonSegment(value: _GraphMode.all, label: Text('All'), icon: Icon(Icons.hub_rounded, size: 15)),
                  ButtonSegment(value: _GraphMode.meetings, label: Text('Meetings'), icon: Icon(Icons.forum_rounded, size: 15)),
                  ButtonSegment(value: _GraphMode.documents, label: Text('Documents'), icon: Icon(Icons.description_rounded, size: 15)),
                ],
                selected: {_mode},
                onSelectionChanged: (v) => setState(() => _mode = v.first),
                showSelectedIcon: false,
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (_mode) {
            _GraphMode.all => const _CombinedGraphView(key: ValueKey('all'), includeDocuments: true),
            _GraphMode.meetings => const _CombinedGraphView(key: ValueKey('meetings'), includeDocuments: false),
            _GraphMode.documents => const _DocumentGraphView(),
          },
        ),
      ],
    );
  }
}

const _meetingTypes = {
  'meeting': 'Meetings',
  'person': 'People',
  'topic': 'Topics',
  'decision': 'Decisions',
  'action': 'Actions',
  'question': 'Open questions',
};

const _documentGroups = {
  'document': 'Documents',
  'entity': 'Document entities',
};

/// Filter group of a node: its own type for meeting nodes, otherwise one of
/// the two document groups.
String _groupOf(GraphNode n) {
  if (_meetingTypes.containsKey(n.type)) return n.type;
  return n.type == 'document' ? 'document' : 'entity';
}

class _CombinedGraphView extends ConsumerStatefulWidget {
  final bool includeDocuments;

  const _CombinedGraphView({super.key, required this.includeDocuments});

  @override
  ConsumerState<_CombinedGraphView> createState() => _CombinedGraphViewState();
}

class _CombinedGraphViewState extends ConsumerState<_CombinedGraphView> {
  late final Set<String> _types = {
    ..._meetingTypes.keys,
    if (widget.includeDocuments) ..._documentGroups.keys,
  };
  bool _showAll = false;
  static const int _limit = 150;

  @override
  Widget build(BuildContext context) {
    final full = widget.includeDocuments ? ref.watch(combinedGraphProvider) : ref.watch(meetingGraphProvider);
    final sessions = ref.watch(historyNotifierProvider).sessions;
    final documents = ref.watch(documentNotifierProvider).documents;

    if (full.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.forum_outlined,
        title: widget.includeDocuments ? 'Nothing to show yet' : 'No meetings yet',
        description: widget.includeDocuments
            ? 'Finish a meeting or upload a document and it joins the graph. Topics, people and entities that match are linked together.'
            : 'Finish a meeting and it joins the graph. Topics, people, decisions and action items link your meetings together.',
      );
    }

    final filtered = GraphFilter.apply(full, types: _types, limit: _showAll ? null : _limit, groupOf: _groupOf);
    final hidden = GraphFilter.apply(full, types: _types, groupOf: _groupOf).nodes.length - filtered.nodes.length;
    final withoutNotes = sessions.where((s) => s.digest == null && s.entries.isNotEmpty).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final e in {
                    ..._meetingTypes,
                    if (widget.includeDocuments) ..._documentGroups,
                  }.entries)
                    FilterChip(
                      label: Text(e.value, style: const TextStyle(fontSize: 11)),
                      avatar: ShapeGlyph(e.key == 'entity' ? 'concept' : e.key),
                      selected: _types.contains(e.key),
                      onSelected: (v) => setState(() => v ? _types.add(e.key) : _types.remove(e.key)),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (hidden > 0 || _showAll)
                    TextButton(
                      onPressed: () => setState(() => _showAll = !_showAll),
                      child: Text(_showAll ? 'Show top $_limit' : 'Show $hidden more'),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${filtered.nodes.length} nodes · ${filtered.edges.length} links',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              if (withoutNotes > 0) ...[
                const SizedBox(height: AppSpacing.xs),
                const BackfillBar(),
              ],
            ],
          ),
        ),
        Expanded(
          child: Graph3DCanvas(
            key: ValueKey('${_types.toList()..sort()}/$_showAll/${filtered.nodes.length}/${filtered.edges.length}'),
            graph: filtered,
            detailsBuilder: (id, onClose) => _MeetingNodeDetails(
              graph: full,
              documents: documents,
              nodeId: id,
              onClose: onClose,
            ),
          ),
        ),
      ],
    );
  }
}

class _MeetingNodeDetails extends StatelessWidget {
  final DocGraph graph;
  final List<UploadedDocument> documents;
  final String nodeId;
  final VoidCallback onClose;

  const _MeetingNodeDetails({
    required this.graph,
    this.documents = const [],
    required this.nodeId,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final node = graph.node(nodeId);
    if (node == null) return const SizedBox.shrink();

    final fmt = DateFormat('d MMM yyyy');
    final meetings = [
      for (final id in node.sourceIds)
        if (graph.node('m:$id') != null) graph.node('m:$id')!,
    ]..sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));

    final relations = [
      for (final e in graph.edges)
        if (e.from == nodeId || e.to == nodeId)
          '${graph.node(e.from)?.name ?? '?'} — ${e.relation} → ${graph.node(e.to)?.name ?? '?'}',
    ];

    // document-side nodes: which file they come from and where in it
    final sourceDocs = [
      for (final d in documents)
        if (node.sourceIds.contains(d.id) && !node.id.startsWith('m:')) d,
    ];
    final excerpts = [
      for (final d in sourceDocs)
        for (final i in (node.chunkIndexes.toList()..sort()))
          if (i < d.chunks.length) d.chunks[i].text,
    ];

    return Container(
      width: 300,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppTheme.cardBackground,
        border: Border(left: BorderSide(color: AppTheme.borderSubtle)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    node.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            Row(children: [ShapeGlyph(node.type, size: 13), const SizedBox(width: 6), Text(NodeStyles.of(node.type).label, style: TextStyle(fontSize: 11, color: NodeStyles.of(node.type).color))]),
            if (node.detail != null && node.detail!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(node.detail!, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.4)),
            ],
            const SizedBox(height: AppSpacing.md),
            if (sourceDocs.isNotEmpty) ...[
              const Text('In document', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
              const SizedBox(height: AppSpacing.xs),
              for (final d in sourceDocs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(d.fileName, style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary)),
                ),
              for (final t in excerpts)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(color: AppTheme.backgroundPureDark, borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: Text(t, maxLines: 6, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, height: 1.35)),
                ),
              const SizedBox(height: AppSpacing.md),
            ] else if (node.type != 'meeting') ...[
              const Text('Meetings', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
              const SizedBox(height: AppSpacing.xs),
              for (final m in meetings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${m.date == null ? '' : '${fmt.format(m.date!)} · '}${m.name}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      ),
                      // what that meeting said about this topic
                      for (final e in graph.edges)
                        if (e.from == m.id && e.to == nodeId && e.relation == 'discussed' && e.detail != null)
                          Text(e.detail!, style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary, height: 1.4)),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
            ] else if (node.date != null)
              Text(fmt.format(node.date!), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            const Text('Links', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
            const SizedBox(height: AppSpacing.xs),
            if (relations.isEmpty) const Text('None', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            for (final r in relations)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(r, style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary)),
              ),
          ],
        ),
      ),
    );
  }
}
