# 🎙️ Mitra Assistant

**Mitra Assistant** is a privacy-focused, real-time AI meeting assistant overlay app built with Flutter and native desktop channels. It sits as a sleek, non-intrusive floating window on top of meeting applications (such as Google Meet, Zoom, and Microsoft Teams) to provide live speech transcription and continuous AI-powered meeting insights.

---

## ✨ Key Features

- 🖥️ **Smart Overlay Window**
  - **Compact & Expanded Modes**: Switch seamlessly between a minimal floating badge and a detailed workspace.
  - **Always-on-Top & Global Hotkeys**: Stay productive without losing window focus during meetings.
  - 🛡️ **Screenshare Protection**: Utilizes macOS `NSWindow.sharingType` native window configuration so your assistant overlay remains strictly invisible to attendees during screen sharing.

- 🎙️ **Real-Time Live Transcription**
  - **Dual Audio Capture**: Captures both microphone input and system audio (team/client audio) via native macOS audio loopback services.
  - **Streaming Speech-to-Text**: Low-latency transcription powered by the Deepgram WebSocket API.

- 💡 **AI Context Engine**
  - **Continuous Analysis**: Powered by Google Gemini (`google_generative_ai`) operating over a rolling transcript buffer.
  - **Actionable Insights**: Automatically extracts key meeting summaries, action items, topic switches, and direct answers to questions asked during discussion.

- 📄 **Contextual Document Upload**
  - **Multi-Format Support**: Upload TXT, MD, PDF, and DOCX files directly via drag-and-drop or file picker before or during meetings.
  - **Zero-Token Local Keyword Matching**: Parsed document content is keyword-indexed locally and injected into Gemini context only when relevant topics are actively discussed in the meeting transcript.
  - **Session-Only Memory**: Uploaded documents are kept in session memory with one-time AI summaries and pinning controls.

- ⚙️ **Customization & Controls**
  - Configure Deepgram and Gemini API keys directly in app settings.
  - Adjust AI analysis frequency intervals (default: 12 seconds).
  - Select active audio input devices and toggle system audio capture.

---

## 🛠️ Technology Stack

| Layer | Technology |
| :--- | :--- |
| **UI Framework** | [Flutter](https://flutter.dev) (Desktop / macOS target) |
| **State Management** | [Riverpod](https://riverpod.dev) (`flutter_riverpod`) |
| **Window & Hotkey Control** | `window_manager` & `hotkey_manager` |
| **Live Speech-to-Text** | Deepgram WebSocket SDK (`deepgram_speech_to_text`) |
| **AI Context Engine** | Google Gemini SDK (`google_generative_ai`) |
| **Document Processing** | `file_picker`, `syncfusion_flutter_pdf`, `docx_to_text`, `desktop_drop` |
| **Native Integration** | Swift Platform Channels (macOS Audio Capture & `NSWindow` Privacy) |
| **Persistence** | `shared_preferences` |

---

## 📁 Project Architecture

The project follows Clean Architecture principles organized by feature layers:

```
<<<<<<< HEAD
<<<<<<< HEAD
.docs/                   # Planning, task lists, and walkthrough specs
=======
=======
>>>>>>> 032322b153bab131210054e25480d3271f0a296f
.claude/
└── agents/              # Claude Code agent configurations
    ├── planning.md      # Planning Agent (Opus 4.8 Thinking Medium)
    ├── implementation.md# Implementation Agent (Sonnet Medium)
    ├── testing.md       # Testing Agent (Haiku)
    └── document.md      # Document Agent (Haiku)
<<<<<<< HEAD
>>>>>>> 2f7adb2 (agent: add claude agents for plan, implement, test, document)
=======
>>>>>>> 032322b153bab131210054e25480d3271f0a296f
lib/
├── core/
│   ├── constants/       # Global constants & channel identifiers
│   ├── theme/           # App dark theme & design tokens
│   └── utils/           # Logger, TextSimilarity & helper utilities
├── features/
│   ├── ai_engine/       # Gemini service, prompt templates & insights UI
│   ├── audio/           # Native audio capture service & device management
│   ├── documents/       # Document parsing, chunking, keyword relevance & chips bar UI
│   ├── overlay/         # Overlay shell, compact/expanded views & window service
│   ├── settings/        # API keys & configuration repository/UI
│   └── transcription/   # Deepgram STT service, models & live transcript view
├── app.dart             # Main MaterialApp setup
└── main.dart            # Application entrypoint
```

---

## 📋 Prerequisites

Before running Mitra Assistant, ensure you have:

1. **Flutter SDK**: `^3.12.2` or later installed and configured for desktop targets (`flutter config --enable-macos-desktop`).
2. **macOS Development Environment**: Xcode 14+ and macOS 12+ (Monterey or later).
3. **API Keys**:
   - **[Deepgram API Key](https://console.deepgram.com/)**: Required for live speech-to-text transcription.
   - **[Google Gemini API Key](https://aistudio.google.com/)**: Required for AI meeting insights generation.

---

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/your-username/mitra_assistant.git
cd mitra_assistant
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Run the App

Launch the application on macOS in debug mode:

```bash
flutter run -d macos
```

---

## ⚙️ Initial Configuration & Permissions

### macOS Permissions
Upon first launch, macOS will request permission for:
- **Microphone**: Required to record your spoken voice.
- **Screen & System Audio Recording**: Required to capture participant audio from video calls.

Ensure permissions are granted under **System Settings > Privacy & Security > Microphone / Screen & System Audio Recording**.

### App Settings Setup
1. Click the ⚙️ **Settings** icon on the overlay control bar.
2. Enter your **Deepgram API Key** and **Gemini API Key**.
3. (Optional) Customize the AI Analysis Interval (in seconds) and select your preferred audio input device.
4. Save settings and start your meeting session!

---

## 🛡️ Privacy & Security

- **Screenshare Masking**: The overlay window is configured natively on macOS to prevent capture during screen sharing, keeping your AI prompts and notes completely confidential.
- **Local Key Storage**: API keys are stored locally on your device using encrypted native storage primitives via `shared_preferences`.

---

## 📄 License

This project is licensed under the MIT License - see the `LICENSE` file for details.
