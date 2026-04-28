class ReplyThread {
  final String postId;
  final String authorId;
  final String userId;
  final String lastMessage;
  final DateTime lastTimestamp;
  final int unreadCount;

  const ReplyThread({
    required this.postId,
    required this.authorId,
    required this.userId,
    required this.lastMessage,
    required this.lastTimestamp,
    this.unreadCount = 0,
  });

  String get id => '$postId::$userId';

  ReplyThread copyWith({
    String? postId,
    String? authorId,
    String? userId,
    String? lastMessage,
    DateTime? lastTimestamp,
    int? unreadCount,
  }) {
    return ReplyThread(
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      userId: userId ?? this.userId,
      lastMessage: lastMessage ?? this.lastMessage,
      lastTimestamp: lastTimestamp ?? this.lastTimestamp,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'authorId': authorId,
      'userId': userId,
      'lastMessage': lastMessage,
      'lastTimestamp': lastTimestamp,
      'unreadCount': unreadCount,
    };
  }

  factory ReplyThread.fromMap(Map<String, dynamic> map) {
    return ReplyThread(
      postId: map['postId'] ?? '',
      authorId: map['authorId'] ?? '',
      userId: map['userId'] ?? '',
      lastMessage: map['lastMessage'] ?? '',
      lastTimestamp: (map['lastTimestamp'] as dynamic)?.toDate() ?? DateTime.now(),
      unreadCount: map['unreadCount'] ?? 0,
    );
  }
}
