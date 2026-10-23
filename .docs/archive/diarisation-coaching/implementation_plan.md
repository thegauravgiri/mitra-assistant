# Plan: Finish remaining charter scope (diarisation → insights → coaching → comparison → evaluation)

## Context

The app (Mitra Assistant / "AI Meeting Communication Coach") already has audio capture (macOS + Windows), live Deepgram transcription, the stealth overlay, document grounding, and history with CSV export. `flutter analyze` is clean and 16 tests pass.

Measured against the charter's acceptance criteria and the project plan's FR1–FR7, the gaps are:

| Req | Status today | Gap |
|---|---|---|
| FR2: speaker-labelled transcript | **Not done** | `deepgram_service.dart` doesn't send `diarize=true`. `TranscriptEntry.speaker` is always `'Meeting Participant'` and no word timings are kept. |
| FR3: answers and unanswered-question alerts | Partial | `InsightCategory` only has suggestion, keyPoint, question and actionItem. Gemini gets the transcript without speaker labels. No latency is measured, so the "≤15 s" target can't be checked. |
| FR6: participation, turns, interruptions and a per-speaker review | **Missing** | Nothing in `lib/` computes these. |
| FR7: compare one speaker across meetings | **Missing** | `MeetingSession` stores no metrics or speaker identities. |
| Evaluation (acceptance #5) | **Missing** | Insights aren't saved with sessions, so there's nothing to score against annotations. |

Timeline: the charter starts on 16/08/2026, and today (19/10/2026) is **Week 10**. The plan scheduled participation analysis for Weeks 8–9 and evaluation for Weeks 10–11, so this work is behind. Phases 1–3 come first.

Decisions already made: diarisation uses Deepgram `diarize` on the existing mono stream, with no native changes. Speakers can be renamed after a meeting. Cross-meeting data goes in the existing history JSON (`shared_preferences`), plus a Markdown report export that Graphify can be run over offline. This plan covers code only; the academic documents are a separate task.

## Phase 0: Housekeeping (follows the `.docs/` workflow convention)
- Move the finished document-upload `implementation_plan.md`, `task.md` and `walkthrough.md` into `.docs/archive/document-upload/`.
- Write this plan into `.docs/implementation_plan.md`, with a matching checklist in `.docs/task.md`.

## Phase 1: Diarisation and word timings (FR2)
- **`lib/features/transcription/data/deepgram_service.dart`**
  - Add `model=nova-2&diarize=true` to the listen URL. Nova-2 matches NFR2.
  - Move message parsing out of `_handleMessage` into a pure, testable `DeepgramMessageParser.parse(Map) → TranscriptEntry?`. It reads `alternatives[0].words[]` and works out:
    - the speaker, by majority vote over `word.speaker`;
    - `startSec` as the first word's `start`;
    - `endSec` as the last word's `end`.
  - Keep a per-connection time offset. Deepgram timestamps restart on reconnect, so the offset keeps them increasing.
- **`transcript_entry.dart`**: add nullable `speakerIndex`, `startSec` and `endSec` to the fields, `copyWith` and JSON.
  - Old saved sessions must still load, so missing keys parse to null.
  - The label stays in `speaker` as "Speaker N".
- **`transcription_providers.dart`**: add a `labelledTranscript` getter that produces lines like `Speaker 1: …`. Switch `AiNotifier` (`ai_providers.dart`) from `fullTextTranscript` to the new getter, so Gemini can tell who asked what.
- **`transcript_view.dart`**: show a speaker chip on each line, grouping consecutive lines from the same speaker. Each speaker gets a stable colour from `design_tokens.dart`.

## Phase 2: Answers, unanswered-question alerts and latency (FR3)
- **`insight.dart`**: add `answer` and `unansweredQuestion` to `InsightCategory`. Keep the parser's fallback for unknown categories in `gemini_service.dart` (`_parseInsightsJson`), and preserve the fence-stripping and regex fallback too.
- **`prompt_templates.dart`**: add both categories to the system prompt.
  - `unansweredQuestion` is a question a speaker asked that later turns didn't answer. It must quote the question and name the speaker.
  - `answer` is a short answer to a question that was just asked, grounded in the transcript or documents.
- **`insight_view.dart`**: give each new category its own icon and colour. `unansweredQuestion` uses alert styling.
- **`ai_providers.dart`**: record latency as the time from the newest final entry to the insight's arrival. Store it on `Insight` (`latencyMs`) and log it with `AppLogger`.

## Phase 3: Participation analysis and per-speaker review (FR6)
New feature `lib/features/coaching/`, following the standard layering:
- **`domain/models/speaker_metrics.dart`** holds `speakerKey`, `talkTimeSec`, `talkSharePct`, `turnCount`, `wordCount`, `interruptionsMade` and `interruptionsReceived`. It is immutable, with `copyWith` and JSON.
- **`domain/models/coaching_report.dart`** holds a list of metrics, a map of speaker reviews (`Map<String, String>`) and `generatedAt`.
- **`data/participation_analyzer.dart`** is a pure function over `List<TranscriptEntry>`:
  - A turn is consecutive same-speaker entries separated by a gap of no more than `AppConstants.turnMergeGapSec` (1.5 s).
  - Talk time is the sum of `endSec − startSec`. Entries without timings count towards words and turns but not time.
  - An interruption is a speaker change where the next turn starts before the previous one ends. It also counts when the gap is under `AppConstants.interruptGapSec` (0.3 s) and the previous turn didn't end in `.`, `?` or `!`. On a mono stream this is a heuristic, and the in-code docs will say so.
- **`gemini_service.dart` and `prompt_templates.dart`**: add `generateSpeakerReviews(metrics, labelledTranscript)`. It returns JSON `{speakerKey: review}` and reuses the existing JSON cleaning.
- **`providers/coaching_providers.dart`**: `CoachingNotifier` builds the report when a meeting is saved.
  - The metrics are filled in immediately.
  - The review is generated asynchronously, then written back to the session.
- **`presentation/coaching_report_view.dart`**: opened from a history session. It shows:
  - a metrics table;
  - talk-share bars;
  - the review text for each speaker;
  - a rename action that maps `Speaker N` to a name.
- **`meeting_session.dart`** gets nullable `coachingReport`, `speakerNames` (`Map<String, String>`) and `insights` (a snapshot used for evaluation). All are backward-compatible in JSON.
- **`history_repository.dart` and `history_providers.dart`**: add `updateSession`. `saveCurrentMeeting` will also take the insights.

## Phase 4: Cross-meeting comparison and Markdown export (FR7)
- **`coaching/data/progress_service.dart`** is pure. Given sessions and a person's name (matched trimmed and case-insensitive against `speakerNames`), it returns time-ordered metrics.
- **`coaching/presentation/progress_view.dart`** adds a "Progress" section to the history tab. You pick a person and see talk share, turns and interruptions across meetings.
- **`coaching/data/report_export_service.dart`** writes `MitraAssistant/reports/<date>-<title>.md` using the same `path_provider` documents-dir logic as `history/data/csv_export_service.dart`. The file has the metrics table, the reviews and the unanswered questions. Graphify can be run over that folder offline; the README will say so. The app does not call Graphify.

## Phase 5: Evaluation support (acceptance #5)
- Add **Export session JSON** next to the CSV export. It writes the entries with timings and speakers, the insights with latency, and the metrics.
- Add **`tool/evaluate_session.dart`**, a CLI. It reads a session JSON plus a hand-made annotation JSON (manual talk seconds per speaker and the list of unanswered questions) and prints:
  - talk-time error per speaker (target ≤10%);
  - unanswered-question recall and precision (target ≥75%);
  - median and p90 insight latency (target ≤15 s).
- Keep the scoring logic in a small pure library so it can be unit-tested.

## Tests (one per new pure unit, in the existing `test/` layout)
- `test/features/transcription/deepgram_message_parser_test.dart`: speaker majority vote, timings, empty transcript, missing `words`.
- `test/features/coaching/participation_analyzer_test.dart`: turn merging, talk share adds up to 100, interruptions from overlap and from a short gap, entries without timings.
- `test/features/coaching/progress_service_test.dart`: name matching, ordering.
- Extend `test/history_test.dart` so old-format session JSON still loads.
- Extend `test/unit_test.dart` with parsing of the new insight categories.
- Add a test for the evaluation scorer.

## Verification
1. `flutter analyze` (zero issues) and `flutter test` (all pass).
2. Run `flutter run -d macos` and play a two-person YouTube interview through system audio. Check that:
   - the transcript shows Speaker 1 and Speaker 2;
   - an unanswered-question card appears;
   - latency shows in the debug log.
3. Stop and save the meeting, then open it in History. Check that the coaching report has metrics and reviews. Rename the speakers, save a second meeting with the same names, and check the Progress view.
4. Export both the Markdown report and the session JSON. Run `dart run tool/evaluate_session.dart <session.json> <annotation.json>` against a short hand-annotated clip.
5. Smoke-test on Windows (`flutter run -d windows`). It's the same Dart path, but it confirms there's no platform regression.
