import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../documents/domain/models/doc_graph.dart';
import '../../history/providers/history_providers.dart';
import '../../documents/providers/document_providers.dart';
import '../data/combined_graph_builder.dart';
import '../data/meeting_graph_builder.dart';

/// The cross-meeting graph, rebuilt whenever saved meetings change.
final meetingGraphProvider = Provider<DocGraph>((ref) {
  final sessions = ref.watch(historyNotifierProvider.select((s) => s.sessions));
  return MeetingGraphBuilder.build(sessions);
});

/// Meetings and documents in one graph (for the Graph page's "All" view).
final combinedGraphProvider = Provider<DocGraph>((ref) {
  final sessions = ref.watch(historyNotifierProvider.select((s) => s.sessions));
  final docs = ref.watch(documentNotifierProvider.select((s) => s.documents));
  return CombinedGraphBuilder.build(sessions, docs);
});
