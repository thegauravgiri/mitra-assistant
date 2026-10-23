## 1. Project Background

Virtual meetings on Zoom, Teams and Google Meet leave two gaps identified in the Assessment 2 literature review: attendees lose key points and unanswered questions under real-time cognitive load, and nobody receives feedback on how they actually participated (talk time, interruptions, turn-taking). Existing tools such as Otter.ai and Fathom only produce a transcript after the call, so they cannot help during the discussion, and none of them turn a speaker-labelled transcript into personal coaching.

This project was initiated by the student after the literature review surfaced that the underlying pieces already exist as separate services (streaming ASR, diarisation, LLM reasoning) but have not been combined into a single, privacy-respecting desktop overlay that avoids sending a recording bot into the call. It sits squarely inside the ITNET312A Major Individual Project brief: it requires the student to scope, design, build, test and document a non-trivial software system end to end, applying the project management and research skills built up in Assessments 1 and 2.

The assistant is a Flutter desktop overlay that captures microphone and system audio locally, streams it to Deepgram for live transcription and diarisation, and periodically sends the rolling transcript to Google Gemini to generate structured insight cards. Figure 1 shows the six-stage pipeline: native audio capture, streaming speech recognition, context building from the rolling transcript and any uploaded reference documents, the Gemini reasoning stage, the live overlay, and a post-meeting coaching stage that is scheduled for the second half of the project.

**[Figure 1: End-to-end system architecture and dataflow block diagram]**

## 2. Requirements Analysis

Requirements were grouped into high-level (what the system must do) and low-level (how it does it), then given IDs so they can be traced through to goals, milestones and test evidence later in this plan.

### 2.1 High-Level Requirements

| ID | Requirement | Priority |
|---|---|---|
| FR1 | Capture microphone and system audio together without an external recording bot joining the call | Must |
| FR2 | Transcribe speech to text live, with a speaker label on each line | Must |
| FR3 | Generate live insights: key points, action items, answers to questions just asked, unanswered-question alerts, suggested follow-up questions | Must |
| FR4 | Present insights in an always-on-top overlay that is invisible to screen recording or screen sharing | Must |
| FR5 | Allow an optional reference document (agenda, spec) to be used as extra context when it becomes relevant | Should |
| FR6 | Measure speaking time, turn-taking and interruptions per speaker after the meeting and write a short review | Should |
| FR7 | Store meeting results so a speaker's measures can be compared across meetings | Could |

### 2.2 Low-Level Requirements

| ID | Requirement | Linked FR |
|---|---|---|
| NFR1 | Rolling transcript sent to Gemini every 12-15 seconds; response forced into a strict JSON schema with a regex-based fallback parser for malformed output | FR3 |
| NFR2 | Audio streamed to Deepgram Nova-2 over a raw WebSocket at 16kHz 16-bit linear PCM, targeting sub-400ms transcription latency | FR2 |
| NFR3 | Audio capture and window visibility are native Swift services; channel names are defined once in `AppConstants` and the Dart wrapper and Swift handler are updated in the same commit | FR1, FR4 |
| NFR4 | Both API keys are supplied by the user at runtime and stored locally via `shared_preferences`; no key is hardcoded or committed | FR1-FR3 |
| NFR5 | Global hotkeys (panic hide, toggle overlay) registered through `hotkey_manager` at OS scope | FR4 |
| NFR6 | Each feature follows the same layered structure (data / domain / providers / presentation) with one Riverpod `StateNotifier` per feature | All |
| NFR7 | Parsing, text-similarity and document-relevance logic covered by unit tests; static analysis run on every change | All |

### 2.3 Requirement Traceability

| Requirement(s) | Project Goal | Milestone | Verification |
|---|---|---|---|
| FR1, FR2, NFR2, NFR3 | G1 | End of Week 5 | 10-minute test call, latency log |
| FR3, NFR1 | G2 | End of Week 7 | Annotated transcript comparison |
| FR4, NFR5 | G3 | End of Week 5 | Screen-share test on Zoom/Teams/Meet |
| FR5 | G4 | End of Week 6 | 5 sample-document relevance test |
| FR6, FR7 | G5 | End of Week 9 | Two-meeting comparison report |
| NFR4, NFR6, NFR7 | G6 | Ongoing, checked weekly | `flutter analyze` + test suite output |

## 3. Project Goals

The following SMART goals cover every requirement above and are scheduled against the 12-week plan agreed in the project charter.

1. **G1 - Live capture and transcription.** By the end of Week 5, capture mixed microphone and system audio on macOS and stream a live, speaker-labelled transcript with sub-400ms token latency, confirmed on a 10-minute recorded test call.
2. **G2 - Live insight generation.** By the end of Week 7, produce structured insight cards (key points, action items, answered/unanswered questions, suggested questions) refreshed at least every 15 seconds, measured against a set of annotated test transcripts with at least 75% of unanswered questions correctly flagged.
3. **G3 - Stealth overlay.** By the end of Week 5, keep the overlay always-on-top, hidden from screen-share capture, and controllable through global hotkeys, verified by sharing the screen in Zoom, Teams and Google Meet while the overlay stays invisible to the recording.
4. **G4 - Document grounding.** By the end of Week 6, chunk an uploaded PDF or DOCX and inject only the locally relevant chunk into the Gemini prompt, tested against five sample documents without increasing the average prompt size.
5. **G5 - Post-meeting coaching.** By the end of Week 9, calculate participation share, turn count and interruption count per speaker, generate a short written review, and store results so one speaker's numbers can be compared across at least two meetings.
6. **G6 - Engineering quality.** Throughout all 12 weeks, keep `flutter analyze` free of warnings and maintain unit-test coverage for all parsing and relevance logic, checked at every weekly commit.

## 4. Methodology and Standards

### 4.1 Development Approach

Because this is a one-person project, full Scrum ceremonies would add overhead without a team to coordinate. Instead, the project runs as a solo iterative cycle: each week has a single planned increment tied to a charter milestone, a short personal stand-up note logged before the next session starts, and a fortnightly review with the supervisor to agree scope changes in writing. This keeps ULO3 (managing time, workload and stress) practical rather than ceremonial, while still producing a visible weekly increment the supervisor can check against the plan.

### 4.2 Architecture and Coding Standards

The codebase follows a feature-first layered structure: every feature under `lib/features/<feature>/` is split into `data/` (platform-channel wrappers, HTTP/WebSocket clients, storage), `domain/models/` (immutable models with `copyWith`), `providers/` (one Riverpod `StateNotifier` and state class per feature) and `presentation/` (widgets that only read state, never call services directly). This was chosen over a looser MVC-style split because it keeps native-bridge code, business logic and UI independently testable, and it matches the conventions already documented in the project's `CLAUDE.md` so any reviewer can predict where a change belongs. Cross-feature communication happens through `ref.read`, avoiding a separate use-case layer that would be unnecessary at this project's scale.

Native functionality (audio capture, window visibility) is implemented as MethodChannel and EventChannel calls into Swift, because `window_manager` and `hotkey_manager` only expose desktop-level window control, not raw system-audio capture. Channel names are defined once in `AppConstants` as the single source of truth, and the Dart wrapper and Swift handler are always changed together, since a mismatch here only surfaces as a runtime exception, not a compile error.

Code style follows the standard Dart/Flutter guide enforced by `flutter_lints` through `analysis_options.yaml`, and commit messages use conventional prefixes (`feat`, `fix`, `docs`, `ci/cd`) already established in the project history, so the log itself documents what changed and why.

### 4.3 Data, Security and API Standards

Both the Deepgram and Gemini API keys are supplied by the user through the Settings screen and stored locally with `shared_preferences`; neither key is ever hardcoded or committed to the repository. Gemini is run in forced JSON response mode using a defined schema, but because LLM output is not always clean JSON, response parsing strips markdown fences and falls back to a regex-extracted JSON array rather than crashing the insight pipeline. Audio and transcripts are processed locally and are not sent anywhere beyond the two named third-party APIs required for transcription and reasoning.

### 4.4 Testing and Tooling Standards

Parsing, text-similarity and document-relevance logic are covered by `flutter test` unit tests, and every change is checked with `flutter analyze` before being committed; a GitHub Actions workflow re-runs these checks on push. OS-level behaviour such as global hotkeys and screen-share masking cannot be exercised by widget tests, so these paths are verified manually by running the app on physical macOS hardware, matching the CLAUDE.md guidance that only `flutter run -d macos` can confirm they work end to end.

### 4.5 Tools and Technology Justification

| Tool / Technology | Role | Why it was chosen |
|---|---|---|
| Flutter / Dart | Desktop UI shell | Single codebase for the always-on-top overlay across macOS now and Windows later |
| Deepgram Nova-2 | Streaming ASR and diarisation | WebSocket streaming API with sub-400ms tokens and built-in speaker labels, avoiding a separate diarisation model |
| Google Gemini 2.5 Flash | Insight and coaching reasoning | Fast structured JSON output at a cost that fits the AUD 100-200 project budget |
| Riverpod | State management | Compile-time-safe dependency access and testable `StateNotifier`s without the boilerplate of BLoC |
| window_manager / hotkey_manager | Overlay behaviour and global hotkeys | The only maintained Flutter packages exposing frameless always-on-top windows and OS-level hotkeys |
| Graphify | Longitudinal knowledge base | Graph storage suits comparing one speaker's measures across many meetings over time |
| GitHub Actions | Continuous checks | Runs `flutter analyze` and a build on every push so regressions are caught before they reach a milestone review |

## 5. Resources, Staffing and Cost

The student is the sole team member and covers every role: developer, tester, project manager and technical writer. The supervisor acts as an advisor through fortnightly reviews and sign-off on scope changes. A small pool of consenting classmates or colleagues provides recorded test meetings for evaluating diarisation and coaching output; the assessment panel is the final audience for the report and demonstration.

All development hardware and software (a Mac for the primary build, Xcode, VS Code) is already owned, so the only direct cost is API usage:

| Item | Estimated Cost (AUD) |
|---|---|
| Deepgram transcription and diarisation | 60-120 |
| Gemini analysis and coaching generation | 40-80 |
| Hardware and development tools | 0 (already owned) |
| **Total** | **100-200** |

## 6. Implementation Timeline

The project runs for 12 weeks from the charter start date. As of this submission the project is at the end of Week 4, on schedule against the Week 5 milestone.

| Phase | Weeks | Status |
|---|---|---|
| Requirements and review of existing tools | 1-2 | Complete |
| Architecture and interface design | 2-3 | Complete |
| Native audio capture, live transcription, stealth overlay | 3-5 | In progress - capture, transcription and overlay are working; speaker-label stability under overlapping speech is being tuned this week |
| Document upload and context grounding | 5-6 | In progress - upload, chunking and local relevance matching are implemented; being refined against the 5-document test set |
| Live insight engine and unanswered-question alerts | 6-7 | Planned |
| Participation analysis and per-speaker coaching review | 8-9 | Planned |
| Graphify knowledge base and cross-meeting comparison | 9 | Planned |
| Annotated test meetings and evaluation | 10-11 | Planned |
| Report and demonstration | 12 | Planned |

Audio capture, live Deepgram transcription, the compact/expanded overlay with screen-share masking, the Settings screen for API keys, document upload with relevance matching, and a meeting-history view with CSV export are already working end to end on macOS, which is why the plan brings forward the diarisation and document-grounding tuning that remains before the Week 5 milestone can be signed off.

## 7. Evaluation Plan

The project will be evaluated against the quality targets set in the project charter, using consented test meetings recorded specifically for this purpose:

- Live insights must appear within 15 seconds of the relevant point in the conversation, measured from transcript timestamp to insight card timestamp.
- Unanswered-question detection must reach at least 75% accuracy against a manually annotated set of test meetings.
- Per-speaker speaking time must be within 10% of a manual stopwatch measurement.
- The app must run a 30-minute meeting on macOS without crashing.

Results will be logged against each target in the final report, alongside supervisor sign-off that the acceptance criteria in the project charter have been met.

## 8. Risk Management

| Risk | Impact | Probability | Current Status | Mitigation |
|---|---|---|---|---|
| Diarisation mislabels speakers on overlapping audio | High | High | Active - being tuned in Week 5 | Test with real meeting audio, tune Deepgram settings, fall back to a single-speaker label if confidence is low |
| Live insights arrive too late to be useful | High | Medium | Not yet measured | Fixed 12-15s analysis interval, short prompts, latency logging from Week 7 |
| Gemini output is malformed or invented | Medium | Medium | Mitigated | Structured JSON schema with regex fallback parsing already implemented; output shown as suggestions, not facts |
| Windows audio capture takes longer than planned | Medium | Medium | Deferred, unchanged | macOS-first delivery, Windows port scheduled for Week 9 behind one shared Dart interface |

## 9. Conclusion

This plan turns the gaps identified in the literature review into a concrete build: a macOS overlay that already captures audio, transcribes it live and displays it without appearing in a screen share, with document grounding in progress and coaching analytics scheduled for the second half of the project. Requirements have been traced through to SMART goals and weekly milestones, the architecture and tooling choices are justified against the project's solo, budget-constrained context, and the risk register is being actively worked rather than left as a formality. On the current trajectory the project remains on track to meet all milestones in the charter and to deliver a demonstrable prototype by Week 12.
