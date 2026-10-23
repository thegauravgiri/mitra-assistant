# Defence Prep: Likely Questions from the Supervisor/Panel

**Project:** AI Meeting Communication Coach (codebase name: Mitra Assistant)
**Purpose of this document:** Question-and-answer pairs to rehearse before the Assessment 3 early-stage presentation. Answers are written the way you should say them out loud — plain language first, technical term in brackets where it matters. A few entries flag things that are **not fully true yet** in the current build; those are the questions most likely to catch you out if you just repeat the plan from memory, so they are marked clearly and you should answer them honestly rather than oversell.

How to use this: read a section the night before, close the file, and try to answer out loud before checking. If a panel member asks something not listed here, fall back to the same pattern every answer below follows: what it does → why that choice → how you'd verify it → what the honest limitation is.

---

## 1. Problem and Motivation

**Q1. In one sentence, what problem does this project solve?**
People lose track of key points and unanswered questions while a meeting is happening, and nobody ever gets told how they actually participated (talk time, interruptions) — this app gives live help during the call and a short coaching review after it, from the same speaker-labelled transcript.

**Q2. Why does this need to happen live? Couldn't a summary after the meeting be enough?**
A post-meeting summary can't help you ask a better follow-up question five seconds from now, or tell you a question from ten minutes ago was never answered while the conversation is still open. That's the actual gap tools like Otter.ai and Fathom leave — they are accurate, but they are late. The cost of "live" is that the AI has to work with a partial, still-changing transcript instead of a clean final one, which is why the insight engine re-runs on a rolling window every 12–15 seconds rather than waiting for the meeting to end.

**Q3. Why should anyone trust a tool telling them how they communicated? Isn't that subjective?**
The coaching side deliberately measures only objective, countable things — speaking time share, number of turns, number of interruptions — not tone or personality. Those numbers come straight from the timestamped, speaker-labelled transcript, so they're closer to "here's the data" than "here's my opinion of you." The write-up is framed as a suggestion, not a verdict, for the same reason the AI insight cards are framed as suggestions and not facts.

---

## 2. Existing Solutions and Novelty

**Q4. Otter.ai, Fathom and Zoom AI Companion already do this — what's actually new here?**
Two things those tools don't do together: (1) they all require a bot to join the call as a visible participant to record it, which is why many workplaces restrict them, while this app captures audio locally on the same machine with no bot in the roster; and (2) none of them turn the speaker-labelled transcript into a personal participation review — they summarise content, not conduct. The novelty is the combination — real-time coaching from a stealth desktop overlay — not any single piece, since streaming transcription and LLM summarisation both already exist as separate services.

**Q5. Aren't you just gluing together three APIs (Deepgram, Gemini, and window/hotkey packages)? Where's the engineering?**
Yes, the individual building blocks are third-party APIs — that's a deliberate scope decision (see Q19). The engineering is in the parts that don't come out of the box: fusing two audio channels into one stream, keeping a rolling context window small enough to stay under Gemini's 15-second refresh target without losing meaning, parsing LLM output that isn't always valid JSON without crashing, and making the overlay invisible to screen capture while still visible to the user. None of the three vendors ship that integration.

**Q6. Why Flutter instead of a native Swift app if macOS is the only platform that works right now?**
The charter's stated end goal is macOS and Windows from one codebase, and Flutter is one of the few frameworks with mature desktop window control (`window_manager`) and global hotkeys (`hotkey_manager`) across both. Native audio capture and screen-share masking are unavoidably OS-specific either way (Swift on macOS, would be C++/WASAPI on Windows), so that native layer exists either way — Flutter just avoids rewriting the UI and business logic a second time when the Windows port happens.

---

## 3. System Architecture and Data Flow

**Q7. Walk me through what happens from someone speaking to an insight appearing on screen.**
Microphone and system audio are captured natively (Swift, via `AVAudioEngine` and `ScreenCaptureKit`), mixed into one 16kHz 16-bit PCM stream, and pushed to Deepgram over a WebSocket, which streams back words as they're recognised. Those words build a rolling transcript. Every 12–15 seconds, that rolling window (plus any relevant chunk from an uploaded document) is sent to Gemini with a forced JSON response format. Gemini's structured response is parsed into typed "Insight" objects and rendered as cards in the always-on-top overlay.

**Q8. Why 12–15 seconds specifically, and not, say, every 5 seconds or only when someone finishes speaking?**
It's a latency/cost trade-off, not a technical limit. Shorter windows mean insights feel more "live" but cost more API calls and can fire on incomplete thoughts; longer windows are cheaper and more coherent but feel laggy. 12–15 seconds was chosen as a starting point matched to natural pause lengths in conversation and is one of the first things to tune once real latency numbers exist (see the evaluation plan).

**Q9. What happens if the Gemini API is down or the key is invalid mid-meeting?**
The call is wrapped in a try/catch that surfaces a specific error (e.g. "Invalid Gemini API Key") rather than crashing the app, and the failure is scoped to that one analysis cycle — the transcript keeps recording locally regardless of whether insight generation succeeds. It does mean a live outage means no new insight cards until the next successful cycle; there's no offline fallback model, which is an accepted limitation for a prototype.

**Q10. What's the single biggest technical risk in this architecture?**
Diarisation reliability under overlapping speech (see Section 4) — if speaker labels are wrong, both the live insight quality and the entire post-meeting coaching feature (which depends on knowing who spoke) are undermined. Everything else in the pipeline degrades gracefully; that one doesn't.

---

## 4. Speech Recognition and Speaker Diarisation

**Q11. What is diarisation, in plain terms, and why is it hard to do live?**
Diarisation answers "who spoke when" — attaching a speaker label to each stretch of audio, separately from recognising the words themselves. It's harder live than after the fact because an offline system can listen to the whole recording and cluster voices with full context, while a streaming system has to commit to a speaker label immediately and can't go back and quietly relabel earlier lines without the label visibly "flickering" on screen. Overlapping speech — people talking over each other — is the main failure case, and studies of meeting audio put overlap at roughly 10–30% of speaking time, so it isn't a rare edge case. [Source: general speaker diarisation literature, e.g. arXiv 2406.14464.]

**Q12. Which model are you using for speech recognition, and how fast is it?**
Deepgram's real-time Nova model family, connected over a raw WebSocket rather than Deepgram's SDK. Deepgram publishes P50 (median) end-to-end latency in the 337–509ms range for streaming transcription, with Nova-2 specifically benchmarked at up to 30% lower word-error-rate than the previous generation. [Source: Deepgram's own Nova-2 and streaming API documentation.] Be ready for a follow-up on exact model name — see the honest caveat below.

**⚠️ Honest caveat to have ready:** the current WebSocket connection URL does not yet pass Deepgram's `diarize=true` parameter, so today's build is not actually receiving per-speaker labels from Deepgram — the "speaker" field in the code currently defaults to a placeholder ("Meeting Participant") rather than a real diarised value. If asked directly: **say this plainly rather than claim it's finished.** The honest answer is: "Diarisation is the Week 5 milestone item still in progress — the plumbing (the `speaker` field on every transcript line) is already in place end-to-end from the model through to the UI and CSV export, and the remaining work is enabling the parameter on the Deepgram connection and mapping its per-word speaker index to a stable on-screen label." This is a normal and defensible state for a plan submitted mid-way through Week 4/5 of a 12-week project — the risk register already names this as the top risk, and it's why the SMART goal for it is scoped to end of Week 5, not sooner.

**Q13. If Deepgram mislabels two overlapping speakers, what does your app do?**
Per the risk mitigation already planned: fall back to a single combined "speaker" label when Deepgram's confidence is low, rather than showing a wrong name with false confidence. The participation-analytics feature (Q17) inherits whatever labels diarisation produces, so its accuracy is capped by diarisation accuracy — that dependency is called out directly in the requirement traceability table (FR6/FR7 depend on FR2).

**Q14. Why WebSockets and not Deepgram's own SDK?**
A raw WebSocket connection keeps the dependency surface small and the exact wire protocol visible and debuggable, rather than depending on an SDK's abstractions and update cycle for what is, at its core, sending PCM bytes and receiving JSON. It also matches how the audio pipeline already streams via `EventChannel` from the native side, so there's one obvious data shape moving through the whole app.

---

## 5. The LLM Reasoning Engine (Gemini)

**Q15. Why Gemini 2.5 Flash and not GPT-4, Claude, or a local/open model?**
Three practical reasons: cost, speed, and native structured-output support. Gemini 2.5 Flash is priced at roughly $0.30 per million input tokens and $2.50 per million output tokens [Source: OpenRouter/CloudPrice model pricing pages, 2026], which comfortably fits inside the AUD 100–200 total project budget even with a 15-second refresh cycle running for hours of test meetings. It also has a native JSON-schema-constrained output mode, which is what makes the "forced JSON" parsing pipeline possible in the first place. A local model was ruled out because running a capable LLM locally alongside real-time audio processing is a heavier hardware ask than a solo 12-week project budget supports.

**Q16. LLMs are known to hallucinate. How do you stop it inventing an action item that was never said?**
Three layers, none of which is "trust the model": (1) the prompt is deliberately narrow — it only sees the current rolling transcript window plus, at most, one relevant document chunk, not the model's general world knowledge; (2) the response is forced into a strict JSON schema, and anything that doesn't parse — even after stripping markdown fences and a regex-based fallback extraction — is simply dropped rather than shown; (3) everything the model returns is displayed as a suggestion, explicitly not asserted as fact, so a wrong action item is a false suggestion the user visibly dismisses, not a silent record. This is a mitigation, not a guarantee — hallucination risk is listed in the project risk register as "Medium/Medium," not "solved."

**Q17. How exactly will the post-meeting coaching feature calculate participation share and interruptions?**
Participation share is each speaker's total speaking duration divided by the meeting's total speaking duration, from the timestamped transcript. An interruption is currently planned as: speaker B's turn starts before speaker A's turn has ended (an overlap in the timestamps), which is a standard, simple operational definition — it will not detect a supportive "mm-hmm" backchannel as an interruption if segmented finely enough, which is a known modelling simplification worth naming if pushed on it.

---

## 6. The Overlay, Hotkeys, and "Stealth" Screen-Share Masking

**Q18. How does the overlay stay hidden from screen sharing, technically?**
By setting the native macOS window property `NSWindow.sharingType = .none`, which historically removes the window from the OS's screen-capture pipeline entirely — any app using the standard capture APIs, including Zoom, Teams or Meet, receives a frame that never contained that window, rather than the app choosing to hide it (so the meeting app can't override it).

**⚠️ Honest caveat to have ready — this is a strong "did you actually check this" question:** Apple changed how screen capture works starting with macOS 15 (Sequoia): capture now goes through a compositor that assembles the whole screen into one framebuffer before `ScreenCaptureKit`-based capture reads it, and multiple developer reports (including an open GitHub issue against a well-known cross-platform app framework) say `sharingType = .none` no longer reliably excludes a window from `ScreenCaptureKit` captures on macOS 15+, while it still works for the older `CGWindowListCreateImage`-style capture path. Whether a given meeting app is affected depends on which capture API *that app* uses, which is not something this project controls or has fully verified across Zoom/Teams/Meet and macOS versions yet. The right answer if pressed: "I'm relying on the documented public API for this, `sharingType = .none`; I know Apple's screen-capture internals changed in macOS 15 and that this is reported as unreliable in some cases on ScreenCaptureKit-based capture, so verifying this against the actual meeting apps on the actual macOS version being demoed is on the test plan before the final evaluation, not something I'm assuming is solved." Do not claim it is guaranteed to work on every macOS version — that is not currently true.

**Q19. What if the panic-hide hotkey doesn't fire in time, or the meeting app takes a screenshot instead of a live share?**
Panic-hide (`Cmd+Shift+H`) fully removes the window (`orderOut`), which is a stronger guarantee than sharing-type masking, but it's a manual action, not automatic — it relies on the user reacting. A screenshot taken by another app through a different capture path is outside this project's control entirely; the scope is limited to standard screen-share/recording capture, and that boundary should be stated explicitly rather than implied to cover everything.

**Q20. Why global hotkeys instead of an in-app button for panic-hide?**
Because the whole point of panic-hide is that it has to work even when the overlay isn't focused, or is about to be seen on someone else's shared screen right now — `hotkey_manager` registers the shortcut at the OS level (`HotKeyScope.system`), so it fires regardless of which window has focus.

---

## 7. Software Engineering Practices

**Q21. Why this specific folder structure (data/domain/providers/presentation) instead of something simpler?**
Because native-bridge code (talking to Swift), business logic, and UI have very different failure modes and testing needs — a `data/` service can throw a `PlatformException` that a `presentation/` widget should never see directly. Splitting them means the parsing logic (Q16) can be unit-tested without a running UI, and it matches a structure documented once (in `CLAUDE.md`) so every feature looks the same rather than each one improvising its own layout.

**Q22. Why Riverpod instead of plain `setState`, Provider, or BLoC?**
`setState` doesn't scale past a single widget's local state and doesn't let one feature read another feature's state (which this app needs — the AI feature reads the current transcript and API keys from two other features). Riverpod gives compile-time-checked access to state without needing a `BuildContext`, and one `StateNotifier` per feature is enough structure for a one-person project without BLoC's heavier event/state boilerplate, which pays off more on larger teams. [General comparison consistent with current Flutter community guidance, 2026.]

**Q23. How do you actually test something like a global hotkey or the screen-share masking, if they're OS-level?**
You can't, meaningfully, with `flutter test` widget tests — there's no simulated OS to intercept. Those paths are verified manually by running the real app on real macOS hardware (`flutter run -d macos`) and actually sharing the screen / pressing the hotkey. What *is* unit-tested is everything that doesn't need the OS: JSON parsing, text-similarity matching for document relevance, and the fallback regex extraction — anything that's pure Dart logic.

**Q24. What does "requirement traceability" actually buy you here, beyond looking organised for the report?**
It stops scope drift: every low-level requirement is only allowed to exist because it serves a numbered high-level requirement, and every SMART goal has to be traceable back to specific requirement IDs. In practice it means when a feature request comes up mid-project ("what about Slack integration?"), the answer is fast: it doesn't map to any FR/NFR in the charter, so it's out of scope unless a documented, written scope change happens with the supervisor.

---

## 8. Data, Privacy, Security and Ethics

**Q25. Where do API keys live, and is that actually secure?**
They're entered once in Settings and stored locally with `shared_preferences`. Asked directly: **this is not encrypted storage** — on macOS, `shared_preferences` backs onto a plist file, readable by anything with access to that user account, not a secure enclave or keychain entry. It's an acceptable trade-off for a solo prototype where the keys are the user's own and never leave the local machine or get committed to source control, but a production version would move this to `flutter_secure_storage`, which does use the OS keychain. Good to say this proactively — it shows you know the difference rather than assuming "stored locally" means "stored safely."

**Q26. Is it legal to record a meeting like this without everyone's consent?**
It depends on jurisdiction, and this matters for the ethics approval already flagged in the charter. In Australia, recording consent law is state-based, not one federal rule: Victoria and Queensland allow one-party consent (fine if you are a participant), while NSW and Western Australia require all-party consent under their respective surveillance devices legislation. [Source: Australian state surveillance devices legislation as summarised by current legal-explainer sources, 2026 — verify against the specific state before the actual evaluation, since this is exactly the kind of claim to double-check rather than assert from memory.] This is precisely why the charter requires written consent from every test participant and university ethics sign-off before any test meeting is recorded, regardless of which state's minimum applies.

**Q27. Where does the audio and transcript data go — is anything sent anywhere besides Deepgram and Gemini?**
No. Audio is captured and streamed directly to Deepgram for transcription and back; the transcript window is sent directly to Gemini for analysis. There's no third server, backend, or analytics pipeline in between — the Flutter app is the only thing that ever holds the full transcript, and it's stored locally (meeting history feature) rather than in the cloud.

**Q28. What happens to a test participant's data after the evaluation is done?**
Per the charter's stakeholder plan: local storage only, deleted after evaluation is complete — this should be stated as a concrete deletion step in the final report, not just a policy line, since "we said we would" is weaker evidence than "here's the deletion happening in the demo."

---

## 9. Project Management: Methodology, Risk, Timeline, Budget

**Q29. Why an informal solo-iterative approach instead of "real" Scrum or Kanban?**
Scrum's ceremonies (sprint planning, daily stand-ups, retros, a Scrum Master role) exist to coordinate *multiple* people's work — with one developer, there's no one to synchronise with, so running full ceremonies would be process theatre. What's kept from agile practice is the part that still adds value solo: short iterations, a visible weekly increment, and a fixed cadence of external check-ins (the fortnightly supervisor review) that plays the same role a sprint review would for a team.

**Q30. Your goals are dated by week. What happens if Week 5's diarisation work isn't done by Week 5?**
That's exactly what the risk register and the fortnightly supervisor review are for — a missed milestone should trigger a written, agreed scope or timeline adjustment with the supervisor, not silent slippage. The plan already reflects one such judgement call: diarisation tuning was flagged as "active, high probability/high impact" risk rather than assumed solved, precisely so a delay here isn't a surprise later.

**Q31. Walk me through where the AUD 100–200 estimate actually comes from.**
Deepgram's real-time streaming rate is roughly $0.0077/minute (about $0.46/hour) [Source: Deepgram pricing pages, 2026], and Gemini 2.5 Flash is about $0.30/$2.50 per million input/output tokens [Source: OpenRouter/CloudPrice, 2026]. For a project's worth of test meetings — a handful of 30–45 minute recorded sessions across the evaluation phase — both of those come out to only a few dollars USD in practice; the $100–200 AUD figure in the charter is a conservative ceiling with margin for repeated testing and iteration, not a tight budget expected to be fully spent.

**Q32. If you had to cut one feature to hit the Week 12 deadline, what goes first, and why?**
By the requirement priority table: anything marked "Could" (currently FR7, cross-meeting comparison) goes before anything marked "Must." The core "Must" loop — capture, transcribe, live-insight, stealth overlay — is what makes this a meeting assistant at all; participation analytics and cross-meeting storage are valuable additions on top of a working core, not the core itself.

---

## 10. Evaluation and Success Criteria

**Q33. How will you actually measure "insights within 15 seconds," rather than just asserting it?**
By logging two timestamps for every insight: the timestamp of the transcript moment it relates to, and the timestamp the insight card was rendered, and taking the difference — this is a stopwatch-style measurement against recorded test audio, not a subjective "it felt fast" impression.

**Q34. How do you evaluate whether unanswered-question detection is "75% accurate" — accurate compared to what?**
Against a manually annotated set of test meetings: a human (the student, and ideally a second reviewer) marks every question in the transcript as answered or unanswered by listening to the recording, and that manual annotation becomes the ground truth the app's own detections are scored against. This needs to be built as an actual labelled dataset during the evaluation weeks, not assumed — worth being explicit that this doesn't exist yet.

**Q35. What counts as the project failing, versus just falling short of a stretch target?**
The acceptance criteria in the charter are the pass/fail line: it must run end-to-end on macOS with a live speaker-labelled transcript, show live insights and unanswered-question alerts, produce a participation writeup, and be demonstrable on a real test meeting. The specific numeric targets (15 seconds, 75%, 10%) are quality targets to report against honestly, even if some fall short — falling short of 75% and reporting 68% with an explanation is a defensible outcome; silently not measuring it at all is not.

---

## 11. Scope, Limitations and Future Work

**Q36. What are you explicitly NOT building, and why?**
Per the charter: no mobile or web version, no Linux support, no video or facial-expression analysis, no Zoom/calendar API integration, no user accounts or cloud sync, English only. Each of these was cut to keep a one-person, 12-week project achievable — video/tone analysis in particular would need an entirely different technical stack (computer vision) on top of everything already planned.

**Q37. "Graphify" is named in the charter as the knowledge base for cross-meeting comparison — what is it, exactly, and does it actually fit that job?**
Graphify (from Graphify-Labs, backed by Y Combinator's S26 batch — a real, actively developed tool, not a hypothetical) turns a codebase — "any codebase, with its docs, SQL schemas, configs, and PDFs" per its own tagline — into a queryable knowledge graph. It's a Python CLI, parses source with tree-sitter across 37 languages, clusters related concepts using the Leiden community-detection algorithm, and is normally run as `/graphify .` inside an AI coding assistant (Claude Code, Cursor, Gemini CLI and others), producing an interactive `graph.html`, a `GRAPH_REPORT.md`, and a queryable `graph.json` — with an option to export into Neo4j or FalkorDB for larger graphs.

Two things worth saying honestly if pressed on the fit:
1. **It's not a database your Flutter app calls at runtime.** There's no Dart SDK; it's a separate Python CLI/AI-assistant skill you point at a folder of files, not a library you embed in an app process the way SQLite would be.
2. **The realistic use here is on its document-ingestion side, not its code-parsing side, and it's a periodic offline step, not the live store.** The plan is: the app already needs to write each meeting's coaching review out as a Markdown report (for FR6); once a folder of those per-meeting reports accumulates, Graphify can be run over that folder the same way it's run over a documentation folder, turning mentions of a speaker's participation numbers across many meetings into a queryable, linked graph ("show every mention of Speaker A's interruption count over time"). The numbers the live app actually displays still come from a normal local store (e.g. SQLite) — Graphify sits on top of the exported reports as a secondary, cross-meeting query layer, not a replacement for that store. It's also a genuinely fitting choice thematically, since it's literally invoked as a skill inside the same AI-assisted, `CLAUDE.md`-driven workflow already used to build this project.

**Q38. If the project continued past Week 12, what's the next thing you'd build?**
The Windows port, since the shared-Dart/native-bridge-per-OS architecture was deliberately built to make that additive rather than a rewrite — followed by real longitudinal comparison once enough real meetings exist to make "compared to last time" meaningful.

---

## 12. Hard "Did You Actually Think About This" Questions

**Q39. You call the AI's output "suggestions, not facts" — does the interface actually make that distinction obvious to a user glancing at it mid-meeting, or is that just a disclaimer in the report?**
Fair challenge — this needs to be shown, not just claimed. If the overlay currently renders all insight categories with equal visual weight, that's a gap between the stated design principle and the actual UI, worth checking honestly before the demo rather than assuming it's handled.

**Q40. Your quality targets (15s latency, 75% accuracy, 10% timing accuracy) — did you pick those numbers, or are they backed by anything?**
They were set as reasonable-sounding targets in the charter, not derived from a prior study or pilot measurement — that's normal for a charter written before any data exists, but the honest framing is "these are the targets we're testing against," not "these are proven achievable numbers." Part of the evaluation phase's job is finding out if they were realistic at all.

**Q41. What would make you say this project *shouldn't* have used an LLM at all?**
If simpler, deterministic rules (keyword spotting for questions, a fixed list of action-item trigger phrases) turned out to hit the accuracy targets just as well as Gemini, that would be a stronger, cheaper, more predictable design — and worth saying so if the evaluation data actually shows that, rather than defending the LLM choice for its own sake.

**Q42. What's the one part of this plan you're least confident will work as described?**
The honest answer is diarisation under real, overlapping meeting speech (Q11–Q13) — it's the one place where the underlying research literature itself says this is genuinely hard, not just an engineering task to grind through, and it's the dependency the coaching feature can't function without.

**Q43. You said Graphify is normally run as a code-intelligence tool against source code — isn't it strange to point that at meeting transcripts instead?**
Fair, and worth naming directly rather than dodging: Graphify's core pipeline (tree-sitter AST parsing, extracting relationships like "imports," "calls," "inherits") is built and battle-tested for source code; its "documentation and PDFs" ingestion path is the same tool applied to a looser kind of input, and it's reasonable to expect that side is less mature. The honest plan is to actually test this in Weeks 8–9 — run it against a small folder of real per-meeting Markdown reports and see whether the graph it produces contains anything meaningfully queryable about speakers and metrics. If it doesn't, the fallback costs nothing extra: FR7 only requires that cross-meeting comparison be *possible*, not that Graphify specifically be the mechanism, so a plain SQLite table with a hand-written "compare speaker X across meetings" query satisfies the same requirement.

---

## Quick-Reference: Things to State Proactively (don't wait to be asked)

- Diarisation is not fully wired yet — the data model supports it end-to-end, the Deepgram parameter and label-mapping logic are the remaining work, scoped to the current milestone.
- Screen-share invisibility relies on a documented API (`sharingType = .none`) whose reliability on the very latest macOS (15+) against real meeting apps has not been independently verified yet — it's on the test plan, not assumed.
- API keys are stored unencrypted locally; that's an accepted prototype trade-off, not an oversight.
- Graphify (Graphify-Labs, YC S26) is a real, specific tool for turning codebases *and documents* into a queryable knowledge graph — it has no Dart SDK and isn't called by the app at runtime; the plan is to run it periodically over exported per-meeting Markdown reports, not embed it as the live data store.
- All AI output is a suggestion the user can dismiss, never an autonomous action taken on the user's behalf.

Saying these before being asked reads as engineering maturity. Getting caught not knowing them reads as not having tested your own claims.
