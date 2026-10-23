# PROJECT CHARTER

**Project Title:** AI Meeting Communication Coach: A Speaker-Aware Desktop Assistant

**Project Sponsor:** [Supervisor name]

**Date Prepared:** [Insert date]

**Project Manager:** Sneha Neupane (900008705)

**Project Customer:** People who attend regular meetings and want help during the call and feedback after it. The supervisor and assessment panel are the immediate customers.

---

## Executive Summary

This project will build a desktop assistant that sits in a small floating window on top of Zoom, Teams or Meet. It captures microphone and system audio, transcribes the meeting live, and labels who is speaking.

It helps in two ways. During the meeting it shows key points, action items, topic changes, answers to questions just asked, and questions the user could ask next. It also flags questions that were asked but never answered. After the meeting it measures speaking time, turn taking and interruptions, then writes a short review for each speaker with suggestions for next time.

Meeting history is stored in a knowledge base built with Graphify so reviews can be compared over time. The prototype uses Flutter for macOS and Windows, Deepgram for transcription and diarisation, and Gemini for analysis. It runs for fourteen weeks and is done by one student. Work has not started yet.

---

## Project Purpose or Justification

Two things go wrong in meetings. During the call, decisions and action items get lost and questions slide past unanswered. After the call, nobody is told how they took part, so quiet people stay quiet and interruptions go unnoticed.

Current tools only produce transcripts and summaries after the meeting, which is too late to help anyone. None of them measure how well people communicated, even though a speaker labelled transcript already holds that information.

This project covers both gaps in one application: live support while the meeting runs, and personal coaching afterwards. It also gives the student practical work in real time audio, speaker diarisation, LLM integration and cross platform desktop development.

---

## Project Description

A desktop prototype for macOS and Windows, built in Flutter. Audio capture and window control are written natively for each platform, everything else is shared code.

**During the meeting**

1. Capture microphone and system audio together.
2. Live transcription with speaker labels via Deepgram.
3. Live insights from Gemini: key points, action items, topic changes, answers to questions asked.
4. Suggested questions the user could ask next.
5. Alerts when a question goes unanswered.
6. Always on top overlay with compact and expanded modes, hotkeys, and hidden from screen sharing.
7. Optional document upload (agenda, specification) used as context when that topic comes up.

**After the meeting**

8. Speaking time, turn taking and interruption counts per speaker.
9. A short written review for each speaker with one or two suggestions.
10. Results stored in a Graphify knowledge base so measures can be compared across meetings.

**Out of scope:** mobile and web, Linux, video or tone analysis, Zoom or calendar API integration, user accounts or cloud sync, languages other than English.

**Assumptions:** Deepgram diarisation is accurate enough for speaker level analysis; both APIs stay available at the expected cost; consented test meetings can be arranged; a macOS and a Windows machine are available.

---

## Initial Risks

| Id | Risk Statement | Probability | Impact | Strategy | Response |
|---|---|---|---|---|---|
| R1 | Diarisation mislabels speakers on poor or overlapping audio | High | High | Mitigate | Test in Week 5, tune settings, fall back to single speaker mode |
| R2 | Live insights arrive too late to be useful | High | High | Mitigate | Fixed analysis interval, short prompts, measure latency from Week 8 |
| R3 | Gemini output is wrong, invented or badly formatted | Medium | Medium | Mitigate | Structured JSON with fallback parsing, present output as suggestions only |
| R4 | Too many features for fourteen weeks | High | High | Mitigate | Build in priority order, drop progress tracking first |
| R5 | Consent and privacy issues block test recordings | Medium | High | Avoid | Ethics approval first, written consent, local storage, delete after evaluation |
| R6 | Windows audio capture takes longer than planned | Medium | Medium | Mitigate | One shared interface, macOS first, port in Week 7 |

---

## Initial Stakeholders

| Name | Interest | Impact | Strategies |
|---|---|---|---|
| Sneha Neupane (Student) | Grade, deadlines, learning | High | Owns all work, weekly progress log |
| Supervisor | Academic quality, feasible scope | High | Fortnightly meetings, agree scope changes in writing |
| Assessment panel | Fair marking of report and demo | High | Work mapped to marking criteria, demo rehearsed |
| Test participants | Consent and data handling | Medium | Written consent, local storage, deleted after evaluation |
| Deepgram and Google | Proper use of their APIs | Low | Stay within limits, keep keys out of the repository |
| University ethics process | Data protection compliance | Medium | Ethics approval before any recording |

---

## Project Deliverables

- Requirements and review of existing tools
- Architecture and interface design
- Overlay prototype with audio capture, transcription and diarisation (macOS and Windows)
- Live insight engine and unanswered question alerts
- Document upload with local relevance matching
- Participation and interruption analysis
- Per speaker review and feedback
- Graphify knowledge base with progress tracking
- Annotated test meetings and evaluation results
- Final report and demonstration

| Summary Milestones | Due Date |
|---|---|
| Requirements complete | End of Week 2 |
| Design signed off | End of Week 4 |
| Overlay, capture, transcription, diarisation working | End of Week 7 |
| Live insights and unanswered questions complete | End of Week 9 |
| Participation and interruption analysis complete | End of Week 10 |
| Per speaker review and progress tracking complete | End of Week 12 |
| Evaluation complete | End of Week 13 |
| Report and demonstration delivered | End of Week 14 |

---

## Summary Budget and Feasibility

Hardware and development tools are already available and free. The only direct cost is API usage.

| Item | Cost (AUD) |
|---|---|
| Deepgram transcription and diarisation | 60 to 120 |
| Gemini analysis and feedback | 40 to 80 |
| Hardware and tools | 0 |
| **Total** | **100 to 200** |

The project is feasible because both APIs provide ready streaming and analysis endpoints, so the work is integration and analysis logic rather than model building. The main concern is the number of features, handled by the priority order in R4.

---

## Project Objectives and Success Criteria

**Scope:** A working prototype on macOS and Windows that gives live insights during a meeting and per speaker reviews afterwards, with results stored for comparison across meetings. Both sides must be demonstrable on real test meetings.

**Time:** All milestones met within one week of plan, report and demo submitted by the module deadline.

**Cost:** Total spend stays within AUD 200.

**Quality:**
- Live insights appear within 15 seconds of the relevant point in the conversation.
- Unanswered question detection at least 75 percent accurate against annotated test meetings.
- Speaking time per speaker within 10 percent of manual measurement.
- Runs a 30 minute meeting without crashing on both platforms.

**Other:** Written consent from every participant, recordings deleted after evaluation, and at least five users rate the insights and feedback as understandable and useful.

---

## Acceptance Criteria

1. Runs end to end on macOS and Windows with a live speaker labelled transcript.
2. Shows live insights, suggested questions and unanswered question alerts during a meeting.
3. Produces participation figures and a written review for each speaker afterwards.
4. Compares one speaker's measures across two or more meetings.
5. Evaluation results documented against the quality targets.
6. Report submitted by the deadline and accepted by the supervisor.

---

## Project Approval and Manager

**Project Approval Requirements:** Approved when the supervisor accepts this charter and the scope. Final approval rests with the supervisor and assessment panel against the acceptance criteria and marking scheme. Scope, deliverable or schedule changes must be agreed with the supervisor in writing.

**Project Manager:** Sneha Neupane (900008705), responsible for all planning, development, testing, documentation and reporting, and for raising problems with the supervisor early.

---

## Approvals

| | |
|---|---|
| Project Manager Signature | Sponsor or Originator Signature |
| | |
| Project Manager Name: Sneha Neupane | Sponsor or Originator Name: |
| | |
| Date: | Date: |
