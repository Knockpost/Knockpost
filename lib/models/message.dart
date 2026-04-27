class ReplyMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String postId;
  final String text;
  final DateTime timestamp;

  const ReplyMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.postId,
    required this.text,
    required this.timestamp,
  });

  ReplyMessage copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? postId,
    String? text,
    DateTime? timestamp,
  }) {
    return ReplyMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      postId: postId ?? this.postId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
