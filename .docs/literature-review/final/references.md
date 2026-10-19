# Literature Review References: AI Meeting Communication Coach

**Project Title:** AI Meeting Communication Coach: A Speaker-Aware Desktop Assistant (the proposed desktop assistant)  
**Author:** Sneha Neupane (Student ID: 900008705)  
**Unit:** ITNET312A Major Individual Project : Assessment 2: Literature Review  
**Institution:** TAFE NSW Higher Education  
**Referencing Style:** APA 7th Edition  

22. **Vaswani, A., Shazeer, N., Parmar, N., Uszkoreit, J., Jones, L., Gomez, A. N., Kaiser, Ł., & Polosukhin, I.** (2017). Attention is all you need. In *Advances in Neural Information Processing Systems 30 (NeurIPS 2017)* (pp. 6000-6010).
    - *Relevance to Project:* Foundational Transformer architecture underpinning all modern LLMs and Conformer ASR encoders used in the proposed system.

---

## 1. Primary References (Alphabetical by Author)

1. **Bailenson, J. N.** (2021). Nonverbal overload: A theoretical argument for the causes of Zoom fatigue. *Technology, Mind, and Behavior*, 2(1). https://doi.org/10.1037/tmb0000030
   - *Relevance to Project:* Establishes the psychological framework of video-conferencing fatigue caused by constant self-view, high cognitive load in decoding nonverbal cues, and continuous screen gaze. Informs the proposed desktop assistant's glanceable, low-distraction overlay design to prevent additional cognitive overload.

2. **Bredin, H., Yin, R., Coria, J. M., Broux, G., Bousbih, M., Barsim, M. N., ... & Zhang, Z.** (2020). pyannote.audio: Neural building blocks for speaker diarization. In *ICASSP 2020 - 2020 IEEE International Conference on Acoustics, Speech and Signal Processing (ICASSP)* (pp. 7124-7128). IEEE. https://doi.org/10.1109/ICASSP40776.2020.9052974
   - *Relevance to Project:* Demonstrates state-of-the-art neural architectures for voice activity detection, speaker embedding extraction, and diarization. Highlights the trade-offs between batch clustering models and real-time streaming diarization requirements in the proposed desktop assistant.

3. **Carletta, J., Ashby, S., Bourban, S., Flynn, M., Guillemot, M., Hain, T., Ehlers, M., Post, W., & Wellner, P.** (2006). The AMI meeting corpus: A pre-announcement. In S. Renals & S. Bengio (Eds.), *Machine Learning for Multimodal Interaction: Second International Workshop, MLMI 2005, Revised Selected Papers* (Lecture Notes in Computer Science, Vol. 3869, pp. 28-39). Springer, Berlin, Heidelberg. https://doi.org/10.1007/11677482_3 (Note: MLMI workshop presented in 2005; official Springer volume published in 2006).
   - *Relevance to Project:* Foundational multimodal benchmark corpus providing realistic multi-party meeting data, speaker turns, dialogue acts, and annotations. Serves as a standard theoretical benchmark for meeting analysis and evaluation.

4. **Gemini Team, Google.** (2024). Gemini: A family of highly capable multimodal models. *arXiv preprint arXiv:2312.11805*. https://doi.org/10.48550/arXiv.2312.11805
   - *Relevance to Project:* Details the underlying multimodal and long-context capabilities of Google Gemini 1.5/2.0 Flash and Pro, used by the proposed desktop assistant for low-latency in-flight transcript analysis, prompt handling, and structured JSON insight extraction.

5. **Gulati, A., Qin, J., Chiu, C. C., Parmar, N., Zhang, Y., Yu, J., ... & Pang, R.** (2020). Conformer: Convolution-augmented transformer for speech recognition. In *Interspeech 2020* (pp. 5036-5040). https://doi.org/10.21437/Interspeech.2020-3015
   - *Relevance to Project:* Proposes the Conformer architecture combining CNNs and self-attention, which forms the architectural backbone of modern streaming end-to-end ASR engines (such as Deepgram Nova-2) used for real-time speech transcription in the proposed desktop assistant.

6. **Hu, Y., Ganter, T., Deilamsalehy, H., Dernoncourt, F., Foroosh, H., & Liu, F.** (2023). MeetingBank: A benchmark dataset for meeting summarization. In *Proceedings of the 61st Annual Meeting of the Association for Computational Linguistics (Volume 1: Long Papers)* (pp. 16409-16423). Association for Computational Linguistics. https://doi.org/10.18653/v1/2023.acl-long.906
   - *Relevance to Project:* Provides a large-scale real-world dataset and taxonomy for meeting summarization and dialogue analysis, validating that raw transcripts require targeted chunking and prompt structuring to extract reliable summaries and action items.

7. **Janin, A., Baron, D., Edwards, J., Ellis, D., Gelbart, D., Morgan, N., ... & Shriberg, E.** (2003). The ICSI meeting corpus. In *2003 IEEE International Conference on Acoustics, Speech, and Signal Processing (ICASSP '03)* (Vol. 1, pp. I-364). IEEE. https://doi.org/10.1109/ICASSP.2003.1198793
   - *Relevance to Project:* Classic conversational speech dataset emphasizing natural meeting acoustics, multi-channel recording, overlapping speech phenomena, and conversational turns. Informs the handling of acoustic overlap and diarization challenges in the proposed desktop assistant.

8. **Kim, T., Chang, A., Holland, L., & Pentland, A.** (2008). Meeting mediator: Enhancing group collaboration using sociometric feedback. In *Proceedings of the 2008 ACM Conference on Computer Supported Cooperative Work (CSCW '08)* (pp. 457-466). Association for Computing Machinery. https://doi.org/10.1145/1460563.1460636
   - *Relevance to Project:* Seminal CSCW study evaluating real-time sociometric visual feedback (speaking time balance and interactivity) on group dynamics. Demonstrates that visualizing participation dynamics encourages quiet members to speak and mitigates dominance.

9. **Matthews, T., Rattenbury, T., & Carter, S.** (2007). Defining, designing, and evaluating peripheral displays: An analysis using activity theory. *Human-Computer Interaction*, 22(1-2), 221-261. https://doi.org/10.1080/07370020701307997
   - *Relevance to Project:* Establishes interaction design principles for glanceable, ambient, and peripheral user interfaces. Directly guides the design of the proposed desktop assistant's compact overlay mode, ensuring notifications sit comfortably in peripheral awareness without breaking conversational immersion.

10. **Pan, S., Luo, L., Wang, Y., Chen, C., Wang, J., & Wu, X.** (2024). Unifying large language models and knowledge graphs: A roadmap. *IEEE Transactions on Knowledge and Data Engineering*, 36(7), 3580-3599. https://doi.org/10.1109/TKDE.2024.3352100
    - *Relevance to Project:* Surveys the integration of LLMs with structured knowledge graphs. Directly validates the proposed desktop assistant’s use of Graphify knowledge bases for storing cross-meeting historical reviews, allowing longitudinal communication growth tracking beyond ephemeral LLM context windows.

11. **Park, T. J., Kanda, N., Dimitriadis, D., Han, K. J., Watanabe, S., & Narayanan, S.** (2022). A review of speaker diarization: Recent advances with deep learning. *Computer Speech & Language*, 72, 101317. https://doi.org/10.1016/j.csl.2021.101317
    - *Relevance to Project:* Comprehensive literature review of deep learning approaches to speaker diarization, discussing the mathematical distinction between offline agglomerative clustering vs online streaming clustering, diarization error rates (DER), and speaker permutation invariance.

12. **Pentland, A.** (2008). *Honest signals: How they shape our world*. The MIT Press. https://doi.org/10.7551/mitpress/8022.001.0001
    - *Relevance to Project:* Identifies non-linguistic social signals:turn-taking consistency, vocal influence, conversational engagement, and interruptions:as direct predictors of collaborative success, providing the theoretical grounding for the proposed desktop assistant's post-meeting coaching metrics.

13. **Radford, A., Kim, J. W., Xu, T., Brockman, G., McLeavey, C., & Sutskever, I.** (2023). Robust speech recognition via large-scale weak supervision. In *Proceedings of the 40th International Conference on Machine Learning (ICML 2023)* (Vol. 202, pp. 28492-28518). PMLR.
    - *Relevance to Project:* Demonstrates the breakthrough in zero-shot robustness for speech recognition using large-scale weakly supervised audio data (Whisper). Highlights why encoder-decoder batch models excel at offline tasks but require streaming adaptations or dedicated streaming engines (like Deepgram) for live in-meeting latency constraints.

14. **Sacks, H., Schegloff, E. A., & Jefferson, G.** (1974). A simplest systematics for the organization of turn-taking for conversation. *Language*, 50(4), 696-735. https://doi.org/10.2307/412243
    - *Relevance to Project:* The fundamental sociological theory of conversation analysis detailing turn-constructional units, transition relevance places (TRPs), and turn allocation. Forms the conceptual baseline for detecting turn-taking rhythms and interruptions in meeting analytics.

15. **Samrose, S., McDuff, D., Sim, R., Suh, J., Rowan, K., Hernandez, J., Rintel, S., Moynihan, K., & Czerwinski, M.** (2021). MeetingCoach: An intelligent dashboard for supporting effective and inclusive meetings. In *Proceedings of the 2021 CHI Conference on Human Factors in Computing Systems* (pp. 1-13). Association for Computing Machinery. https://doi.org/10.1145/3411764.3445615
    - *Relevance to Project:* Closest academic relative to the post-meeting coaching module of the proposed desktop assistant. Evaluates an intelligent post-meeting feedback dashboard tracking speaking duration, turn dynamics, and sentiment, confirming that reflective, retrospective feedback empowers attendees to improve participation without in-meeting distraction.

16. **Stivers, T., Enfield, N. J., Brown, P., Englert, C., Hayashi, M., Heinemann, T., ... & Levinson, S. C.** (2009). Universals and cultural variation in turn-taking in conversation. *Proceedings of the National Academy of Sciences*, 106(26), 10587-10592. https://doi.org/10.1073/pnas.0903616106
    - *Relevance to Project:* Empirical cross-linguistic study establishing that typical floor-transition gaps in human dialogue fall within 200-300 milliseconds. Reinforces the technical necessity of sub-second streaming diarization and fast inference to accurately classify turn transfers versus intrusive interruptions.

17. **Stolcke, A., Ries, K., Coccaro, N., Shriberg, E., Bates, R., Jurafsky, D., ... & Meteer, M.** (2000). Dialogue act modeling for automatic tagging and recognition of conversational speech. *Computational Linguistics*, 26(3), 339-373. https://doi.org/10.1162/089120100561737
    - *Relevance to Project:* Establishes computational modeling of dialogue acts (questions, statements, acknowledgments, agreements). Informs the algorithmic classification of question-answer pairs and the detection of unanswered queries in conversational streams.

18. **Sweller, J.** (1988). Cognitive load during problem solving: Effects on learning. *Cognitive Science*, 12(2), 257-285. https://doi.org/10.1207/s15516709cog1202_4
    - *Relevance to Project:* Cognitive Load Theory (CLT) explaining intrinsic, extraneous, and germane cognitive load. Provides the justification for the proposed desktop assistant’s filtering logic, concise JSON card layout, and 12-to-15 second analysis cycles to avoid extraneous load during active dialogue.

19. **Zhong, M., Yin, D., Yu, T., Zaidi, A., Mutuma, M., Jha, R., Hassan Awadallah, A., Celikyilmaz, A., Liu, Y., Qiu, X., & Radev, D.** (2021). QMSum: A new benchmark for query-based multi-domain meeting summarization. In *Proceedings of the 2021 Conference of the North American Chapter of the Association for Computational Linguistics: Human Language Technologies* (pp. 5905-5921). Association for Computational Linguistics. https://doi.org/10.18653/v1/2021.naacl-main.472
    - *Relevance to Project:* Benchmark illustrating that users in meetings rarely want monolithic summaries; instead, they need query-focused, topic-specific retrieval and concise bullet points, directly corroborating the proposed desktop assistant’s structured insight categories (key points, suggestions, action items, questions).

20. **Zhu, A., & Callison-Burch, C.** (2025). Overhearing LLM agents: A survey, taxonomy, and roadmap. *arXiv preprint arXiv:2509.16325*. https://doi.org/10.48550/arXiv.2509.16325
    - *Relevance to Project:* Formulates the theoretical paradigm of "overhearing LLM agents":systems that silently observe ambient multi-party interaction and synthesize situational intelligence into a side channel without disrupting conversational flow. Serves as the primary theoretical architecture for the proposed desktop assistant's live co-pilot functionality.

21. **Zimmerman, D. H., & West, C.** (1975). Sex roles, interruptions and silences in conversation. In B. Thorne & N. Henley (Eds.), *Language and sex: Difference and dominance* (pp. 105-129). Newbury House Publishers.
    - *Relevance to Project:* Foundational study operationalizing interruptions versus collaborative overlaps in conversational analysis. Grounding metric for the proposed desktop assistant's post-meeting participation analysis and inclusive communication coaching.

---

## 2. Categorical Synthesis Matrix

| Thematic Category | Key Citations | Direct Engineering & Architectural Application in the proposed desktop assistant |
| :--- | :--- | :--- |
| **Conversational Dynamics & Sociometric Feedback** | Sacks et al. (1974); Zimmerman & West (1975); Kim et al. (2008); Pentland (2008); Stivers et al. (2009) | Formulates metrics for turn-taking, speaking duration distribution, floor transitions, and interruption detection. Informs the post-meeting coaching engine and personalized suggestion generation. |
| **Streaming Speech-to-Text & Speaker Diarisation** | Janin et al. (2003); Carletta et al. (2006); Gulati et al. (2020); Bredin et al. (2020); Park et al. (2022); Radford et al. (2023) | Justifies the selection of streaming WebSocket Conformer ASR (Deepgram Nova-2) over batch offline models (Whisper) to achieve sub-second live transcript latency and real-time online diarisation. |
| **LLM Reasoning, Dialogue Acts & Overhearing Agents** | Stolcke et al. (2000); Zhong et al. (2021); Hu et al. (2023); Gemini Team (2024); Zhu & Callison-Burch (2025) | Establishes the "overhearing agent" paradigm. Defines rolling transcript buffer extraction, dialogue act tagging (unanswered question detection), and structured JSON insight generation via Gemini 1.5/2.0. |
| **Human-Computer Interaction & Cognitive Load** | Sweller (1988); Matthews et al. (2007); Bailenson (2021); Samrose et al. (2021) | Explains the necessity of glanceable, ambient UI design, compact/expanded modes, and throttled analysis cycles (12-15s) to avoid cognitive split-attention and Zoom fatigue. |
| **Longitudinal Memory & Structured Knowledge Graphs** | Pan et al. (2024) | Justifies replacing flat, ephemeral context windows with Graphify knowledge bases to benchmark personal speaking growth and participation trends across recurring meetings. |
