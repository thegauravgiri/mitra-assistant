# Plan: Graph-based document retrieval, graph viewer, and Zen / Workspace UI

## Context

Three requests, one release:
1. **Graph-based retrieval for uploaded documents** (instead of keyword-only scoring), fast at meeting time, no new dependency.
2. **A graph viewer** inside the app to see a document's graph.
3. **Two UIs**: a *Zen* window for the live meeting (default, opens ready to start a meeting) and a wider, taller *Workspace* with navigation (History, Settings, Graph, Coaching, Documents...). Both must stay hidden from screen sharing/recording.

Current state (verified):
- One frameless always-on-top window (`window_manager`), `main.dart` -> `OverlayShell` toggling `CompactModeView` (380x56 pill) / `ExpandedModeView` (420x680, tabs: AI Copilot, Transcript, History, Settings).
- Stealth is per native window: macOS `NSWindow.sharingType = .none` (`WindowControlService.swift`), Windows `SetWindowDisplayAffinity(WDA_EXCLUDEFROMCAPTURE)` (`window_control_channel.cpp`), enabled once in `WindowControlService.initializeWindow()`.
- Meeting start/stop logic and the elapsed timer live in `ControlBar`'s widget state (`control_bar.dart`), so they would be lost if that widget is rebuilt.
- Documents are in-memory only (`DocumentNotifier`), parsed into 500-char chunks with keywords, summarised once with Gemini on upload (`_processParsedDocuments`), retrieved via Jaccard scoring in `DocumentRelevanceService.getRelevantContext`.

## Key decisions

- **One window that resizes, not a second window.** A second Flutter window runs a separate engine, so Riverpod state (live meeting, history, documents) would not be shared, and stealth would have to be wired for a second native window on both platforms. Resizing the single existing window keeps all state and keeps the existing stealth (same `NSWindow`/`HWND`).
- **Graph RAG in plain Dart**, no package (Windows support unverified for the candidates; one-hop expansion is trivial). Gemini extracts entities/relations once per upload in the background; retrieval is in-memory map lookups.
- **Own graph viewer** (`CustomPainter` + `InteractiveViewer` + a small force-directed layout), not a package.

## Part A: Graph retrieval

**Models** (`lib/features/documents/domain/models/doc_graph.dart`): `GraphNode{id, name, type, chunkIndexes}`, `GraphEdge{from, to, relation, chunkIndex}`, `DocGraph{nodes, edges}` with precomputed `Map<String token, Set<nodeId>>` and adjacency `Map<nodeId, Set<edgeIdx>>`. `UploadedDocument` gets nullable `graph` and `graphStatus` (`none|building|ready|failed`), `copyWith` updated.

**Extraction** (`documents/data/graph_extractor_service.dart`, pure parse + Gemini call):
- Batch 6 chunks per Gemini call, JSON `{"chunks":[{"index":n,"entities":[{"name","type"}],"relations":[{"from","to","relation"}]}]}`.
- Prompt requires both relation endpoints to appear in the chunk text.
- Defensive parsing like `GeminiService._parseInsightsJson` (strip fences, regex fallback).
- Normalise names with `TextSimilarity.normalize`; merge duplicates by normalised name, then Jaccard >= 0.8 (`lib/core/utils/text_similarity.dart`).
- Caps: first 60 chunks, 80 nodes per document. Own model instance in `GeminiService` (like `generateSpeakerReviews`), method `extractGraph(...)`.

**Background build** (`document_providers.dart`): after a document becomes `ready` (keyword search usable immediately), start graph build asynchronously; set `graphStatus` building -> ready/failed. A failure never affects the document.

**Retrieval** (`document_relevance_service.dart`): when a doc has a ready graph, per chunk score = existing Jaccard keyword score + `0.5 * seedNodeHits` + `0.25 * neighbourNodeHits` (seeds = nodes whose name tokens appear in the transcript window; neighbours = one hop via edges). Same 1,500-char budget, pinned handling and `activeSignature` as today; no graph -> unchanged behaviour. Weights live in `AppConstants`.

**Tests**: graph retrieval finds a chunk reachable only through an edge (transcript says "forecast", chunk says "budget") where keyword-only misses it; empty graph; budget cap; extractor parser with fenced/malformed JSON; name merging.

## Part B: Zen / Workspace UI

**Mode state** (`lib/features/overlay/providers/shell_providers.dart`): `ShellMode {zen, zenCompact, workspace}` in a `StateNotifier`. Only this notifier resizes the window.

**Window service** (extend `window_control_service.dart`): `enterWorkspace()` saves current bounds, sets minimum size (900x600), size ~1100x760, centres, `setAlwaysOnTop(false)`; `enterZen()` restores saved bounds, size 420x680, minimum 320x200, `setAlwaysOnTop(true)`. Screen protection is not touched (already on for the window); `enableScreenProtection()` is re-asserted after each resize as a safety net.

**Lift meeting lifecycle out of `ControlBar`**: new `MeetingNotifier` (`lib/features/meeting/providers/meeting_providers.dart`, new feature folder per CLAUDE.md layering) owns `startTime`, elapsed timer, `start()` and `stop()` (the existing start/stop + save + coaching-review logic moved from `control_bar.dart`). `ControlBar` becomes a thin view. This is required so switching modes mid-meeting does not lose the timer or session.

**Zen window** (default; reuses `ExpandedModeView`/`CompactModeView`): tabs reduced to AI Copilot and Transcript; start/stop meeting stays the primary control; new "Open workspace" button in `ControlBar`. Opens ready to start a meeting (current default).

**Workspace** (`lib/features/overlay/presentation/workspace_shell.dart`): frameless, custom top bar (drag area, "Back to Zen", minimise/close via `window_manager`), left navigation rail, pages in an `IndexedStack`:
- **Meeting**: live status + start/stop + live insights (reuses `InsightView`, `TranscriptView`).
- **History**: existing `HistoryView`.
- **Coaching**: sessions list + inline report (refactor `CoachingReportDialog` content into a reusable `CoachingReportPanel`) + progress (`ProgressDialog` body as a panel).
- **Documents**: upload/pin/remove (reuse `document_chips_bar.dart` logic), graph status per doc.
- **Graph**: viewer (Part C).
- **Settings**: existing `SettingsView`.

`OverlayShell` switches between zen views and `WorkspaceShell` based on `ShellMode`, keeping the existing fade/scale transition.

**Hotkeys**: panic hide and toggle keep working in both modes (they act on the single window).

## Part C: Graph viewer

`lib/features/documents/presentation/graph_view.dart`: document selector -> `GraphCanvas` (`CustomPainter`) inside `InteractiveViewer` (pan/zoom). Layout: simple force-directed (repulsion + spring + centring), ~150 iterations computed once in `compute()` (isolate) and cached on the `DocGraph`, so the UI never blocks. Node colour by type, edge labels shown on hover/selection, tap a node to show its connected chunks in a side panel. States: building (progress), failed (retry button), no Gemini key.

## Sequence

1. Part A model, extractor, tests -> 2. retrieval + tests -> 3. `MeetingNotifier` refactor (no UI change; verify) -> 4. shell mode + window service + workspace shell with existing pages -> 5. Coaching/Documents panels -> 6. graph viewer -> 7. docs (`.docs/implementation_plan.md`, `task.md`, `walkthrough.md`, CLAUDE.md feature list).

## Risks / notes

- Native file picker (`NSOpenPanel`/Windows dialog) is a separate OS window and is not covered by the stealth flag. This already applies today; I will note it rather than change it.
- Resizing a frameless transparent window can flicker; mitigated by setting size before switching the widget tree. Needs a real run on macOS and Windows.
- Graph quality depends on Gemini; the keyword fallback always remains.
- Extra Gemini calls on upload (about one per 6 chunks, 10 calls for a 60-chunk document).

## Verification

1. `flutter analyze` clean, `flutter test` all green (new tests above).
2. `flutter run -d macos`: start a meeting in Zen, click "Open workspace" mid-meeting; timer and transcript continue; click "Back to Zen" restores position/size.
3. While in each mode, share the screen (Zoom/Meet/QuickTime) and confirm the window is invisible.
4. Upload a PDF; document usable immediately, graph status goes building -> ready; open Graph page, pan/zoom, tap a node.
5. During a meeting, say a related term ("forecast") and confirm the document chunk about "budget" is included in Gemini's context (debug log of the assembled context).
6. Repeat 2-3 on Windows.
