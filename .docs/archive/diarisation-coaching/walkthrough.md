# Walkthrough: Diarisation, Coaching & Evaluation

## What changed
- **Diarisation (FR2):** Deepgram now requests `diarize=true` on `nova-2`. `DeepgramMessageParser` (pure) extracts the majority speaker and first/last word timings; `TranscriptEntry` gained `speakerIndex`, `startSec`, `endSec` (old sessions still load). Transcript view shows coloured speaker chips; Gemini receives `Speaker N:` labelled text.
- **Insights (FR3):** new `answer` and `unansweredQuestion` categories (prompt, parser, UI). Each periodic insight records `latencyMs` (newest final line → arrival), logged via `AppLogger`.
- **Coaching (FR6):** new `features/coaching/` — `ParticipationAnalyzer` (talk time/share, turns, interruptions), Gemini per-speaker reviews (separate model so the insight system prompt doesn't interfere), report dialog with speaker rename. Metrics are saved immediately on stop; the review arrives in the background.
- **Comparison (FR7):** `ProgressService` + progress dialog (History toolbar) compare a named person across meetings.
- **Export / evaluation:** Markdown report and session JSON export (`Documents/MitraAssistant/{reports,sessions}`); `tool/evaluate_session.dart` scores a session against a hand annotation.

## Verification run
- `flutter analyze`: no issues. `flutter test`: 37 passed.
- `dart run tool/evaluate_session.dart` on a hand-made session: correct output.

## Not yet verified (needs a real run)
- Live diarisation quality on real audio (`flutter run -d macos` / `windows`), Gemini review quality, and the dialogs visually.
- Interruption counts are a heuristic on a mixed mono stream.
- Graphify is only an offline consumer of `reports/`; the app does not call it.
