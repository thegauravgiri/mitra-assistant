# Task Checklist: Document Upload for Contextual Insights

Legend: `[ ]` todo · `[/]` in progress · `[x]` done

See [implementation_plan.md](implementation_plan.md) for full detail.

## Phase 1 — Dependencies & Constants
- [x] Add `file_picker`, `syncfusion_flutter_pdf`, `docx_to_text`, `desktop_drop` to `pubspec.yaml`; run `flutter pub get`
- [x] Confirm Syncfusion Community License acceptable (else switch to `read_pdf_text`)
- [x] Add document constants to `lib/core/constants/app_constants.dart` (extensions, max size, chunk size, max context chars, relevance threshold)

## Phase 2 — Shared Tokenizer Refactor
- [x] Create `lib/core/utils/text_similarity.dart` (tokenize, Jaccard, normalize, stop-words)
- [x] Refactor `AiNotifier` (`ai_providers.dart`) to delegate to the util — no dedup behavior change
- [x] Regression: existing dedup tests still pass

## Phase 3 — Documents Module (domain + data)
- [x] `domain/models/uploaded_document.dart` (`UploadedDocument`, `DocumentChunk`, `DocStatus`, `copyWith`)
- [x] `data/document_parser_service.dart` (pick + extract txt/md/pdf/docx, size guard, chunk, keyword-index)
- [x] `data/document_relevance_service.dart` (offline relevance scoring, chunk selection, char budget, pinned handling, active-doc signature)

## Phase 4 — Provider
- [x] `providers/document_providers.dart` (`DocumentState`, `DocumentNotifier`, provider)
- [x] Upload pipeline: parsing -> keyword-index -> summarizing -> ready; error + missing-key handling
- [x] `addDocuments`, `removeDocument`, `togglePin`

## Phase 5 — Gemini / Prompt Integration
- [x] `prompt_templates.dart`: `documentContext` block in analysis + question builders; add `buildDocumentSummaryPrompt`
- [x] `gemini_service.dart`: `documentContext` param on both methods; add `summarizeDocument` (plain-text response)
- [x] `ai_providers.dart`: inject relevant `documentContext` in `analyzeCurrentTranscript` and `askQuestion`; extend change-detection with active-doc signature

## Phase 6 — UI
- [x] Attach (paperclip) `IconButton` in bottom input row of `insight_view.dart`
- [x] `presentation/document_chips_bar.dart` (chips: icon, name, status, pin, remove) above input
- [x] Wrap view body in `desktop_drop` `DropTarget` + drag highlight overlay

## Phase 7 — Tests & Verification
- [x] Unit: parser (txt/md) + chunk boundaries
- [x] Unit: keyword extraction + relevance selection (threshold, char budget, pinned)
- [x] `flutter analyze` clean
- [x] `flutter test` green
- [x] `flutter run -d macos`: off-topic doc sends no tokens; on-topic doc surfaces referencing insights
- [x] Author `.docs/walkthrough.md` (Implementation Agent)
