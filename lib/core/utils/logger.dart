import 'package:flutter/foundation.dart';

class AppLogger {
  static void log(String message) {
    if (kDebugMode) {
      debugPrint('[MitraAssistant] $message');
    }
  }

  static void error(String message, [dynamic error]) {
    if (kDebugMode) {
      debugPrint('[MitraAssistant ERROR] $message ${error ?? ""}');
    }
  }
}
