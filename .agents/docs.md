# 📄 Agent Documentation & Repository Maintenance Guide (`docs.md`)

**Mitra Assistant** — Guidelines for AI Coding Agents on Documentation Synchronization

---

## 🎯 Purpose & Primary Directive

This document defines mandatory guidelines for AI agents operating within the **Mitra Assistant** codebase.

> [!IMPORTANT]
> **PRIMARY DIRECTIVE**: Whenever major structural, architectural, functional, UI/UX, configuration, or dependency changes are made to the repository, the agent **MUST** review and update [README.md](../README.md) and any relevant specification documents (e.g., [design.md](design.md)) before declaring the task complete or submitting git commits/pull requests.

---

## 📁 Shared `.docs/` Artifact Repository

All AI model agents share artifacts via the **[.docs/](../.docs/README.md)** folder:
1. **Claude Opus (Planning)** drafts technical implementation plans to **[.docs/implementation_plan.md](../.docs/implementation_plan.md)** and tasks to **[.docs/task.md](../.docs/task.md)**.
2. **Gemini / Antigravity (Implementation)** reads the plans, executes the changes, updates **[.docs/task.md](../.docs/task.md)**, and records execution results in **[.docs/walkthrough.md](../.docs/walkthrough.md)**.

---

## ⚡ What Constitutes a "Major Change"?

An agent must consider any of the following occurrences as a **Major Change** requiring immediate updates to project documentation:

### 1. 🏗️ Architecture & Engine Refactoring
- Changes to state management architecture (e.g., Riverpod providers, notifier structures).
- Modifications to core engines (e.g., Deepgram STT engine, Gemini AI Context Engine, sliding transcript windows).
- Introduction of new data pipelines or algorithms (e.g., multi-pass Jaccard semantic deduplication, text normalization, capacity caps).
- Updates to native macOS Swift platform channels (e.g., `WindowControlService`, native window sharing protection, loopback audio capture).

### 2. 🎨 UI/UX & Design System Overhauls
- Introduction of new design tokens, color palettes, glassmorphic styling components (`GlassContainer`), or typography systems (`AppTextStyles`).
- Redesigns of core app views, window layouts, or overlay behaviors (e.g., Compact Pill Mode vs. Expanded Shell).
- Addition of new interactive components (e.g., search/category filtering bars, animated audio pulse indicators, tab navigation).

### 3. 🚀 New Feature Additions
- New user-facing capabilities (e.g., Meeting History view, CSV export functionality, question prompting, dark glass theme toggles).
- New global hotkeys, panic hide shortcuts, or tray controls.

### 4. 📁 Project Structure & Dependency Changes
- Addition or removal of third-party packages in `pubspec.yaml`.
- Addition, deletion, or reorganization of core feature modules under `lib/` or guidelines under `.agents/`.
- Updates to target Flutter SDK version, macOS deployment targets, or Xcode requirements.

### 5. ⚙️ Configuration & Environment Requirements
- Changes to required API keys (Deepgram, Gemini) or app settings storage.
- Updates to required macOS system permissions (Microphone, Screen Recording, System Audio Capture).

---

## 📝 README.md Maintenance Checklist for Agents

<<<<<<< HEAD
When a major change is made, the agent **MUST** perform a section-by-section audit of [README.md](../README.md) using the following checklist:
=======
When a major change is made, the agent **MUST** perform a section-by-section audit of [README.md](file:///Users/gauravgiri/Developer/proshore/mitra_assistant/README.md) using the following checklist:
>>>>>>> 06159ce (agent: add docs.md to instruct agent to update docs upon major changes)

| Section in `README.md` | Audit & Update Actions |
| :--- | :--- |
| **`## ✨ Key Features`** | • Add new capabilities with clear concise bullet points and icons.<br>• Update descriptions of modified/redesigned features (e.g., deduplication, history export). |
| **`## 🛠️ Technology Stack`** | • Update the tech stack table if dependencies, packages, algorithms, or native layers change. |
| **`## 📁 Project Architecture`** | • Update the visual directory tree map if files/directories under `lib/` or `.agents/` are modified. |
| **`## 📋 Prerequisites`** | • Update SDK versions, Xcode requirements, or external API requirements if changed. |
| **`## 🚀 Getting Started`** | • Update installation or execution commands if build steps change. |
| **`## ⚙️ Initial Configuration`** | • Update permission details, API setup steps, or setting preferences if altered. |
| **`## 🛡️ Privacy & Security`** | • Update security/privacy descriptions if native protection mechanisms change. |

---

## 🔄 Agent Execution & Verification Workflow

Agents should follow this step-by-step workflow during any task involving major changes:

```
[1. Code Implementation & Bug Fixes]
                 │
                 ▼
[2. Execution & Automated Testing]
  (Ensure code compiles clean and tests pass)
                 │
                 ▼
[3. Major Change Assessment]
  Did this change touch features, architecture, UI, dependencies, or configuration?
                 ├─────── YES ───────► Update README.md & .agents/ documentation
                 └─────── NO  ───────► Skip doc updates
                 │
                 ▼
[4. Final Verification & Clean Completion]
```

---

## 📏 Documentation Quality Standards for Agents

- **Keep Documentation Synchronized**: Never leave code changes and documentation in a divergent state.
- **Clear Markdown Formatting**: Use structured headings, GitHub alerts (`[!NOTE]`, `[!IMPORTANT]`), concise bullet points, and syntax-highlighted code blocks.
<<<<<<< HEAD
- **Accurate File References**: When referencing source code, use Markdown file links (e.g., [design.md](design.md)).
=======
- **Accurate File References**: When referencing source code, use Markdown file links (e.g., [design.md](file:///Users/gauravgiri/Developer/proshore/mitra_assistant/.agents/design.md)).
>>>>>>> 06159ce (agent: add docs.md to instruct agent to update docs upon major changes)
- **Concise Summaries**: Avoid fluff; focus on technical clarity, setup accuracy, and developer ergonomics.
