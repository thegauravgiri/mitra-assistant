# Task Checklist: Graph retrieval, graph viewer, Zen/Workspace UI

Legend: `[ ]` todo · `[/]` in progress · `[x]` done. Plan: [implementation_plan.md](implementation_plan.md). Earlier cycles: [archive/](archive/).

## Part A — Graph retrieval
- [x] `DocGraph` model + indexes; `UploadedDocument.graph/graphStatus`
- [x] `GraphExtractorService` (batching, defensive parse, merge, hallucination filter) + `GeminiService.generateGraphJson`
- [x] Background build in `DocumentNotifier` (+ `retryGraph`)
- [x] Graph-aware scoring in `DocumentRelevanceService`
- [x] Tests (`graph_retrieval_test.dart`)

## Part B — Zen / Workspace
- [x] `MeetingNotifier` (lifecycle moved out of `ControlBar`)
- [x] `ShellNotifier` (zen / zenCompact / workspace) + `WindowControlService.applyShellMode`
- [x] `StartStopButton`, slimmer `ControlBar` (+ Open Workspace), Zen tabs reduced
- [x] `WorkspaceShell` (nav rail: Meeting, History, Coaching, Documents, Graph, Settings)
- [x] `CoachingReportPanel` / `ProgressPanel` reusable; Documents page

## Part C — Graph viewer
- [x] `GraphLayout` (force-directed, isolate) + tests
- [x] `GraphView` (pan/zoom, node details)

## Needs a real run (not verifiable headless)
- [ ] Zen <-> Workspace switch mid-meeting on macOS and Windows (timer/transcript continue, no flicker)
- [ ] Screen-share check: window invisible in both modes
- [ ] Upload a real PDF: graph builds, viewer usable, related-term retrieval observed
