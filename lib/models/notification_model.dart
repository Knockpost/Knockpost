import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Notification Types ──────────────────────────────────────────────────────

enum NotificationType {
  knock,         // Someone knocked you or requested
  knockAccept,   // Someone approved your knock request
  knockBack,     // Someone knocked you back
  like,          // Someone liked your post
  comment,       // Someone commented/replied on your post
  message,       // Someone sent you a message
  mention,       // Someone mentioned you
  waveLike,      // Someone liked your Wave
}

// ─── Priority Levels ─────────────────────────────────────────────────────────

enum NotificationPriority {
  high,    // Instant push + vibration: knocks, messages, replies, mentions
  medium,  // Normal push: likes, wave interactions
  low,     // Silent/grouped: suggestions, milestones
}

// ─── Priority Mapping ────────────────────────────────────────────────────────

NotificationPriority priorityForType(NotificationType type) {
  switch (type) {
    case NotificationType.knock:
    case NotificationType.knockAccept:
    case NotificationType.knockBack:
    case NotificationType.message:
    case NotificationType.comment:
    case NotificationType.mention:
      return NotificationPriority.high;
    case NotificationType.like:
    case NotificationType.waveLike:
      return NotificationPriority.medium;
  }
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

  // For Firebase: The unique ID of the post this notification is about
  final String? postId;

  // Deduplication / grouping
  final int interactionCount; // How many interactions this notification groups

  // For Push Notification Backend Read Optimization (Phase N2)
  final String? triggerUserName;
  final String? triggerAvatarUrl;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.triggerUserId,
    required this.timestamp,
    this.isRead = false,
    this.postThumbnailUrl,
    this.commentSnippet,
    this.postId,
    this.interactionCount = 1,
    this.triggerUserName,
    this.triggerAvatarUrl,
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
      'interactionCount': interactionCount,
      if (triggerUserName != null) 'triggerUserName': triggerUserName,
      if (triggerAvatarUrl != null) 'triggerAvatarUrl': triggerAvatarUrl,
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
      interactionCount: map['interactionCount'] as int? ?? 1,
      triggerUserName: map['triggerUserName'] as String?,
      triggerAvatarUrl: map['triggerAvatarUrl'] as String?,
    );
  }

  /// Human-readable action text for this notification type.
  /// Used consistently across push notifications, in-app, and notification page.
  String actionText({String? knockConnectionStatus}) {
    switch (type) {
      case NotificationType.knock:
        if (knockConnectionStatus == 'pending') {
          return 'requested to knock you';
        }
        return 'knocked you';
      case NotificationType.knockAccept:
        return 'accepted your knock request';
      case NotificationType.knockBack:
        return 'knocked you back';
      case NotificationType.like:
        return 'liked your post';
      case NotificationType.comment:
        return 'replied on your post';
      case NotificationType.message:
        return 'sent you a message';
      case NotificationType.mention:
        return 'mentioned you';
      case NotificationType.waveLike:
        return 'liked your Wave';
    }
  }
}
