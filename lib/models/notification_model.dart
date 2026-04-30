import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Notification Types ──────────────────────────────────────────────────────

enum NotificationType {
  knock,    // Someone knocked on your post/profile
  like,     // Someone liked your post
  comment,  // Someone commented on your post
}

// ─── Model ───────────────────────────────────────────────────────────────────

class NotificationModel {
  final String id;
  final NotificationType type;
  final String triggerUserId; // The UID of the person who caused this
  final DateTime timestamp;
  final bool isRead;

  // For like / comment: thumbnail of the post
  final String? postThumbnailUrl;

  // For comment: the comment text preview
  final String? commentSnippet;

  // For Firebase: The unqiue ID of the post this notification is about
  final String? postId;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.triggerUserId,
    required this.timestamp,
    this.isRead = false,
    this.postThumbnailUrl,
    this.commentSnippet,
    this.postId,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'triggerUserId': triggerUserId,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': isRead,
      if (postThumbnailUrl != null) 'postThumbnailUrl': postThumbnailUrl,
      if (commentSnippet != null) 'commentSnippet': commentSnippet,
      if (postId != null) 'postId': postId,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map, String docId) {
    NotificationType nType = NotificationType.knock;
    try {
      nType = NotificationType.values.byName(map['type'] ?? 'knock');
    } catch (_) {}

    return NotificationModel(
      id: docId,
      type: nType,
      triggerUserId: map['triggerUserId'] as String? ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] as bool? ?? false,
      postThumbnailUrl: map['postThumbnailUrl'] as String?,
      commentSnippet: map['commentSnippet'] as String?,
      postId: map['postId'] as String?,
    );
  }
}
