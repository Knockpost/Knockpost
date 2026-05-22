import 'package:flutter/foundation.dart';

class ChatLogger {
  ChatLogger._();
  static final ChatLogger instance = ChatLogger._();

  void info(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[INFO] [Chat][$tag] $message');
    }
  }

  void warning(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[WARN] [Chat][$tag] $message');
    }
  }

  void error(String tag, String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[ERROR] [Chat][$tag] $message');
      if (error != null) debugPrint('Exception: $error');
      if (stackTrace != null) debugPrint('Stack: $stackTrace');
    }
  }
}
