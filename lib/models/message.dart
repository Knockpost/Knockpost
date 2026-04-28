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

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'postId': postId,
      'text': text,
      'timestamp': timestamp,
    };
  }

  factory ReplyMessage.fromMap(Map<String, dynamic> map, String documentId) {
    return ReplyMessage(
      id: documentId,
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      postId: map['postId'] ?? '',
      text: map['text'] ?? '',
      timestamp: (map['timestamp'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }
}
