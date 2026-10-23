# Task Checklist: Diarisation, Coaching & Evaluation

Legend: `[ ]` todo · `[/]` in progress · `[x]` done

See [implementation_plan.md](implementation_plan.md) for full detail. Previous cycle archived in [archive/document-upload/](archive/document-upload/).

## Phase 1 — Diarisation & word timings (FR2)
- [x] `DeepgramMessageParser` + `diarize=true`, `model=nova-2`
- [x] `TranscriptEntry`: `speakerIndex`, `startSec`, `endSec` (backward-compatible JSON)
- [x] `labelledTranscript` getter; `AiNotifier` uses it
- [x] Transcript view speaker chips/colours
- [x] Tests: parser

## Phase 2 — Answers, unanswered questions, latency (FR3)
- [x] New `InsightCategory` values + prompt + UI
- [x] Latency measurement on `Insight`

## Phase 3 — Participation analysis & review (FR6)
- [x] `features/coaching/` models, `ParticipationAnalyzer`, Gemini speaker reviews
- [x] `MeetingSession` extended (report, speakerNames, insights); `updateSession`
- [x] Coaching report view + speaker rename
- [x] Tests: analyzer, history back-compat

## Phase 4 — Cross-meeting comparison & MD export (FR7)
- [x] `ProgressService` + Progress view
- [x] Markdown report export

## Phase 5 — Evaluation support
- [x] Session JSON export
- [x] `tool/evaluate_session.dart` + scorer tests
