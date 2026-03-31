import 'package:flutter/foundation.dart';

/// Manages a session-based set of user IDs that should be dismissed from suggestions.
class GlobalDismissState {
  static final ValueNotifier<Set<String>> dismissedUserIds = ValueNotifier<Set<String>>({});

  /// Dismisse a user globally from all suggestion lists for this session.
  static void dismiss(String userId) {
    final current = Set<String>.from(dismissedUserIds.value);
    if (current.add(userId)) {
      dismissedUserIds.value = current;
    }
  }

  /// Whether a user is currently dismissed.
  static bool isDismissed(String userId) {
    return dismissedUserIds.value.contains(userId);
  }
}
