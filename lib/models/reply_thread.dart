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
}
