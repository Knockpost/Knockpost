import 'package:flutter/foundation.dart';

/// Manages a session-based set of deleted post IDs.
class GlobalPostState {
  static final ValueNotifier<Set<String>> deletedPostIds = ValueNotifier<Set<String>>({});

  /// Deletes a post globally for this session.
  static void delete(String postId) {
    final current = Set<String>.from(deletedPostIds.value);
    if (current.add(postId)) {
      deletedPostIds.value = current;
    }
  }

  /// Whether a post is currently deleted.
  static bool isDeleted(String postId) {
    return deletedPostIds.value.contains(postId);
  }
}
