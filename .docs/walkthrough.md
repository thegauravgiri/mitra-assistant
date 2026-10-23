# Walkthrough: Meeting graph + coaching overhaul

## What changed
- **Meeting digest** (`coaching/data/digest_service.dart`): one Gemini pass per meeting yields summary, topics, decisions, action items (with owner) and unanswered questions; stored on the session. Runs automatically on save. "Build notes for N older meetings" (`BackfillBar`, Coaching page and Graph page) runs it over old history, sequentially, skipping failures.
- **Meeting graph** (`meeting_graph/`): `MeetingGraphBuilder` derives meetings, people, topics, decisions, actions and questions from saved sessions (no separate storage). Same topic/person across meetings merges into one node (`NameCanonicalizer`, shared with the document graph). Items link to the topics they mention. Graph page: Meetings | Documents switch, type filters, top-150 by degree (+ "show all"), node details with meetings and links.
- **Live recall**: `MeetingRecallService` matches transcript words to topic nodes and adds a short "Earlier meetings" block (date, decision, action + owner, left-unanswered) to the live analysis prompt. Nothing is added when no topic matches. The current meeting is excluded.
- **Coaching for "me"**: speaker picker per meeting ("This is me", name remembered in Settings -> Profile). New metrics: pace, fillers (Deepgram `filler_words=true` + phrase matching), longest stretch, average turn, questions, response gap. `IndicatorEvaluator` gives good/ok/watch against documented thresholds with delta vs your last 5 meetings. Goals (up to 3, Settings -> stored) are evaluated every meeting. `CoachingFeedbackService` produces strengths/improvements with a concrete tip each; **quotes are verified against your own lines and dropped if not found**.
- **Report UI**: me picker, scorecard, goals, coaching, outcomes, everyone's numbers, exports (.md/.json now include coaching and notes). Progress panel shows a sparkline per metric over time.
- Removed the old generic per-speaker review generation; reviews already stored on old sessions still display.

## Verified
- `flutter analyze` clean; `flutter test` all green (new: delivery metrics, indicators/goals, digest and coaching parsers incl. hallucinated-quote drop, meeting graph builder, recall, graph filter, report panel widget tests).
- macOS debug build + launch.

## Not verified (needs an interactive run)
- Real Gemini output quality for digest/coaching; Deepgram acceptance of `filler_words=true`; graph viewer on real data; Windows.

## Limits to remember
- The app cannot tell which voice is yours on a mixed stream; you pick per meeting.
- Old meetings have no word timings, so pace/fillers-per-minute/monologue show "n/a" for them; notes, questions and the graph still work.
- Thresholds are rules of thumb. Interruptions are estimates.
- Recall sends short snippets of earlier meetings to Gemini (as the live transcript already is).

## UI refinement round (graph 3D, colours, coaching layout)
- **3D graph** (`documents/presentation/graph_3d_view.dart`): force-directed layout in 3D (`graph_layout_3d.dart`, isolate), orbit camera with perspective (`graph_camera.dart`), drag to rotate, scroll/pinch to zoom, double-click to reset, optional auto-rotate, click a node to focus it. Depth cues: nearer nodes are larger and brighter. Hover/selection dims everything except the node and its neighbours.
- **Edges:** three tiers (structural: attended/from/decided in/unanswered in = faint; semantic = medium; owns/asked/raised = strong). Edges touching the focused node get a source-to-target colour gradient, an arrowhead and a relation label. Labels go through `LabelPlacer` (greedy, collision-free), so names no longer overlap or clip.
- **Colour:** node colours are the first three validated categorical slots (blue, orange, aqua; passes all-pairs colour-blind/normal-vision checks on the graph surface). Beyond three groups, **shape** carries the type (hexagon meeting, circle topic/person, diamond decision, square action, triangle open question) plus a legend. Status colours use the fixed good/warning/serious palette with icon + word. Muted text raised from 3.2:1 to 6:1 contrast; chips/segmented buttons no longer default to green (`AppTheme`).
- **Coaching page:** rebuilt as tabs (meeting list + "My progress"), adaptive one/two-column report, even tile grid with status accent bar, shared `SectionCard`, export moved to a menu. Fixed a desktop bug where vertical scroll views shared one primary controller (report opened scrolled halfway).
- **Screenshot harness:** `tool/preview/` runs the real app with sample data and capture protection off (never ships). Build `flutter build macos --debug -t tool/preview/preview_main.dart`, then run the binary with `PAGE=coaching|graph|graph-docs|documents|history|settings|zen` (and `SELECT=<node id>`).

## Documents persist + combined graph
- **Saved documents:** `DocumentRepository` writes finished documents (text, chunks, summary, pin state, entity graph) to `Documents/MitraAssistant/documents.json` (atomic write, serialised, corrupt file = empty list). `DocumentNotifier` loads on start and saves 600 ms after any change. A graph build interrupted by quitting is restored as "not built" (retry button). Tests/preview use `persist: false`.
- **Combined graph** (`meeting_graph/data/combined_graph_builder.dart`): meeting graph + a pentagon document node per ready document, linked ("mentions") to its 25 best-connected entities, with the document's own relations kept. A document entity links ("same as", dashed white) to a meeting topic/person **only when the names match** (`NameCanonicalizer.find`, no registering). Linked, not merged; document retrieval is unchanged and still uses each document's own graph.
- **Graph page:** All (default) | Meetings | Documents. Filter chips add Documents and Document entities. Document-side nodes show the file name and the source excerpts.
- Limits: matching is by name only, so "Pricing" and "Pricing strategy" will not link; entities are capped at 25 per document; the 150-node view cap still applies.

## History refined; outcomes moved out of Coaching
- **History** is now list + detail. Left: searchable list (title, summary, transcript text) with badges for notes-ready and coached. Right: the opened meeting with **Outcomes** and **Transcript** tabs, Coaching (jumps to that meeting's coaching), Export CSV and Delete. Transcript groups consecutive lines per speaker with colour, names and times, has find-in-transcript, and copy.
- **Outcomes left Coaching.** Coaching keeps a "Your follow-ups" card (action items you own, your unanswered questions) with a "Full notes" link to History; History links back via "Coaching".
- **Safer delete:** deleting one meeting or all meetings opens a dialog with a checkbox; the Delete button is disabled until it is ticked (`core/widgets/confirm_delete_dialog.dart`). Cancel keeps everything.
- The old Zen-sized coaching/progress dialogs were removed (Zen has no History).

## Speaker separation fixes (diarisation)
Two causes found by reading the code; neither could be proven with live audio here.
1. **macOS mixed nothing.** The mic tap and the ScreenCaptureKit stream each pushed their own chunks into the same Deepgram stream, so the two sources were interleaved (audio at roughly double speed) instead of summed. Windows already sums (`MixPcm16`). macOS now uses `PcmMixer` (in `AudioCaptureService.swift`): per-source queues, drained every 100 ms and added sample by sample with clipping, 300 ms backlog cap. Standalone checks: `tool/native_tests/run_pcm_mixer_test.sh` (10 checks).
2. **System audio was forwarded as raw bytes.** ScreenCaptureKit audio is not guaranteed to be Int16 (typically 32-bit float, possibly planar). `AudioStreamOutput` now reads the real format and converts via `PcmConverter` (shared with the mic path) to 16 kHz mono Int16.
3. **One result = one speaker.** `DeepgramMessageParser` labelled a whole Deepgram result with its majority speaker, so a result containing both voices became one line. `parseAll` now emits one entry per run of consecutive same-speaker words (with their own times). A lone word shorter than 0.35 s between two runs of the same speaker is treated as flicker; a real one-word reply is kept. Interim (live) text stays a single entry.
Not verified: real two-person audio; Deepgram diarisation needs several seconds of speech before it separates voices, and quality drops when both voices come through one speaker/mic (use headphones to keep the remote voice out of the mic).

## Speaker separation, second round: separate channels
Mixing both voices into one stream and asking diarisation to tell them apart was unreliable (and in a real test it labelled the user and the caller both "Speaker 1"). The user's mic and the call are different *sources*, so they now stay apart:
- **Native:** macOS (`PcmMixer`) and Windows (`StereoInterleaver`) send ONE stereo stream: left = microphone, right = system audio. Channels stay sample-aligned: while both sources deliver, only the common length is emitted (never padded, so neither is time-stretched); a source quiet for 500 ms becomes zeros; backlog capped at 300 ms. Checks: `tool/native_tests/run_pcm_mixer_test.sh` (macOS, 12) and `tool/native_tests/stereo_interleaver_test.cpp` (Windows class compiled with clang, 7). The whole Windows app build is NOT verified.
- **Deepgram:** `channels=2&multichannel=true` (+ `diarize=true`). Results carry `channel_index`. Channel 0 is always **"You"**; channel 1 is the call, where diarisation (numbering restarts per channel) gives Speaker 2, 3, ...
- **Setting** (Settings -> Speaker separation, on by default): off folds stereo to mono (`PcmDownmix`) = old behaviour and single-channel billing. Deepgram bills each channel, so on costs about 2x.
- **Echo guard** (`TranscriptMerge`): if the call plays through speakers the mic hears it. A "You" line that repeats a call line (>= 3 content words, 75% overlap, within 4 s) is dropped, or replaced if the call line arrives second. Lines are inserted in start-time order because the two channels arrive interleaved.
- **Automatic "me":** meetings recorded with a "You" channel save `meSpeakerKey = 'You'` named after the profile name, so there is no "which speaker are you?" step for new meetings. Older meetings keep the manual picker.
- Analysis prompt now says "You" is the user.
Not verified: real two-person audio on either OS; whether Deepgram diarisation numbers speakers on the call channel as expected; the interleaved-stereo layout is the standard for raw linear16 but was not confirmed against a live stream.

## Stronger notes, insights and summaries
- **Meeting notes are descriptive and complete** (`MeetingDigest` v2): a 5-9 sentence overview; every topic with a summary of what was said about it in that meeting; decisions with rationale and a verbatim quote; action items with owner, due date and quote; open questions with context; risks; key facts (figures, dates, names). Quotes are checked against the transcript and dropped if not found (`DigestService.verifyEvidence`); the item stays.
- **Long meetings are not trimmed.** Over 30,000 characters the transcript is split on line boundaries (22,000 per part, 1,500 overlap), each part is analysed in full detail, and a merge step combines them (same topic across parts = one topic; an earlier question answered later is removed). If the merge call fails the parts are merged in code. A failing part is skipped; all failing throws.
- **Recall uses what was said.** A topic's per-meeting summary lives on the "discussed" link; live recall now includes it ("came up on 12 Oct: Forecast shows a 12% shortfall; ..."), and the Graph topic panel shows each meeting's account. Notes saved before this change still load.
- **Live insights:** new system prompt (clear quality bar: specific, grounded, flags contradictions, no restating, max 3, `[]` when nothing helps), a longer recent window (4,500 chars, cut on a line boundary), and **running notes of the meeting so far**, refreshed in the background every ~2,500 characters that leave the window. That is what lets the AI catch an unanswered question from 40 minutes ago.
- **Ask box** now gets the same context (running notes, earlier meetings, documents, speaker-labelled recent conversation) and must say so when the material does not contain the answer.
- **Document summaries**: 6-10 specific sentences (purpose, sections, figures, terms) instead of 2-3; very long documents are summarised from start and end. Coaching also receives the meeting overview.
- Cost: more Gemini calls (parts + merge for long meetings; a running-notes update about every 2,500 characters). All use gemini-2.5-flash; swapping `GeminiService` to a stronger model for the notes step is a one-line change if quality needs it.
- Not verified: real model output quality on a long meeting.
