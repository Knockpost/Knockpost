/// Comment model for KnockPost's private 2-sided comment system.
///
/// Each viewer's comments are only visible to the poster + that viewer.
/// The poster can see ALL viewers' comments.
class CommentModel {
  final String id;
  final String text;
  final String authorId;
  final String authorUsername;
  final String? replyToId; // null = top-level comment
  final DateTime timestamp;

  CommentModel({
    required this.id,
    required this.text,
    required this.authorId,
    required this.authorUsername,
    this.replyToId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'authorId': authorId,
      'authorUsername': authorUsername,
      'replyToId': replyToId,
      'timestamp': timestamp,
    };
  }

  factory CommentModel.fromMap(Map<String, dynamic> map, String documentId) {
    return CommentModel(
      id: documentId,
      text: map['text'] ?? '',
      authorId: map['authorId'] ?? '',
      authorUsername: map['authorUsername'] ?? '',
      replyToId: map['replyToId'],
      timestamp: (map['timestamp'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Generate demo comments for prototype
List<CommentModel> generateDemoComments() {
  final now = DateTime.now();
  return [
    CommentModel(
      id: 'c1',
      text: 'This is absolutely beautiful! Where was this taken?',
      authorUsername: 'you',
      authorId: 'me',
      timestamp: now.subtract(const Duration(hours: 2)),
    ),
    CommentModel(
      id: 'c2',
      text: 'Thank you! It was taken in Shimla during sunset 🌅',
      authorUsername: 'poster_user',
      authorId: 'poster123',
      replyToId: 'c1',
      timestamp: now.subtract(const Duration(hours: 1, minutes: 45)),
    ),
    CommentModel(
      id: 'c3',
      text: 'The colors in this are incredible',
      authorUsername: 'you',
      authorId: 'me',
      timestamp: now.subtract(const Duration(minutes: 30)),
    ),
  ];
}
