# Memory: Academic Coursework Branch

**Read this first if you are a fresh Claude Code session with no prior conversation history.** This branch (`academic-coursework`) exists specifically to continue unfinished work from a previous conversation, on a different machine. Everything below is context that conversation had but this one doesn't yet.

## What this branch is for

The `mitra-assistant` repository is a real Flutter desktop app (see root `CLAUDE.md` for its actual architecture). Separately, the repo's owner is using this exact app as the subject of a university assignment: a TAFE NSW Higher Education unit (**ITNET312A Major Individual Project**) requires designing, planning and documenting a solo software project. Rather than invent a fake project, the student is documenting *this real app* as if it were being built from scratch for the assignment, under a different authorial persona (see below).

Those two things — the real app's development, and the academic paperwork describing a fictionalised version of its development — are deliberately kept apart. `main` carries the real app and its own `.docs/task.md` / `.docs/walkthrough.md` workflow (used by other collaborators — do not touch those). This branch carries only the academic submission artifacts, under `.docs/`, so they don't clutter `main` for other contributors.

## The academic persona (important — do not break character across documents)

All submitted documents are authored as:
- **Candidate:** Sneha Neupane (Student ID: 900008705)
- **Unit:** ITNET312A Major Individual Project
- **Institution:** TAFE NSW Higher Education
- **Project title used throughout:** "AI Meeting Communication Coach: A Speaker-Aware Desktop Assistant" (the academic name for what the codebase calls Mitra Assistant)
- **Referencing style:** APA 7th edition

The assignment has (at least) three graded assessments, submitted in sequence, each building on the last:
1. **Assessment 1 — Project Charter** (already done, not produced in this branch — see `.docs/academic/charter/Project Charter.docx.pdf`, used as source material).
2. **Assessment 2 — Literature Review** (20%, Week 6 submission). Already completed. Output: `.docs/academic/literature-review/final/literature-review-sneha.docx` (+ `.pdf`), built from `.docs/academic/literature-review/final/literature-review-draft.md` via `build_clean_docx.py`. Declares **Level 2: AI-Assisted Editing** in its own Gen AI appendix.
3. **Assessment 3 — Project Plan / Early-Stage Presentation** (15% report + 5% presentation, Week 8 submission). This is what most of the branch's work is about. Output: `.docs/academic/project-plan/final/project-plan.docx` (+ source `.md`), built via `build_project_plan_docx.py`. A presentation deck also exists: `.docs/academic/presentation/presentation.pptx` (+ a `.pdf` export for quick reading).

A fourth artifact, **`.docs/academic/viva/question_answer.md`**, is not a graded deliverable — it's defence-prep Q&A for the oral presentation/viva, written in first person for the student to rehearse with.

## Narrative timeline used across the documents (don't contradict this)

The charter states it was prepared **16/08/2026**, for a **12-week** solo project. All "current progress" framing in the project plan and presentation is pinned to **end of Week 4 / start of Week 5** (i.e. written as if submitted in mid-September 2026), matching the Week 5 milestone in the charter ("overlay, capture, transcription, diarisation working"). **When continuing this work, recompute which week "today" falls in** from 16/08/2026 + 12 weeks, rather than assuming Week 4/5 still applies — the real calendar date has moved on since these documents were written.

## Key factual honesty decisions already made — carry these forward

When writing the project plan and Q&A, the actual codebase was checked against what the charter/plan *claim*, on the principle that the academic documents should only claim what's actually true or plausibly true for the elapsed time, even though a fictional persona is writing them. Several gaps were found and written up **honestly as "in progress" or flagged as caveats**, not hidden:

1. **Diarisation (speaker labelling) was not actually wired up** as of the project-plan/Q&A writing: `lib/features/transcription/data/deepgram_service.dart` did not pass `diarize=true` to Deepgram, and `TranscriptEntry.speaker` defaulted to a hardcoded placeholder. Framed in the documents as "Week 5 milestone, actively being tuned," which is defensible but **re-check the current code before claiming this is finished** — it may have been completed since.
2. **Screen-share masking reliability on macOS 15+ is genuinely uncertain.** `NSWindow.sharingType = .none` (used in `WindowControlService.swift`) is reported by developers to no longer reliably exclude a window from `ScreenCaptureKit`-based capture on macOS 15 Sequoia and later. This is written up as a known risk to verify by testing, not assumed solved.
3. **API keys are stored in plaintext** via `shared_preferences` (not the OS keychain) — written up as an accepted prototype trade-off, not hidden as if it were secure.
4. **"Graphify"** (named in the charter as the planned cross-meeting knowledge base) is the **real** open-source tool at <https://github.com/Graphify-Labs/graphify> (Graphify-Labs, YC S26 batch, ~117k GitHub stars) — a Python CLI that turns a **codebase or documentation folder** into a queryable knowledge graph (tree-sitter AST parsing, Leiden clustering), normally invoked as `/graphify .` inside an AI coding assistant. It has **no Dart SDK** and is not something the Flutter app calls at runtime. The documents' honest position: run it periodically over exported per-meeting Markdown coaching reports (treating them as a "documentation folder"), as a secondary cross-meeting query layer — with a plain SQLite fallback if that doesn't pan out in testing (Weeks 8–9). Do not describe Graphify as an embedded app database.

## ⚠️ Major update since these documents were last written: Windows support is now real

The project charter/plan originally framed Windows as **future work** ("macOS first, Windows port in Week 9," risk R4). **This is now out of date.** A pull from `origin/main` on 2026-10-19 brought in commit `9799b12` ("feat(windows): add native Windows desktop support and audio/stealth channels", PR #7, by a collaborator — not the academic persona) which actually implements:
- WASAPI microphone + system-audio loopback capture (`windows/runner/audio_capture_channel.cpp`)
- Windows screen-share stealth via `SetWindowDisplayAffinity(WDA_EXCLUDEFROMCAPTURE)` (`windows/runner/window_control_channel.cpp`)
- Cross-platform hotkeys (Ctrl+Shift+H on Windows)

Root `CLAUDE.md` has already been updated upstream to describe the app as supporting **both macOS and Windows** natively.

**This directly affects academic documents that still say "macOS only" or "Windows planned for later":**
- `.docs/academic/project-plan/final/project-plan.docx` — describes Windows as not-yet-started, future Week 9 work.
- `.docs/academic/viva/question_answer.md` — several answers (e.g. about scope, architecture, "what's next") frame Windows as unbuilt.
- `.docs/academic/presentation/presentation.pptx` — multiple slides say "macOS desktop overlay" / "A demonstrable macOS prototype," and the 12-week delivery table has no Windows-port line item at all. A detailed refinement prompt was already written for this (see "Presentation review" below) and **may or may not have been applied yet** — check the current `.docs/academic/presentation/presentation.pptx` content before assuming it's fixed.

**If asked to update these documents next, the honest framing is no longer "Windows is planned" but "Windows support was delivered" — figure out which week that actually landed in relative to the charter's 16/08/2026 start date, and update the timeline/status language accordingly** rather than just swapping "planned" for "done" everywhere blindly.

## Presentation review (`.docs/academic/presentation/presentation.pptx`) — status as of last session

The 13-slide deck was reviewed slide-by-slide (converted to PDF with `soffice --headless --convert-to pdf` to read it, since there's no direct pptx viewer). Findings, in case they still need fixing:
- Slide 13 said "A demonstrable **macOS** prototype" as the final deliverable — contradicts the charter's acceptance criteria (both macOS and Windows).
- Slide 8 (12-week delivery table) had no Windows-port row at all.
- Slide 12 (resources) only listed a Mac as owned hardware, no Windows machine.
- Slide 10 (risks) already had the *correct* macOS-first-then-Windows framing — it was the rest of the deck that was out of sync with it.
- A full refinement prompt covering all of this was handed to the user to paste into whichever tool/chat produced the `.pptx` (not produced via python-pptx in this repo — there's no generator script for it, unlike the `.docx` files). **Re-check the current deck content before re-doing this work** — it may already be fixed, and now there's the added wrinkle that Windows isn't just "scoped for later" anymore, it's actually shipped.

## How the `.docx` files are built (so you can regenerate them after edits)

Both Word documents are generated from Markdown by bespoke Python scripts at the repo root (python-pptx/python-docx aren't installed system-wide — there's no system `pip`; a venv was created ad hoc in the scratchpad directory each session: `python3 -m venv <scratchpad>/venv && source <venv>/bin/activate && pip install python-docx`):
- `build_clean_docx.py` → reads `.docs/academic/literature-review/final/literature-review-draft.md` → writes `.docs/academic/literature-review/final/literature-review-sneha.docx`.
- `build_project_plan_docx.py` → reads `.docs/academic/project-plan/final/project-plan-draft.md` → writes `.docs/academic/project-plan/final/project-plan.docx`.
- `build_academic_docx.py` is an earlier/alternate version of the literature-review builder — kept for reference, not actively used.
- Both scripts share the same visual style: Calibri body, navy (`#1E3A8A`) headings, teal (`#0F766E`) subheadings, a two-column metadata table under the title, page header reading "ITNET312A Major Individual Project | <Assessment Name>", footer "Sneha Neupane (900008705) • TAFE NSW Higher Education". **If you add a third document, match this style rather than inventing a new one.**
- **Known gotcha already fixed once:** the markdown-to-docx parsing loop must flush any pending table *before* processing the next heading line, not only before the next plain-text line — otherwise consecutive tables under back-to-back headings silently merge into one garbled table. Both current scripts handle this correctly; preserve that ordering if you touch the parsing loop.
- To proofread a generated `.docx`/`.pptx` visually: `soffice --headless --convert-to pdf <file>` then read the PDF with the `pages` parameter (these files are usually >1 page, which the PDF reader tool requires a page range for).

## Working style notes for this persona's documents

- Write in plain, direct prose — avoid "AI-sounding" filler (no "furthermore," "moreover," generic hedging). The user explicitly asked for writing that doesn't read as AI-generated, and for facts to be checked, not assumed.
- Prefer stating a real limitation honestly (framed as "here's what I'm already tracking") over oversell — this reads as more credible to an academic panel, not less, and was explicitly requested.
- When a technical or cost claim is used in these documents, it was verified by either reading the actual source code in this repo, or a live web search (not recalled from training knowledge) — e.g. Deepgram/Gemini pricing, macOS ScreenCaptureKit behaviour changes, Australian recording-consent law. **Keep doing this** — don't assert a specific number or API behaviour without checking it's still current.
- Do not silently invent a Generative AI Declaration/appendix on the student's behalf (what AI level was used, which tool) — that's the student's own integrity statement to make; flag that it's missing/needed rather than fabricating specifics for them.

## Suggested next steps (if the user doesn't say otherwise)

1. Re-check whether `.docs/academic/presentation/presentation.pptx` still needs the macOS/Windows fixes described above, and whether it needs *further* updating now that Windows is actually built (not just scoped).
2. Re-check `.docs/academic/project-plan/final/project-plan-draft.md` and `.docs/academic/viva/question_answer.md` for the same now-outdated "Windows is future work" framing, and update both the status language and the current week number against the 16/08/2026 start date.
3. Re-verify the diarisation status (caveat #1 above) against the current `deepgram_service.dart` before repeating that caveat as still-true.
