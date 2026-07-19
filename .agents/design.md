# Design & Architecture Specification (design.md)

**Mitra Assistant** — Professional macOS Floating AI Meeting Co-Pilot

---

## 👁️ 1. Executive Summary & Design Philosophy

Mitra Assistant is designed as a persistent, unobtrusive macOS floating overlay tool for real-time meeting intelligence. The design system follows three core principles:

1. **Non-Intrusive Presence**: The UI seamlessly floats above active meeting windows (Zoom, Google Meet, Microsoft Teams) with a dark translucent glass design (`BackdropFilter` with blur).
2. **Instant Visual Hierarchy**: Color-coded category strips (Indigo, Emerald, Amber, Cyan) allow users to skim key talking points, questions, and action items at a glance during fast-paced calls.
3. **Fluid Responsiveness**: Micro-animations, status pulsing, and seamless transition between **Compact Pill Mode** ($380 \times 56\text{px}$) and **Expanded Assistant Shell** ($420 \times 680\text{px}$).

---

## 🎨 2. Design Tokens & Color Palette

The color system is built around a dark slate backdrop with high-contrast accent highlights for dark-mode readability under high screen-brightness conditions.

| Token Name | Color Value / Hex | Usage |
| :--- | :--- | :--- |
| `backgroundDark` | `Color(0xEC0F172A)` (Slate 900 92%) | Primary application scaffold background |
| `backgroundPureDark` | `Color(0xFF090D16)` (Slate 950) | Pure deep background for input fields & tab bars |
| `cardBackground` | `Color(0x991E293B)` (Slate 800 60%) | Translucent frosted glass card container fill |
| `borderSubtle` | `Color(0x3364748B)` (Slate 500 20%) | Card outlines and divider line separation |
| `borderGlow` | `Color(0x666366F1)` (Indigo Glow 40%) | Outer window border highlight |
| `primaryAccent` | `Color(0xFF6366F1)` (Indigo) | Primary buttons, AI Copilot highlights, AI suggestions |
| `secondaryAccent` | `Color(0xFF10B981)` (Emerald) | Active state indicators, key points, export actions |
| `warningAccent` | `Color(0xFFF59E0B)` (Amber) | System warnings, panic hide actions, questions |
| `panicAccent` | `Color(0xFFEF4444)` (Red) | Stop meeting action, live recording badge, critical alerts |
| `cyanAccent` | `Color(0xFF06B6D4)` (Cyan) | Action item badges |

---

## 📐 3. Layout Scale, Spacing & Typography

### Spacing Scale (`AppSpacing`)
- `xxs`: 2px
- `xs`: 4px
- `sm`: 8px
- `md`: 12px
- `lg`: 16px
- `xl`: 24px
- `xxl`: 32px

### Border Radii (`AppRadius`)
- `sm`: 6px (Badges & chip tags)
- `md`: 10px (Cards & text input fields)
- `lg`: 16px (Shell containers & dialogs)
- `pill`: 999px (Floating status pills & primary action buttons)

### Typography Scale (`AppTextStyles`)
- **Title Large**: 16px / Bold / -0.3px letter-spacing (`textPrimary`)
- **Title Medium**: 14px / SemiBold / -0.2px letter-spacing (`textPrimary`)
- **Title Small**: 12px / SemiBold (`textPrimary`)
- **Body Medium**: 13px / Regular / 1.45 line-height (`textSecondary`)
- **Body Small**: 11px / Regular / 1.35 line-height (`textMuted`)
- **Caption**: 10px / Medium (`textMuted`)
- **Monospace**: 10px / Monospace font family (`textMuted`)

---

## 🧱 4. Component Design System (`lib/core/widgets/`)

### `GlassContainer`
A custom wrapper combining `BackdropFilter` gaussian blur ($\sigma = 10$) with a subtle translucent fill and border stroke.

### `StatusIndicator`
An animated pulsing dot indicator (`SingleTickerProviderStateMixin`) that dynamically pulses when speech recording is active.

### `SectionHeader`
Standardized header bar used across tabs with an iconic badge and action slot.

### `EmptyStateWidget`
Unified empty state UI with circular icon badges, title, description, and action button.

### `AppTextField`
Styled `TextField` wrapper with dedicated focus border highlights (`primaryAccent`) and dense padding.

### `AnimatedTabBar`
Custom tab navigation bar with pill selection highlights and smooth index switching.

---

## 📱 5. Shell Navigation & Window Mechanics

The application window is orchestrated via `window_manager` and `WindowControlService` (`NSWindow` native macOS MethodChannel):

```
+-------------------------------------------------------------+
| Control Bar (Drag Handle | Timer | Start/End Meeting Button) |
+-------------------------------------------------------------+
| AnimatedTabBar (Copilot | Transcript | History | Settings)   |
+-------------------------------------------------------------+
| Active Tab View (InsightView / TranscriptView / etc.)       |
+-------------------------------------------------------------+
```

### Layout Modes
1. **Expanded Mode**: $420 \times 680\text{px}$ full overlay panel.
2. **Compact Mode**: $380 \times 56\text{px}$ floating top bar displaying live interim transcription or top AI insight.

### Native macOS Integration
- **Panic Hide**: Global shortcut (`⌘ + Shift + H`) triggers native window concealment.
- **Screen Protection**: Prevents overlay window capture during screen shares (`NSWindow.sharingType`).

---

## 🧠 6. AI Engine & Deduplication Pipeline Architecture

```
[Live Audio / Mic] ──► [Deepgram STT] ──► [Transcript Stream]
                                                │
                                                ▼
[Gemini 2.5 Flash] ◄── [Sliding Window] ◄── [AiNotifier]
        │
        ▼
[Multi-Pass Deduplicator] ──► (Jaccard Similarity ≥ 0.45?)
        │                              ├─ YES ──► Drop Duplicate
        ▼                              └─ NO  ──► Append & Cap (Max 20)
[Category Filter & UI View]
```

### Multi-Pass Deduplication Algorithm
To eliminate duplicate or paraphrased insights during long meetings:
1. **Direct String & Substring Match**: Checks normalized titles and descriptions.
2. **Tokenized Jaccard Similarity**: Splits normalized strings into word tokens (excluding English stop words) and calculates Jaccard index:
   $$\text{Jaccard}(A, B) = \frac{|A \cap B|}{|A \cup B|}$$
   If similarity $\ge 0.45$, candidate insight is rejected as a paraphrased duplicate.
3. **Capacity Cap**: Limits active insights to a maximum of 20 items per session.
4. **Sliding Transcript Window**: Passes the last 3,000 characters of conversation to Gemini.

---

## 🛠️ 7. Feature Views Overview

1. **AI Copilot (`InsightView`)**:
   - Live AI insights with category-colored left accent strips.
   - Multi-select category filter dropdown menu + live search input field.
   - Direct question prompt field for interactive queries.
2. **Live Transcript (`TranscriptView`)**:
   - Chat bubble list for finalized speech entries with timestamp badges.
   - Animated audio waveform pulse for interim real-time speech.
3. **Meeting History (`HistoryView`)**:
   - Session cards with meeting duration, AI summary highlight, expandable entry preview, and redesigned glass `Export CSV` button.
4. **Settings (`SettingsView`)**:
   - Organized glass cards for API keys (Deepgram, Gemini), audio device selection, screen-share protection, and global shortcuts.
