# Implementation Plan: Document Upload for Contextual Insights

**Author:** Claude Opus (Planning Agent)
**Status:** Ready for implementation
**Target feature area:** AI Copilot Chat Section (`lib/features/ai_engine/`) + new `lib/features/documents/` module

---

## 1. Objective

Let the user upload documents (before or during a meeting) that the AI Copilot uses as
additional context when generating insights. The AI must pull extra detail from a document
**only when the ongoing conversation is actually talking about it** — never reprocessing every
document on every analysis cycle.

## 2. Locked Decisions

| Decision | Choice |
| :--- | :--- |
| Supported formats | **TXT / MD + PDF + DOCX** |
| Persistence | **Session-only** (in-memory; no disk copy) |
| Relevance gate | **Local keyword match** — zero tokens until a doc is discussed |
| Injection payload | **One-time summary (single Gemini call at upload) + best-matching chunks when relevant** |

## 3. Core Mechanism (token budget)

A document is parsed and keyword-indexed **once** at upload. On each analysis cycle a
**zero-cost local keyword match** compares the recent transcript window against each doc's
keyword index. A document's content enters the Gemini prompt **only** when it clears a
relevance threshold, and then only as its short summary + top-matching chunks (capped by a
char budget) — never the full file.

```
Upload once:  file -> extract text -> chunk + keyword-index -> 1 Gemini summarize call -> READY
Every cycle:  transcript window --local keyword match--> relevant docs?
                 no  -> send transcript only (no extra tokens)
                 yes -> append [summary + top chunks, <= ~1500 chars] to prompt
```

## 4. New Dependencies (`pubspec.yaml`)

- `file_picker` — file selection dialog
- `syncfusion_flutter_pdf` — PDF text extraction (pure Dart, macOS-compatible)
- `docx_to_text` — DOCX -> plain text
- `desktop_drop` — drag-and-drop files onto the chatbox area

> **RISK:** `syncfusion_flutter_pdf` is free under Syncfusion's Community License but requires a
> license for commercial use above their revenue threshold. Fallback: `read_pdf_text`.
> Confirm licensing acceptability before wiring in.

> **No macOS entitlement changes required** — the app sandbox is currently **disabled**
> (`com.apple.security.app-sandbox = false` in both `DebugProfile.entitlements` and
> `Release.entitlements`), so `file_picker` has file access. If sandboxing is ever enabled,
> add `com.apple.security.files.user-selected.read-only`.

## 5. New Module: `lib/features/documents/`

Follows the repo's feature-first layering (`data/`, `domain/models/`, `providers/`, `presentation/`).

### `domain/models/uploaded_document.dart`
```dart
enum DocStatus { parsing, summarizing, ready, error }

class UploadedDocument {
  final String id;               // Uuid v4
  final String fileName;
  final String fileType;         // 'txt' | 'md' | 'pdf' | 'docx'
  final String fullText;
  final List<DocumentChunk> chunks;
  final Set<String> keywords;    // document-level keyword index
  final String? summary;         // one-time Gemini summary (nullable if key missing)
  final int charCount;
  final DocStatus status;
  final bool isPinned;           // force-include summary regardless of match
  final DateTime uploadedAt;
  final String? error;
  // + copyWith
}

class DocumentChunk {
  final String text;             // ~500 chars, split on sentence/paragraph boundary
  final Set<String> keywords;    // precomputed for cheap matching
}
```

### `data/document_parser_service.dart`
- Picks files via `file_picker` with `withData: true` (also accepts dropped file paths from `desktop_drop`).
- Routes by extension:
  - `txt` / `md` -> decode bytes as UTF-8.
  - `pdf` -> `syncfusion_flutter_pdf` `PdfTextExtractor`.
  - `docx` -> `docx_to_text`.
- Enforces `maxDocumentSizeBytes`.
- Splits extracted text into `documentChunkSize` (~500) char chunks on sentence/paragraph
  boundaries; computes per-chunk and document-level keyword sets via the shared tokenizer.

### `data/document_relevance_service.dart`
Pure, offline, unit-testable. No network.
- Input: recent transcript window (+ optional question text) and the list of READY docs.
- Scores each doc by keyword overlap (shared tokenizer) against the window.
- Returns docs clearing `documentRelevanceThreshold`, plus their top-N matching chunks
  assembled within `maxDocumentContextChars`.
- Pinned docs always contribute their summary (small) even without a match.
- Produces the assembled `documentContext` string + an active-doc signature (for change detection).

### `providers/document_providers.dart`
```dart
class DocumentState {
  final List<UploadedDocument> documents;
  final bool isProcessing;
  // + copyWith
}

class DocumentNotifier extends StateNotifier<DocumentState> {
  // addDocuments(...)  -> pipeline: parsing -> keyword-index -> summarizing -> ready
  // removeDocument(id)
  // togglePin(id)
}
final documentNotifierProvider = StateNotifierProvider<DocumentNotifier, DocumentState>(...);
```
Upload pipeline per file: create doc `status: parsing` -> extract text -> chunk + keyword-index
(instant, local) -> `status: summarizing` -> one `GeminiService.summarizeDocument` call ->
`status: ready`. Missing Gemini key -> skip summary, still reach `ready`. Parse failure ->
`status: error` with message.

### `presentation/document_chips_bar.dart`
Horizontal strip of chips shown above the input row: file-type icon, name, status
(spinner / check / error), pin toggle, remove (x). Optional subtle "active now" marker when a
doc is being injected in the current cycle.

## 6. Shared Refactor: `lib/core/utils/text_similarity.dart`

Extract the tokenizer / stop-words / Jaccard helpers currently **private** in `AiNotifier`
(`ai_providers.dart:181-199` — `_tokenize`, `_calculateJaccardSimilarity`, `_normalize`,
`_stopWords`) into one reusable module. Used by both the existing dedup logic and the new
relevance scoring. **No behavior change** to dedup — `AiNotifier` delegates to the util.

## 7. Modifications to Existing Files

### `lib/features/ai_engine/data/prompt_templates.dart`
- Add optional `documentContext` param to `buildAnalysisPrompt` and `buildQuestionPrompt`,
  rendering a fenced `Reference Documents:` block only when non-empty.
- Add `buildDocumentSummaryPrompt(String text)` for the one-time upload summary.

### `lib/features/ai_engine/data/gemini_service.dart`
- Add optional `String documentContext = ''` to `analyzeTranscript` and `askCopilotQuestion`;
  pass through to the prompt builders.
- Add `Future<String> summarizeDocument({required String apiKey, required String text})` —
  one-shot, **plain-text** response (bypass the JSON `responseMimeType`, e.g. a separate model
  instance or per-call config), 2-3 sentence summary.

### `lib/features/ai_engine/providers/ai_providers.dart`
- `analyzeCurrentTranscript`: after computing `transcriptSlice`, call the relevance service
  against the window; pass resulting `documentContext` to `analyzeTranscript`.
- `askQuestion`: run relevance against **transcript + question text** (so "summarize the doc I
  uploaded" pulls it in); pass context to `askCopilotQuestion`.
- Extend change-detection: combine `_lastAnalyzedTranscript` with an active-doc signature so a
  newly-relevant doc can re-trigger analysis even if transcript text is unchanged.
- Replace private tokenizer usage with `text_similarity.dart`.

### `lib/features/ai_engine/presentation/insight_view.dart`
- Add a paperclip **attach** `IconButton` to the bottom input row (`insight_view.dart:467-497`)
  that invokes the picker.
- Render `DocumentChipsBar` directly above that row.
- Wrap the view body in a `DropTarget` (desktop_drop); on drop of supported file types call
  `addDocuments`; show a highlight overlay while dragging.

### `lib/core/constants/app_constants.dart`
Add: `supportedDocumentExtensions`, `maxDocumentSizeBytes`, `documentChunkSize`,
`maxDocumentContextChars` (~1500), `documentRelevanceThreshold`.

## 8. Behavior Details

- **Upload any time:** `DocumentNotifier` is independent of meeting state; parse/summarize runs
  on upload whether or not a meeting is active.
- **Pinning:** a pinned doc always injects its (small) summary — for uploading a file mid-call
  to discuss it before its keywords appear in the transcript.
- **Graceful degradation:** no Gemini key -> parse + keyword-match still work, summary skipped
  (chunks inject when relevant); parse failure -> chip shows error, doc excluded from context.

## 9. Tests (`test/`)

- Parser: txt/md extraction + chunk-boundary correctness.
- Keyword extraction + relevance selection: deterministic/offline — threshold gating,
  char-budget capping, pinned-doc inclusion.
- Regression: dedup still passes after the tokenizer refactor.

## 10. Verification

`flutter analyze` -> `flutter test` -> `flutter run -d macos`. Upload a doc before a meeting,
confirm it is ignored while the conversation is off-topic (no doc tokens sent), then speak about
its content and confirm insights referencing it appear.

## 11. Open Questions / Risks

1. Syncfusion PDF licensing (see §4) — confirm acceptable or switch to `read_pdf_text`.
2. DOCX parsing edge cases (tables, images) — text-only extraction is acceptable for v1.
3. Relevance threshold tuning — start conservative; expose as a constant for iteration.
