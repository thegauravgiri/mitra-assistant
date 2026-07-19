# Project Rules for AI Agents (Mitra Assistant)

## 🤝 Planning vs Implementation Model Separation
- **Claude Opus (Planning Agent)**: Responsible for codebase research, architectural design, risk assessment, and drafting implementation plans.
- **Gemini / Antigravity (Implementation Agent)**: Responsible for code implementation, Dart/Swift authoring, build execution, test verification, and walkthrough reporting.

## 📁 Shared `.docs/` Artifact Repository Rule
All AI agents **MUST** use the [.docs/](../.docs/README.md) directory to share planning, task, and verification artifacts:
- **Claude Opus** writes planning specs to [.docs/implementation_plan.md](../.docs/implementation_plan.md) and task lists to [.docs/task.md](../.docs/task.md).
- **Gemini / Antigravity** reads [.docs/implementation_plan.md](../.docs/implementation_plan.md), updates [.docs/task.md](../.docs/task.md) during execution, and outputs verification summaries to [.docs/walkthrough.md](../.docs/walkthrough.md).

## 📄 Documentation & README Maintenance Rule
Whenever major structural, architectural, functional, UI/UX, configuration, or dependency changes are made to the codebase, agents **MUST** refer to [docs.md](docs.md) and update [README.md](../README.md) accordingly prior to declaring work complete.

## 🎨 UI/UX & Architecture Design System
For design tokens, typography, window overlay mechanics, and component patterns, agents **MUST** align with [design.md](design.md).
