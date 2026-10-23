class AppConstants {
  static const String appName = 'Mitra Assistant';
  
  // Default API Keys storage keys
  static const String prefDeepgramApiKey = 'deepgram_api_key';
  static const String prefGeminiApiKey = 'gemini_api_key';
  static const String prefAutoStartAi = 'auto_start_ai';
  static const String prefAnalysisInterval = 'analysis_interval_sec';
  static const String prefAudioInputDevice = 'audio_input_device';
  static const String prefCaptureSystemAudio = 'capture_system_audio';
  static const String prefMeetingHistory = 'meeting_history';
  static const String prefMyName = 'my_name';
  static const String prefGoals = 'coaching_goals';
  static const String prefSeparateVoices = 'separate_voices';

  // AI Default Settings
  static const int defaultAnalysisIntervalSec = 12;
  static const int maxTranscriptRollingBufferTokens = 4000;

  // Document Context Constants
  static const List<String> supportedDocumentExtensions = [
    'txt',
    'md',
    'pdf',
    'docx',
  ];
  static const int maxDocumentSizeBytes = 10 * 1024 * 1024; // 10 MB limit
  static const int documentChunkSize = 500;
  static const int maxDocumentContextChars = 1500;
  static const double documentRelevanceThreshold = 0.08;

  // Document graph retrieval
  static const int graphChunksPerBatch = 6;
  static const int graphMaxChunks = 60;
  static const int graphMaxNodes = 80;
  static const double graphNodeMergeSimilarity = 0.8;
  static const double graphSeedBoost = 0.5; // chunk mentions a node named in the transcript
  static const double graphNeighbourBoost = 0.25; // chunk mentions a node one hop from a seed
  static const double graphDocMatchScore = 0.12; // doc admitted when the graph finds seed nodes

  // Coaching indicator thresholds (heuristics, not clinical norms)
  static const double paceGoodMinWpm = 120;
  static const double paceGoodMaxWpm = 170;
  static const double paceOkMinWpm = 100;
  static const double paceOkMaxWpm = 190;
  static const double fillersGoodPerMin = 3;
  static const double fillersOkPerMin = 6;
  static const double monologueGoodSec = 60;
  static const double monologueOkSec = 90;
  static const double talkShareGoodBandPts = 15; // around the fair share 100/N
  static const double talkShareOkBandPts = 25;
  static const int interruptionsGood = 1;
  static const int interruptionsOk = 3;
  static const double responseGapGoodMaxSec = 1.5;
  static const double responseGapOkMaxSec = 3;
  static const double minTalkSecForRates = 10; // below this, per-minute rates are noise
  static const int baselineMeetings = 5; // "vs your last N meetings"
  static const int maxGoals = 3;
  static const int digestSinglePassChars = 30000; // longer meetings are analysed in parts
  static const int digestSegmentChars = 22000;

  // Coaching / participation analysis
  static const double turnMergeGapSec = 1.5; // same-speaker lines closer than this form one turn
  static const double interruptGapSec = 0.3; // a handover faster than this, mid-sentence, counts as an interruption

  // Channels
  static const String windowControlChannel = 'com.mitra.assistant/window_control';
  static const String audioCaptureChannel = 'com.mitra.assistant/audio_capture_control';
  static const String audioStreamChannel = 'com.mitra.assistant/audio_stream';
}

