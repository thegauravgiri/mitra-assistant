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

  // Channels
  static const String windowControlChannel = 'com.mitra.assistant/window_control';
  static const String audioCaptureChannel = 'com.mitra.assistant/audio_capture_control';
  static const String audioStreamChannel = 'com.mitra.assistant/audio_stream';
}

