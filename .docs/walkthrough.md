# Walkthrough: Document Upload for Contextual Insights

**Author:** Gemini / Antigravity (Implementation Agent)  
**Status:** Completed & Verified  

---

## 🎯 Overview

Implemented end-to-end document attachment and contextual insight generation for Mitra Assistant. Users can upload reference documents (PDF, DOCX, TXT, MD) via drag-and-drop or the native file picker prior to or during a live meeting. 

To maximize efficiency and minimize API token cost:
- Uploaded files are parsed, chunked (~500 chars), and keyword-indexed locally in memory.
- A one-shot Gemini summary is generated upon upload.
- An offline, zero-token Jaccard keyword matching engine evaluates recent transcript windows against document keyword indices on every analysis cycle.
- Document summaries and relevant text chunks are injected into Gemini prompts **only when the document topic is actively discussed** (or explicitly pinned).

---

## 🛠️ Key Changes & Architecture

### 1. Shared Utilities & Core
- **`lib/core/utils/text_similarity.dart`**: Extracted stop-words, normalization, tokenization, and Jaccard similarity logic into a shared core utility class used by both `AiNotifier` (for insight deduplication) and `DocumentRelevanceService` (for keyword matching).
- **`lib/core/constants/app_constants.dart`**: Added document configuration constants (`supportedDocumentExtensions`, `maxDocumentSizeBytes`, `documentChunkSize`, `maxDocumentContextChars`, `documentRelevanceThreshold`).

### 2. Documents Feature Module (`lib/features/documents/`)
- **`domain/models/uploaded_document.dart`**: Implemented `UploadedDocument`, `DocumentChunk`, `DocStatus` (`parsing`, `summarizing`, `ready`, `error`), and immutability helpers.
- **`data/document_parser_service.dart`**: Supports native file picker and file paths; parses TXT/MD, PDFs (`syncfusion_flutter_pdf`), and DOCX (`docx_to_text`); enforces 10 MB limit; chunks text on sentence/paragraph boundaries; indexes keywords.
- **`data/document_relevance_service.dart`**: Offline relevance matcher. Scores ready documents against transcript windows, respects pinned documents, ranks top-matching chunks, and enforces the `maxDocumentContextChars` limit.
- **`providers/document_providers.dart`**: Riverpod state management (`DocumentNotifier` & `DocumentState`) handling async file picking, drag-and-drop ingestion, state transitions, summarization pipeline, pin toggling, and document removal.
- **`presentation/document_chips_bar.dart`**: Sleek, glassmorphic horizontal chip bar above chatbox displaying file-type icons, names, loading spinners, pin toggles, and close buttons.

### 3. AI Engine Integration
- **`lib/features/ai_engine/data/prompt_templates.dart`**: Added optional `documentContext` fenced blocks to `buildAnalysisPrompt` and `buildQuestionPrompt`. Added `buildDocumentSummaryPrompt`.
- **`lib/features/ai_engine/data/gemini_service.dart`**: Added `documentContext` parameters to `analyzeTranscript` and `askCopilotQuestion`. Added `summarizeDocument` for plain-text one-shot summarization.
- **`lib/features/ai_engine/providers/ai_providers.dart`**: Updated `analyzeCurrentTranscript` and `askQuestion` to compute and pass relevant document context. Extended change detection with `activeSignature` to re-trigger analysis when relevant document context changes.
- **`lib/features/ai_engine/presentation/insight_view.dart`**: Integrated paperclip attachment button in input bar, embedded `DocumentChipsBar`, and wrapped view in `desktop_drop` `DropTarget` with visual drag overlay.

---

## 🧪 Verification Results

### Automated Unit Tests
Executed `flutter test` across all unit test suites (14 tests passed in total):
- `test/core/utils/text_similarity_test.dart` — Verified tokenization, normalization, and Jaccard similarity.
- `test/features/documents/document_parser_service_test.dart` — Verified file parsing, invalid extension rejection, and boundary chunking.
- `test/features/documents/document_relevance_service_test.dart` — Verified off-topic gating (0 extra tokens), topic matching, pinned doc inclusion, and character budget capping.
- `test/unit_test.dart` & `test/widget_test.dart` — Passed clean.

```bash
00:04 +14: All tests passed!
```

### Static Analysis
Executed `flutter analyze`:
```bash
Analyzing mitra_assistant...
No issues found! (ran in 2.0s)
```

---

## 📄 Documentation Updates
- Updated `.docs/task.md` with complete checklist status.
- Updated `README.md` with the new Contextual Document Upload feature description, stack additions, and feature architecture map.

---

## 🛠️ Fix: Native File Picker Option on macOS

### Bug
Clicking the paperclip upload button did not display the native macOS `NSOpenPanel` file picker dialog.

### Root Cause
`file_picker`'s Swift implementation checks for `com.apple.security.files.user-selected.read-only` or `read-write` entitlements by default via `SecTaskCopyValueForEntitlement`. Because the app runs with app-sandbox disabled (`com.apple.security.app-sandbox = false`), these entitlement keys were missing from binary metadata, causing `checkEntitlement` in `FilePickerPlugin.swift` to fail with `ENTITLEMENT_NOT_FOUND` before opening `NSOpenPanel`.

### Fix
1. Added `await FilePicker.skipEntitlementsChecks()` prior to calling `FilePicker.pickFiles()` in `DocumentParserService.pickAndParseDocuments()`.
2. Added `<key>com.apple.security.files.user-selected.read-only</key><true/>` to `DebugProfile.entitlements` and `Release.entitlements`.

---

## 🛠️ Fix: macOS Gatekeeper Malware Verification Alert

### Bug
When attempting to run or open downloaded builds of **Mitra Assistant**, macOS displays a Gatekeeper security alert:
> *"Apple could not verify “mitra_assistant” is free of malware that may harm your Mac or compromise your privacy."*

### Root Cause
macOS Gatekeeper automatically tags binaries downloaded from web browsers or GitHub Releases with the `com.apple.quarantine` extended file attribute. Un-notarized app binaries (built without an active Apple Developer ID Code Signing & Notarization pipeline) trigger Gatekeeper blocks upon execution.

### Fix
1. Updated [README.md](../README.md) under **⚙️ Initial Configuration & Permissions** with a dedicated **🛡️ macOS Gatekeeper & Unverified Developer Warning** section providing:
   - **Terminal Command Method**: `xattr -d com.apple.quarantine /path/to/mitra_assistant.app`
   - **System Settings Override**: **System Settings > Privacy & Security > Open Anyway**
   - **Local Developer Build**: `flutter run -d macos`
2. Cleaned up legacy merge conflict markers in `README.md` and `CLAUDE.md`.

### Verification
- **Static Analysis**: `flutter analyze` completed with 0 errors/warnings.
- **Automated Tests**: `flutter test` passed 14/14 unit & widget tests.
- **Documentation Verification**: Verified `README.md` and `CLAUDE.md` syntax and formatting.

