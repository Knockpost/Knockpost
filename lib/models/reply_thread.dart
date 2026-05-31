import 'package:cloud_firestore/cloud_firestore.dart';

class ReplyThread {
  final String postId;
  final String authorId;
  final String userId;
  final String lastMessage;
  final DateTime lastTimestamp;
  final int unreadCount; // Legacy
  final int ownerUnreadCount;
  final int userUnreadCount;

  const ReplyThread({
    required this.postId,
    required this.authorId,
    required this.userId,
    required this.lastMessage,
    required this.lastTimestamp,
    this.unreadCount = 0,
    this.ownerUnreadCount = 0,
    this.userUnreadCount = 0,
  });

  String get id => '$postId::$userId';

  int getUnreadCountFor(String currentUserId) {
    if (currentUserId == authorId) {
      return ownerUnreadCount > 0 ? ownerUnreadCount : unreadCount;
    } else {
      return userUnreadCount > 0 ? userUnreadCount : unreadCount;
    }
  }

  ReplyThread copyWith({
    String? postId,
    String? authorId,
    String? userId,
    String? lastMessage,
    DateTime? lastTimestamp,
    int? unreadCount,
    int? ownerUnreadCount,
    int? userUnreadCount,
  }) {
    return ReplyThread(
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      userId: userId ?? this.userId,
      lastMessage: lastMessage ?? this.lastMessage,
      lastTimestamp: lastTimestamp ?? this.lastTimestamp,
      unreadCount: unreadCount ?? this.unreadCount,
      ownerUnreadCount: ownerUnreadCount ?? this.ownerUnreadCount,
      userUnreadCount: userUnreadCount ?? this.userUnreadCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'authorId': authorId,
      'userId': userId,
      'lastMessage': lastMessage,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'unreadCount': unreadCount,
      'ownerUnreadCount': ownerUnreadCount,
      'userUnreadCount': userUnreadCount,
    };
  }

  factory ReplyThread.fromMap(Map<String, dynamic> map) {
    DateTime parseTimestamp(dynamic ts) {
      if (ts is Timestamp) return ts.toDate();
      if (ts is int) return DateTime.fromMillisecondsSinceEpoch(ts);
      if (ts is String) return DateTime.tryParse(ts) ?? DateTime.now();
      return DateTime.now();
    }

    return ReplyThread(
      postId: map['postId'] ?? '',
      authorId: map['authorId'] ?? '',
      userId: map['userId'] ?? '',
      lastMessage: map['lastMessage'] ?? '',
      lastTimestamp: parseTimestamp(map['lastTimestamp']),
      unreadCount: map['unreadCount'] ?? 0,
      ownerUnreadCount: map['ownerUnreadCount'] ?? 0,
      userUnreadCount: map['userUnreadCount'] ?? 0,
    );
  }
}
