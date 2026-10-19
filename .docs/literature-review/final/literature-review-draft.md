# AI Meeting Communication Coach: A Speaker-Aware Desktop Assistant

**Author:** Sneha Neupane  
**Student ID:** 900008705  
**Course:** ITNET312A Major Individual Project  
**Assessment:** Assessment 2: Literature Review (Weighting: 20%)  
**Institution:** TAFE NSW Higher Education  
**Date:** September 2026  

---

## 1. Introduction

Virtual meetings through Zoom, Microsoft Teams, and Google Meet have become central to modern workplace and educational collaboration. However, participants face two persistent challenges during live video calls.

First, attendees experience heavy cognitive load. In a fast-paced meeting, one must simultaneously listen to speakers, process technical arguments, take notes, track action items, and plan responses. Under this strain, critical points are frequently missed, action items are forgotten, and questions are left unanswered when conversation shifts quickly (Bailenson, 2021; Sweller, 1988).

Second, participants receive no feedback on their interpersonal communication habits. Meetings routinely suffer from speaking imbalances where dominant participants monopolize time or interrupt others, while quieter individuals struggle to contribute (Kim et al., 2008; Samrose et al., 2021; Zimmerman & West, 1975). Because there is no objective record of conversational dynamics, attendees rarely develop awareness of their communication tendencies.

Commercial meeting tools like Otter.ai, Read.ai, and Fathom do not resolve these issues. They rely on automated bots that join meeting rosters to record calls and produce post-meeting transcripts. These post-hoc summaries arrive long after the call has concluded, providing no assistance during live discussions. Furthermore, they do not assess individual speaking habits, and sending external recording bots into private meetings creates social unease and breaches enterprise data privacy guidelines.

The proposed major project develops an AI Meeting Communication Coach, a lightweight desktop application built with Flutter for macOS and Windows. The assistant captures user microphone audio and incoming system audio locally at the operating system level, eliminating the need for meeting bots. Audio is streamed to Deepgram Nova-2 for sub-400 millisecond speech recognition and speaker diarisation, while Google Gemini generates structured, glanceable insight cards every 12 to 15 seconds.

During the call, a compact heads-up display presents real-time key points, action items, suggested follow-ups, and alerts for unanswered questions. Following the session, the assistant calculates objective conversational sociometrics (participation share, turn-taking cadence, and interruptions) and provides constructive feedback, stored longitudinally in a Graphify knowledge graph. Figure 1 outlines the end-to-end dataflow pipeline of the proposed desktop assistant.

---

## 2. Theoretical Background

The design of the proposed assistant synthesizes four foundational domains: speech recognition, speaker diarisation, large language models, and conversational dynamics.

### 2.1 Automatic Speech Recognition and Streaming Audio

Automatic Speech Recognition (ASR) converts spoken acoustic signals into written text. Early systems relied on Hidden Markov Models with separate acoustic, pronunciation, and language components, which suffered from compounding errors and high latency (Park et al., 2022). Modern systems use end-to-end deep neural networks mapping spectrograms directly to word tokens via Connectionist Temporal Classification and Transformer attention (Gulati et al., 2020; Radford et al., 2023).

A vital architectural distinction exists between batch and streaming models. Offline models like OpenAI's Whisper process audio in 30-second windows using bidirectional attention (Radford et al., 2023). While accurate on static recordings, this introduces latency exceeding 30 seconds, rendering it unusable for real-time meeting support. In contrast, streaming models based on the Conformer architecture (Gulati et al., 2020) combine depthwise separable convolutions with causal self-attention, processing audio frames over WebSockets with transcription latency below 400 milliseconds.

### 2.2 Speaker Diarisation and Acoustic Separation

While ASR transcribes spoken words, speaker diarisation determines "who spoke when" (Park et al., 2022). In multi-speaker meetings, attributing speech to specific individuals is necessary to compute participation balance, track interruptions, and assign action items.

A standard diarisation pipeline comprises voice activity detection, temporal segmentation, acoustic embedding extraction via neural networks, and clustering (Bredin et al., 2020). Offline diarisation clusters embeddings globally across an entire recording. Streaming diarisation, however, must incrementally assign speaker identities by maintaining running cluster centroids in memory without retroactively revising past labels (Park et al., 2022).

### 2.3 Large Language Models and Dialogue Engineering

Large Language Models (LLMs) based on Transformer architectures have demonstrated remarkable semantic reasoning capabilities (Vaswani et al., 2017; Gemini Team, 2024). In meeting co-pilots, LLMs function as semantic interpreters converting raw transcript streams into structured insights.

Effective dialogue engineering relies on three key mechanisms:
* Dialogue Act Classification: Categorizing utterance intentions, such as information requests, commitments, and agreements, to reliably separate explicit questions from rhetorical remarks (Stolcke et al., 2000).
* Context Summarization: Distilling decisions from continuous dialogue while preserving operational specifics (Zhong et al., 2021; Hu et al., 2023).
* Strict JSON Schema Constraints: Enforcing schema constraints so models return structured cards (category, title, description) without unparseable conversational filler.

### 2.4 Conversational Dynamics, Turn-Taking, and Sociometrics

Human conversation follows structured turn-taking conventions. Sacks, Schegloff, and Jefferson (1974) demonstrated that dialogue is organized to minimize both silence and simultaneous speech. Turns transition at Transition Relevance Places (TRPs), marked by syntactic, intonational, and pragmatic completions. Across languages, turn-transition gaps average between 200 and 300 milliseconds (Stivers et al., 2009).

When speech overlaps, sociolinguistic theory distinguishes two phenomena (Zimmerman & West, 1975):
* Supportive Backchannels: Brief affirmative vocalizations ("yeah", "okay") that signal active listening without claiming the floor.
* Intrusive Interruptions: Overlaps that cut off a speaker prior to a TRP to seize the floor.

Pentland (2008) showed that non-linguistic conversational cues, such as speaking equity and turn pacing, strongly predict team performance. Visualizing participation balance allows groups to self-regulate effectively (Kim et al., 2008).

To prevent split-attention and cognitive overload (Sweller, 1988; Bailenson, 2021), assistive interfaces must present peripheral, glanceable cues rather than dense text (Matthews et al., 2007). Therefore, assistive interfaces must remain compact, peripheral, and easily glanceable.

---

## 3. Critical Analysis and Synthesis

Evaluating existing commercial products and academic research highlights clear architectural gaps that justify the proposed desktop assistant.

### 3.1 Commercial Meeting Tools vs. Research Prototypes

Commercial products such as Otter.ai, Read.ai, and Zoom AI Companion operate as retrospective note-takers. They deploy bots into meetings and deliver summaries after adjournment. However, retrospective summaries cannot assist participants during active discussions. Missing a critical decision or failing to answer a direct question cannot be rectified thirty minutes after a call ends. Furthermore, invasive recording bots provoke privacy concerns and are often banned under enterprise security policies.

Academic research has demonstrated the effectiveness of communication dashboards. Samrose et al. (2021) developed MeetingCoach, showing that post-meeting metrics on speaking time, turn-taking, and sentiment foster participant self-awareness and encourage inclusive habits. However, MeetingCoach provided only post-hoc analysis without live in-meeting guidance.

The proposed system bridges this divide by delivering both real-time in-flight support and longitudinal coaching, packaged inside a native desktop overlay that requires no bot attendance.

### 3.2 Streaming vs. Batch Latency Trade-offs

A central technical trade-off lies between batch and streaming architectures. Batch models such as Whisper (Radford et al., 2023) achieve high accuracy but require 30-second audio windows, introducing delays that miss rapid 200 to 300 millisecond conversational turns (Stivers et al., 2009).

Streaming WebSocket ASR using Deepgram Nova-2 achieves transcription latency under 400 milliseconds. To prevent user distraction and control API costs, the client buffers transcripts locally and queries Gemini every 12 to 15 seconds. This window provides sufficient context for meaningful inference while adhering to the 15-second response target specified in the Project Charter.

### 3.3 Diarisation Bottlenecks in Overlapping Speech

In multi-party meetings, 10% to 20% of conversation consists of overlapping speech (Janin et al., 2003; Carletta et al., 2006). When multiple voices blend onto a single audio channel, acoustic embeddings degrade, causing diarisation errors.

The proposed desktop assistant mitigates this via hardware-level channel isolation:
* Dual-Channel Separation: Microphone audio is captured on Channel 0, while remote call audio is captured on Channel 1 via operating system loopback (macOS ScreenCaptureKit or Windows WASAPI). This guarantees the local user's speech is never confused with remote participants.
* Single-Speaker Fallback: If network compression degrades remote diarisation quality, remote turns are aggregated into a combined profile while local statistics remain fully accurate.

### 3.4 Cognitive Ergonomics and Glanceable HUD Design

Displaying information during a live call risks inducing extraneous cognitive load (Sweller, 1988). Following peripheral display principles (Matthews et al., 2007), the user interface is structured as a glanceable heads-up display (HUD):
* Compact Mode: A small floating pill displaying audio activity, active speaker, and status.
* Expanded Mode: Categorized cards with distinct colors: Suggestions (Purple), Key Points (Blue), Questions (Emerald), and Action Items (Amber). Each card is restricted to a concise title and one-sentence description.
* Hotkey Navigation: Users can toggle and position the overlay using global shortcuts without taking focus away from their meeting app.

### 3.5 Dialogue Acts and Unanswered Question Alerts

Questions in virtual meetings are frequently neglected when another participant speaks or changes topics. Detecting unaddressed questions requires tracking dialogue acts across sequential turns (Stolcke et al., 2000). Every 12 to 15 seconds, Gemini evaluates the rolling transcript buffer. If an explicit information request is identified without a corresponding response in subsequent turns, the system raises an alert badge, allowing the user to address the topic before the discussion moves on.

### 3.6 Privacy, Consent, and System-Level Screen Share Masking

Third-party meeting bots present significant corporate privacy and intellectual property risks. The proposed assistant operates entirely on the host machine without joining meeting rosters. API credentials are stored securely in OS keychains.

To protect confidentiality during screen sharing, the window is masked at the OS compositor level. On macOS, the window sets `NSWindow.sharingType = .none`. On Windows, it invokes `SetWindowDisplayAffinity(hwnd, WDA_EXCLUDEFROMCAPTURE)`. Consequently, the coaching overlay remains visible to the user but completely invisible to other participants during screen shares.

---

## 4. Advancements in Meeting Communication and Assistive AI

Recent breakthroughs in streaming neural models, overhearing agents, and graph representations make a lightweight desktop assistant practical.

### 4.1 End-to-End Streaming Neural ASR (Conformer and Nova-2)

The Conformer architecture (Gulati et al., 2020) combines convolutions for local feature extraction with self-attention for global context. Deepgram Nova-2 operationalizes this architecture to provide sub-400ms streaming ASR and online diarisation over WebSockets, eliminating the need for expensive local GPU hardware.

### 4.2 The Ambient Overhearing Agent Paradigm

Traditional conversational agents require explicit user prompts, which is impractical while speaking in a live meeting. Zhu and Callison-Burch (2025) formulated the concept of "overhearing LLM agents," which passively monitor multi-party dialogue and surface contextual insights into a side channel. To prevent repetitive suggestions and token bloat, the proposed assistant maintains a 2-to-3 minute rolling buffer and applies prompt-level deduplication. If no new actionable items arise, the model outputs an empty array, keeping the display clutter-free.

### 4.3 Zero-Token Local Document Grounding

Traditional Retrieval-Augmented Generation (RAG) pipelines upload documents to cloud vector databases, incurring API costs and retrieval latency. The proposed system employs a local, zero-token alternative:
1. Reference documents (PDF, DOCX, TXT) are parsed locally upon upload using Dart libraries.
2. Text is segmented and indexed by keywords in local memory, while a single initial Gemini call generates a concise summary.
3. During meetings, live transcripts are matched against indexed keywords using local Jaccard similarity.
4. When discussion is off-topic, zero document tokens are transmitted to the cloud. When relevant keywords are detected, matching excerpts (capped at 1,500 characters) are included in the prompt, grounding the insights locally without cloud vector overhead.

### 4.4 Quantitative Sociometrics and Interruption Modeling

Drawing from conversational turn-taking (Sacks et al., 1974), interruption dynamics (Zimmerman & West, 1975), and sociometrics (Pentland, 2008), the system calculates three metrics post-meeting:
1. Participation Share: The percentage of total active talk time consumed by each participant:

Participation Share (%) = (Total Speaking Duration of Speaker / Total Active Meeting Speaking Duration) * 100

Attendees taking over 60% of speaking time receive feedback on dominance, while those under 10% are encouraged to participate more actively.
2. Turn-Taking Cadence: Floor transitions per minute, evaluating conversational interactivity.
3. Interruption vs. Backchannel: Overlaps under 1.5 seconds where the primary speaker continues are classified as supportive backchannels. Overlaps causing the primary speaker to stop talking are flagged as intrusive interruptions.

### 4.5 Longitudinal Memory via Knowledge Graphs (Graphify)

Standard meeting tools operate ephemerally, clearing all context once a session ends. Meaningful coaching, however, requires tracking habits over time. Pan et al. (2024) demonstrated that integrating LLMs with structured knowledge graphs enables durable memory and prevents hallucinations.

The proposed assistant integrates Graphify, an on-device graph database. Following each call, meeting metrics, action items, and coaching suggestions are linked across entities (Speaker, MeetingSession, Review, ActionItem). This allows the system to compare sessions over weeks and months, tracking whether speaking equity and interruption habits improve over time.

---

## 5. System Architecture of the Proposed Desktop Assistant

The architecture coordinates five functional stages:
1. Native Audio Capture: Records local microphone input (Channel 0) and remote meeting audio (Channel 1) via OS loopback APIs (macOS ScreenCaptureKit or Windows WASAPI) as 16kHz linear PCM.
2. Streaming ASR and Diarisation: Transmits audio frames over WebSockets to Deepgram Nova-2, returning timestamped words and speaker labels with sub-400ms latency.
3. Context Buffering and Relevance Matching: Buffers transcript turns client-side and performs local Jaccard similarity matching against reference documents.
4. LLM Cognitive Reasoning: Sends buffered transcripts and matched document chunks to Google Gemini every 12 to 15 seconds to detect dialogue acts, unanswered questions, and structured insight cards.
5. Glanceable HUD Presentation and Longitudinal Storage: Displays insights on the floating overlay during calls. Post-meeting, sociometrics are computed, exported to CSV, and stored in the Graphify knowledge graph.

---

## 6. Synthesis, Discussion, and Feasibility

### 6.1 State-of-the-Art Comparative Synthesis Matrix

Table 1 synthesizes the technical differences between existing commercial cloud tools, academic research prototypes, enterprise suites, and the proposed desktop assistant.

| Feature / Dimension | Commercial Cloud Bots (Otter, Read.ai) | Academic Systems (MeetingCoach) | Enterprise Tools (Teams Copilot) | Proposed Desktop Assistant |
| :--- | :--- | :--- | :--- | :--- |
| **Delivery Timing** | Post-meeting batch (30-60 min delay) | Post-meeting dashboard only | Post-meeting and in-app chat | Live in-flight HUD and post-meeting coach |
| **Meeting Ingress** | Invasive bot in call roster | Custom lab hardware | Built-in platform license | Host OS audio loopback (No bot needed) |
| **Live Latency** | High or none (>30s) | Offline post-hoc | Moderate (Cloud pipeline) | Sub-second ASR, 12-15s LLM insights |
| **Speaker Diarisation** | Server-side single channel | Multi-sensor array | Platform user accounts | Dual-channel native loopback and Nova-2 |
| **Unanswered Questions** | Not supported | Not supported | Basic text search query | Automatic dialogue act detection and alert |
| **Document Grounding** | Full cloud file upload | Not supported | OneDrive cloud sync | Zero-token local keyword matching |
| **Screen Share Privacy** | In-browser visible | Not applicable | Standard app window | Native OS window masking (sharingType/WDA) |
| **Longitudinal Tracking** | Flat search list | Static study logs | Basic cross-meeting search | Graphify knowledge graph memory |

### 6.2 Capstone Feasibility, Budget, and Risk Analysis

The proposed system is engineered for complete individual execution across a 12-week capstone timeline:
* Tooling and Budget: Development leverages existing personal computers and free tooling. Operating expenses are confined to cloud APIs:
  - Deepgram streaming ASR and diarisation: AUD 60 to AUD 120
  - Google Gemini language analysis: AUD 40 to AUD 80
  - Total expenditure: AUD 100 to AUD 200, strictly within the AUD 200 project budget.
* Development Scope: Leveraging established cloud APIs for transcription and reasoning allows development to concentrate on client architecture, audio loopback capture, prompt engineering, and sociometric algorithms without training custom deep learning models.
* Phased Timeline: Development progresses across six two-week iterations, completing audio capture by Week 5, live HUD cards by Week 7, post-meeting coaching by Week 9, and empirical evaluation by Week 11.

---

## 7. Conclusion

Virtual meetings frequently suffer from cognitive overload, lost action items, unanswered questions, and a lack of objective speaking feedback. Commercial platforms remain focused on retrospective summaries produced by intrusive bots, while academic prototypes have largely omitted real-time in-flight support.

This literature review provides the conceptual and technical foundation for an AI Meeting Communication Coach. By combining Conformer streaming ASR, dual-channel audio loopback, throttled Gemini reasoning, zero-token local document grounding, peripheral HUD ergonomics, and Graphify knowledge graphs, the proposed desktop assistant delivers both live cognitive assistance and longitudinal behavioral coaching. The architecture respects user privacy, requires no meeting bots, and is fully achievable within the 12-week capstone schedule.

---

## 8. References

Bailenson, J. N. (2021). Nonverbal overload: A theoretical argument for the causes of Zoom fatigue. *Technology, Mind, and Behavior*, 2(1). https://doi.org/10.1037/tmb0000030

Bredin, H., Yin, R., Coria, J. M., Broux, G., Bousbih, M., Barsim, M. N., ... & Zhang, Z. (2020). pyannote.audio: Neural building blocks for speaker diarization. In *ICASSP 2020 - 2020 IEEE International Conference on Acoustics, Speech and Signal Processing (ICASSP)* (pp. 7124-7128). IEEE. https://doi.org/10.1109/ICASSP40776.2020.9052974

Carletta, J., Ashby, S., Bourban, S., Flynn, M., Guillemot, M., Hain, T., Ehlers, M., Post, W., & Wellner, P. (2006). The AMI meeting corpus: A pre-announcement. In S. Renals & S. Bengio (Eds.), *Machine Learning for Multimodal Interaction: Second International Workshop, MLMI 2005, Revised Selected Papers* (Lecture Notes in Computer Science, Vol. 3869, pp. 28-39). Springer, Berlin, Heidelberg. https://doi.org/10.1007/11677482_3 (Note: MLMI workshop presented in 2005; official Springer volume published in 2006).

Gemini Team, Google. (2024). Gemini: A family of highly capable multimodal models. *arXiv preprint arXiv:2312.11805*. https://doi.org/10.48550/arXiv.2312.11805

Gulati, A., Qin, J., Chiu, C. C., Parmar, N., Zhang, Y., Yu, J., ... & Pang, R. (2020). Conformer: Convolution-augmented transformer for speech recognition. In *Interspeech 2020* (pp. 5036-5040). https://doi.org/10.21437/Interspeech.2020-3015

Hu, Y., Ganter, T., Deilamsalehy, H., Dernoncourt, F., Foroosh, H., & Liu, F. (2023). MeetingBank: A benchmark dataset for meeting summarization. In *Proceedings of the 61st Annual Meeting of the Association for Computational Linguistics (Volume 1: Long Papers)* (pp. 16409-16423). Association for Computational Linguistics. https://doi.org/10.18653/v1/2023.acl-long.906

Janin, A., Baron, D., Edwards, J., Ellis, D., Gelbart, D., Morgan, N., ... & Shriberg, E. (2003). The ICSI meeting corpus. In *2003 IEEE International Conference on Acoustics, Speech, and Signal Processing (ICASSP '03)* (Vol. 1, pp. I-364). IEEE. https://doi.org/10.1109/ICASSP.2003.1198793

Kim, T., Chang, A., Holland, L., & Pentland, A. (2008). Meeting mediator: Enhancing group collaboration using sociometric feedback. In *Proceedings of the 2008 ACM Conference on Computer Supported Cooperative Work (CSCW '08)* (pp. 457-466). Association for Computing Machinery. https://doi.org/10.1145/1460563.1460636

Matthews, T., Rattenbury, T., & Carter, S. (2007). Defining, designing, and evaluating peripheral displays: An analysis using activity theory. *Human-Computer Interaction*, 22(1-2), 221-261. https://doi.org/10.1080/07370020701307997

Pan, S., Luo, L., Wang, Y., Chen, C., Wang, J., & Wu, X. (2024). Unifying large language models and knowledge graphs: A roadmap. *IEEE Transactions on Knowledge and Data Engineering*, 36(7), 3580-3599. https://doi.org/10.1109/TKDE.2024.3352100

Park, T. J., Kanda, N., Dimitriadis, D., Han, K. J., Watanabe, S., & Narayanan, S. (2022). A review of speaker diarization: Recent advances with deep learning. *Computer Speech & Language*, 72, 101317. https://doi.org/10.1016/j.csl.2021.101317

Pentland, A. (2008). *Honest signals: How they shape our world*. The MIT Press. https://doi.org/10.7551/mitpress/8022.001.0001

Radford, A., Kim, J. W., Xu, T., Brockman, G., McLeavey, C., & Sutskever, I. (2023). Robust speech recognition via large-scale weak supervision. In *Proceedings of the 40th International Conference on Machine Learning (ICML 2023)* (Vol. 202, pp. 28492-28518). PMLR.

Sacks, H., Schegloff, E. A., & Jefferson, G. (1974). A simplest systematics for the organization of turn-taking for conversation. *Language*, 50(4), 696-735. https://doi.org/10.2307/412243

Samrose, S., McDuff, D., Sim, R., Suh, J., Rowan, K., Hernandez, J., Rintel, S., Moynihan, K., & Czerwinski, M. (2021). MeetingCoach: An intelligent dashboard for supporting effective and inclusive meetings. In *Proceedings of the 2021 CHI Conference on Human Factors in Computing Systems* (pp. 1-13). Association for Computing Machinery. https://doi.org/10.1145/3411764.3445615

Stivers, T., Enfield, N. J., Brown, P., Englert, C., Hayashi, M., Heinemann, T., ... & Levinson, S. C. (2009). Universals and cultural variation in turn-taking in conversation. *Proceedings of the National Academy of Sciences*, 106(26), 10587-10592. https://doi.org/10.1073/pnas.0903616106

Stolcke, A., Ries, K., Coccaro, N., Shriberg, E., Bates, R., Jurafsky, D., ... & Meteer, M. (2000). Dialogue act modeling for automatic tagging and recognition of conversational speech. *Computational Linguistics*, 26(3), 339-373. https://doi.org/10.1162/089120100561737

Sweller, J. (1988). Cognitive load during problem solving: Effects on learning. *Cognitive Science*, 12(2), 257-285. https://doi.org/10.1207/s15516709cog1202_4

Vaswani, A., Shazeer, N., Parmar, N., Uszkoreit, J., Jones, L., Gomez, A. N., Kaiser, Ł., & Polosukhin, I. (2017). Attention is all you need. In *Advances in Neural Information Processing Systems 30 (NeurIPS 2017)* (pp. 6000-6010).

Zhong, M., Yin, D., Yu, T., Zaidi, A., Mutuma, M., Jha, R., Hassan Awadallah, A., Celikyilmaz, A., Liu, Y., Qiu, X., & Radev, D. (2021). QMSum: A new benchmark for query-based multi-domain meeting summarization. In *Proceedings of the 2021 Conference of the North American Chapter of the Association for Computational Linguistics: Human Language Technologies* (pp. 5905-5921). Association for Computational Linguistics. https://doi.org/10.18653/v1/2021.naacl-main.472

Zhu, A., & Callison-Burch, C. (2025). Overhearing LLM agents: A survey, taxonomy, and roadmap. *arXiv preprint arXiv:2509.16325*. https://doi.org/10.48550/arXiv.2509.16325

Zimmerman, D. H., & West, C. (1975). Sex roles, interruptions and silences in conversation. In B. Thorne & N. Henley (Eds.), *Language and sex: Difference and dominance* (pp. 105-129). Newbury House Publishers.

---

## 9. Appendix: Generative AI Declaration

*In accordance with TAFE NSW Higher Education Academic Integrity Policy (Level 2: AI-Assisted Editing).*

### Generative AI Usage Statement

* **Permitted Level:** Level 2: AI-Assisted Editing.
* **Tool Name and Version:** Google Gemini (Gemini 2.5 Flash / 3.8 Flash).
* **Purpose of Use:** Generative AI was utilized solely as an editorial tool for proofreading, checking grammatical structure, verifying citation syntax according to APA 7th edition, and improving the conciseness and clarity of the student's text.
* **Student Ownership and Verification:** All research topics, literature discovery, comparative analysis, architectural formulations, and technical decisions were conceptualized and evaluated by the student. No content or ideas were generated by artificial intelligence. The student verified all cited references and DOIs directly against published conference and journal databases.
* **Example Prompts Used:**
  1. *"Review this literature review draft for grammar, clarity, and conciseness, removing repetitive phrasing."*
  2. *"Check these references for compliance with APA 7th edition citation conventions."*
