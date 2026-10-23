# Task Checklist: Meeting graph + coaching overhaul

Legend: `[ ]` todo · `[/]` in progress · `[x]` done. Plan: [implementation_plan.md](implementation_plan.md). Earlier cycles: [archive/](archive/).

- [x] 1. Delivery/listening metrics, indicators, goals (+ tests)
- [x] 2. MeetingDigest model/prompt/parser/backfill (+ tests)
- [x] 3. Coaching narrative + evidence validation + "This is me" + myName/goals settings
- [x] 4. Coaching page rebuild (scorecard, goals, outcomes, sparklines)
- [x] 5. Meeting graph builder + provider + viewer switch/filters + backfill UI
- [x] 6. Live recall in analysis prompt (+ tests)
- [x] 7. Export updates, docs, CLAUDE.md

## Needs a real run (not verifiable headless)
- [ ] Record a two-person clip -> pick "This is me" -> scorecard/coaching/outcomes look right; quotes are real
- [ ] "Build notes for older meetings" on existing history, then Graph -> Meetings
- [ ] Mention an old topic in a new meeting -> "earlier meeting" insight appears
- [ ] Deepgram accepts `filler_words=true` (uh/um show up in transcript); Windows smoke test
