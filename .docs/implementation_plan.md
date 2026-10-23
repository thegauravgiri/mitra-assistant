# Plan: Cross-meeting conversation graph + a much better coaching experience

## Context

Two requests:
1. The graph must also be built from **old conversations**, viewable in the app, and used for **live recall** during meetings.
2. Coaching should be "completely good": for **you** (the user), covering **delivery, listening & inclusion, meeting outcomes, and growth over time**, delivered **after the meeting only** (no live nudges).

Decisions from the user: coaching is for the user (they mark "This is me"); all four dimensions; post-meeting only; graph = viewer + live recall.

Current state (verified in code):
- Coaching today = talk time/share, turns, words, interruption counts (`coaching/data/participation_analyzer.dart`) + one generic Gemini review per speaker (`reviewSystemPrompt`). No pace, fillers, monologues, questions, outcomes, goals, or personalisation. Progress compares talk share/turns/interruptions only.
- Sessions (`MeetingSession`) already hold entries (speaker, word timings for new meetings), insights, `speakerNames`, `coachingReport`; history lives in `shared_preferences` (max 50 sessions). Old sessions have no timings and speaker "Meeting Participant".
- The document graph types (`DocGraph`, `GraphNode`, `GraphEdge`), layout (`GraphLayout`) and viewer (`graph_view.dart`) exist and are reusable. `GraphExtractorService.merge` holds name-canonicalisation logic worth sharing.
- The literature review already defines the cross-meeting model: entities Speaker, MeetingSession, Review, ActionItem. The meeting graph follows that.
- Deepgram `filler_words=true` is supported on Nova-2 (checked in Deepgram docs); it only adds uh/um/mhmm. Other fillers ("like", "you know") are normal words and are detected by regex.

## Design

### A. One post-meeting "digest" feeds both coaching outcomes and the graph
A single Gemini pass per meeting (`MeetingDigest`, stored on the session) returns: `summary`, `topics[]` (<=8, optional `raisedBy`), `decisions[]`, `actionItems[{owner, task}]`, `openQuestions[{asker, question}]`. This avoids a separate graph-extraction pass, and the graph becomes a pure function of the stored sessions (no second store, no migration, always consistent).
- Runs automatically when a meeting is saved (replaces the current generic review call).
- **Backfill for old conversations:** a "Build from history" action runs the same digest over every session without one (sequential, progress "3 of 12", resumable, skips failures). Old transcripts use their stored text; unnamed speakers stay as "Speaker N"/"Meeting Participant" and are only linked to the meeting.

### B. Coaching for "me"
- **Identity:** new setting `myName` + `MeetingSession.meSpeakerKey`. The report opens with "Which speaker are you?" chips; picking one names that speaker (reusing `speakerNames`, so cross-meeting progress works by name) and triggers the coaching call. Choice remembered by name, not label (labels like "Speaker 1" are not stable across meetings).
- **Metrics** (extend `SpeakerMetrics`, all nullable/back-compatible, computed in `ParticipationAnalyzer` from existing turns/timings):
  - Delivery: pace (words/min of talk time), fillers per minute (+ breakdown; needs `filler_words=true` in the Deepgram URL for uh/um; regexes for "like/you know/basically/I mean/sort of/kind of"), longest monologue, average turn length.
  - Listening & inclusion: talk share vs fair share (1/N), interruptions made/received (existing), questions asked (sentences ending "?"), average response gap before the speaker's turns, share of other speakers who got >= X% airtime.
  - Old sessions without timings show "n/a" for time-based metrics rather than fake numbers.
- **Indicators** (`coaching/data/indicator_evaluator.dart`): each metric gets a status (good / ok / watch) from documented thresholds in `AppConstants` (e.g. pace 120-170 wpm, fillers < 3/min, monologue < 60 s, talk share within fair share +/- 15 pts, interruptions made <= 1). Labelled as heuristics; the UI shows the number, the range, and the delta vs the user's average over their last 5 meetings.
- **Goals / growth:** user picks up to 3 goals from a catalogue (reduce interruptions, keep monologues under N s, ask more questions, fewer fillers, talk share target, steady pace). Stored in settings (JSON). Each meeting evaluates every goal (met / not + trend). Trends come from `ProgressService` (by name).
- **Coaching narrative** (second Gemini call, only after "This is me"): input = my metrics + indicators + trend vs history + goals + labelled transcript. Output JSON: `strengths[2]`, `improvements[<=3]` each `{title, evidence, tip}`, `goalNotes[]`. Prompt rules: supportive tone; evidence must be a short quote (<=15 words) from the transcript; one concrete tip per improvement; hedge heuristic metrics (interruptions); no personal judgments. **Evidence validation in code:** a quote that is not found in the transcript (normalised substring) is dropped, so hallucinated quotes never display (unit-tested).
- **Outcomes:** the digest's decisions, action items (with owner), and unanswered questions are shown in the report; the user's own items are highlighted ("You own 2 actions").
- Old per-speaker `reviews` map stays readable for existing sessions; no new per-speaker reviews for other people.

### C. Meeting graph
- `MeetingGraphBuilder.build(sessions)` (pure): nodes = Meeting, Person (by normalised `speakerNames`), Topic, Decision, Action, Question; edges = attended, discussed, raised, decided_in, owns, asked, unanswered_in. Topic/person names canonicalised by shared helper (extract `GraphExtractorService`'s canonicalisation into `core/utils/name_canonicalizer.dart` and reuse). Topics merging across meetings is what makes it a graph.
- Reuses `DocGraph/GraphNode/GraphEdge`; `GraphNode` gains optional `sourceIds` (meeting ids) alongside `chunkIndexes`. Type colours extended.
- `meetingGraphProvider` (derived from `historyNotifierProvider`, memoised).
- **Viewer:** Graph page gets a "Documents | Meetings" switch; type filter chips; shows the top ~150 nodes by degree with a "show all" toggle; node details panel lists meetings (title/date), relations, and quotes for decisions/actions/questions. "Build from history" button + progress lives here and on the Coaching page.
- **Live recall:** `MeetingRecallService.recall(transcriptWindow, graph)` matches transcript words to Topic/Person/Action nodes (same seed logic as document retrieval, `DocGraph.seedNodes`), collects connected facts from past meetings (date, decision, action + owner, question that stayed unanswered), caps at ~600 chars, and passes it to `PromptTemplates.buildAnalysisPrompt` as a new "Earlier meetings" block with an instruction to surface it as insights ("Discussed 12 Oct; Sneha owns the follow-up"). The current meeting is excluded (not saved yet). No hit -> block omitted, zero cost.
- Privacy note in docs/UI: recall sends short snippets from earlier meetings to Gemini, the same as the live transcript already does.

### D. UI (Workspace; Zen unchanged apart from a compact report dialog)
- **Coaching page rebuilt:** header (meeting, date, "This is me" chips) -> Scorecard (indicator tiles with status, value, range, delta) -> Goals card (edit up to 3, met/not) -> Strengths / Improvements (quote + tip) -> Outcomes (decisions, my actions, open questions) -> All speakers table -> Progress (sparklines per metric over time via a small `CustomPainter`). Session list stays on the left.
- Settings: "My name" field.
- Markdown/JSON export updated with the new sections (digest, indicators, goals, narrative).

## Files (representative)

New: `coaching/domain/models/{meeting_digest,coaching_feedback,goal}.dart`, `coaching/data/{indicator_evaluator,goal_evaluator,digest_service}.dart`, `coaching/presentation/{scorecard,goals_card,outcomes_card,sparkline}.dart`, `meeting_graph/data/{meeting_graph_builder,meeting_recall_service}.dart`, `meeting_graph/providers/meeting_graph_providers.dart`, `core/utils/name_canonicalizer.dart`.
Changed: `participation_analyzer.dart`, `speaker_metrics.dart`, `meeting_session.dart` (digest, feedback, meSpeakerKey), `coaching_providers.dart` (digest + coaching + backfill), `gemini_service.dart` + `prompt_templates.dart` (digest and coaching prompts; recall block), `ai_providers.dart` (recall context), `deepgram_service.dart` (`filler_words=true`), `graph_view.dart`, `doc_graph.dart`, `workspace_shell.dart` (Coaching page), `settings_*` (myName, goals), `report_export_service.dart`, `app_constants.dart`.

## Sequence
1. Metrics (pace, fillers, monologue, questions, response gap) + indicator/goal evaluators + tests.
2. Digest model + prompt + parser + backfill + tests; session fields; save-time call.
3. Coaching narrative + evidence validation + "This is me" flow + myName/goals settings.
4. Coaching page rebuild (scorecard, goals, outcomes, sparklines).
5. Meeting graph builder + provider + viewer switch + filters + backfill UI.
6. Live recall into the analysis prompt + tests.
7. Export updates, `.docs` plan/task/walkthrough (archive current), CLAUDE.md note.

## Risks / limits (stated honestly)
- "Me" cannot be detected automatically on a mixed mono stream; the user marks it per meeting (future option: separate mic/system channels).
- Pace, fillers and response gaps depend on Deepgram word timings; interruptions stay an estimate. Thresholds are heuristics, not clinical norms.
- Old sessions lack timings, so only text-based items (digest, questions, word counts) are available for them.
- Backfill costs one Gemini call per old meeting; long transcripts are trimmed (head + tail) like the existing review.
- Graph size: <=50 sessions x ~15 nodes; top-150 view keeps it readable; layout already runs off the UI isolate.
- Marking action items "done" is not in scope; recall labels old actions as "from <date>" without claiming they are open.

## Verification
1. `flutter analyze` clean, `flutter test` green. New tests: each delivery metric on hand-built entries; indicator/goal status and trend; evidence-quote validation (hallucinated quote dropped); digest/coaching parsers (fenced/malformed JSON); `MeetingGraphBuilder` merges one topic across two meetings and one person across differently-labelled speakers; `MeetingRecallService` returns the earlier decision/action only on a topic hit and nothing otherwise; JSON back-compat for old sessions.
2. Run macOS: record a short two-person clip, stop, open Coaching, pick "This is me", confirm scorecard, narrative with real quotes, outcomes; mark a goal and check it evaluates.
3. History with older meetings: "Build from history", confirm progress, then Graph -> Meetings shows shared topics linking meetings; click a topic node.
4. Start a new meeting, mention a topic from an old meeting, confirm an "earlier meeting" insight appears.
5. Windows smoke test (Dart-only changes; one `filler_words=true` connection check).
