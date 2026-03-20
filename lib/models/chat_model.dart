class ChatModel {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final Map<String, int> unreadCount;

  ChatModel({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.unreadCount,
  });

  factory ChatModel.fromMap(Map<String, dynamic> data, String id) {
    return ChatModel(
      id: id,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      unreadCount: Map<String, int>.from(data['unreadCount'] ?? {}),
    );
  }
}
