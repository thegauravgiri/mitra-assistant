# Walkthrough: Graph retrieval, graph viewer, Zen/Workspace UI

## What changed
- **Graph retrieval:** after upload a document is usable immediately (keywords); a background Gemini pass extracts entities/relations into a `DocGraph`. At meeting time, transcript words are matched to nodes (seeds), one hop is expanded, and chunks mentioning seed (+0.5) or neighbour (+0.25) nodes are boosted. A graph can also admit a document the keyword gate would reject. No graph → behaviour unchanged. Weights in `AppConstants`.
- **Zen / Workspace:** one native window, resized by `ShellNotifier` via `WindowControlService.applyShellMode` (so screen-capture protection is the same window's and is re-asserted after resize). Zen = live meeting only (AI Copilot, Transcript). Workspace = nav rail with Meeting, History, Coaching, Documents, Graph, Settings. Meeting start/stop/timer moved to `MeetingNotifier` so switching modes mid-meeting loses nothing.
- **Graph viewer:** Fruchterman-Reingold layout computed in an isolate, painted with `CustomPainter` inside `InteractiveViewer`; tap a node for relations and source chunks.

## Verified
- `flutter analyze` clean; `flutter test` 48 passed; `flutter build macos --debug` OK; app launches without startup exceptions.

## Not verified (needs interactive run)
- Mode switching behaviour/flicker, screen-share invisibility in Workspace, real-document graph quality, Windows.
- Native file picker dialog is a separate OS window and is not covered by capture protection (pre-existing).
