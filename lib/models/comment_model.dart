/// Comment model for Knockpost's private 2-sided comment system.
///
/// Each viewer's comments are only visible to the poster + that viewer.
/// The poster can see ALL viewers' comments.
class Comment {
  final String id;
  final String text;
  final String authorUsername;
  final bool isPostOwner;
  final String? replyToId; // null = top-level comment
  final DateTime timestamp;

  Comment({
    required this.id,
    required this.text,
    required this.authorUsername,
    required this.isPostOwner,
    this.replyToId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Generate demo comments for prototype
List<Comment> generateDemoComments() {
  final now = DateTime.now();
  return [
    Comment(
      id: 'c1',
      text: 'This is absolutely beautiful! Where was this taken?',
      authorUsername: 'you',
      isPostOwner: false,
      timestamp: now.subtract(const Duration(hours: 2)),
    ),
    Comment(
      id: 'c2',
      text: 'Thank you! It was taken in Shimla during sunset 🌅',
      authorUsername: 'poster_user',
      isPostOwner: true,
      replyToId: 'c1',
      timestamp: now.subtract(const Duration(hours: 1, minutes: 45)),
    ),
    Comment(
      id: 'c3',
      text: 'The colors in this are incredible',
      authorUsername: 'you',
      isPostOwner: false,
      timestamp: now.subtract(const Duration(minutes: 30)),
    ),
  ];
}
