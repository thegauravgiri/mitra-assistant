# 📁 Shared Artifacts Directory (`.docs/`)

This directory serves as the **shared artifact repository and communication bridge** between **Claude Opus** (Planning Agent) and **Gemini / Antigravity** (Implementation Agent).

---

## 🔄 Workflow & Responsibilities

```
[Claude Opus (Planning)] ──────► Writes Plan & Tasks to .docs/
                                         │
                                         ▼
[Gemini (Antigravity)]   ◄────── Reads .docs/ & Executes Code
                         ──────► Updates .docs/task.md & .docs/walkthrough.md
```

### 🧠 1. Planning (Claude Opus)
- Conducts architectural research, codebase analysis, and trade-off evaluations.
- Authors technical implementation plans in [.docs/implementation_plan.md](implementation_plan.md).
- Generates itemized task checklists in [.docs/task.md](task.md).
- Does **not** modify production code directly.

### ⚡ 2. Implementation & Execution (Gemini / Antigravity)
- Reads [.docs/implementation_plan.md](implementation_plan.md) and [.docs/task.md](task.md).
- Executes feature code changes in `lib/` and `macos/Runner/Services/`.
- Updates task completion status in [.docs/task.md](task.md).
- Runs verification (`flutter analyze`, `flutter test`, `flutter run -d macos`).
- Generates final verification reports and walkthroughs in [.docs/walkthrough.md](walkthrough.md).

---

## 📜 Key Shared Artifacts

| Artifact File | Author | Purpose |
| :--- | :--- | :--- |
| **[.docs/implementation_plan.md](implementation_plan.md)** | Claude Opus | Architectural design, file modification plan, risk assessment, open questions. |
| **[.docs/task.md](task.md)** | Claude Opus / Gemini | Task checklist (`[ ]`, `[/]`, `[x]`) to track implementation progress. |
| **[.docs/walkthrough.md](walkthrough.md)** | Gemini | Post-implementation execution summary, verification test output, and screenshots/notes. |

---

## 🎓 Academic Coursework Artifacts (branch `academic-coursework`)

Separate from the engineering workflow above. Start with [memory.md](memory.md) for full context (persona, timeline, honesty decisions, Windows-support update).

```
.docs/
├── README.md, implementation_plan.md, task.md, walkthrough.md   # engineering workflow
├── memory.md                                                    # academic session handoff
└── academic/
    ├── charter/             # Assessment 1 — PROJECT_CHARTER.md, .docx, .pdf
    ├── literature-review/   # Assessment 2
    │   ├── final/           #   draft .md, .docx/.pdf, references.md, figures/
    │   ├── extracted/       #   text extracted from brief, charter, senior example
    │   └── sources/         #   brief & example PDFs
    ├── project-plan/        # Assessment 3
    │   ├── final/           #   project-plan-draft.md, project-plan.docx
    │   └── sources/         #   brief & example PDFs
    ├── presentation/        # presentation.pptx
    └── viva/                # question_answer.md (defence prep, not graded)
```
