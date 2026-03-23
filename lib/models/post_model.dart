// KnockPost — Post Model

enum PostDuration {
  h24, // 24-hour post — stays in Recents for 24 hrs then disappears
  h36, // 36-hour post — stays in Recents for 36 hrs then disappears
  lifetime, // Lifetime post — stays in Recents for 24 hrs then moves to Showcase
}

enum PostType {
  media, // Image(s) / video
  text, // Text-only
}

class PostModel {
  final String id;
  final String authorId;

  final PostType type;
  final PostDuration duration;

  final List<String> imagePaths; // empty for text posts
  final String text; // empty for media-only posts

  final DateTime createdAt;
  final int likes;
  final int views;
  final bool isLikedByMe;

  const PostModel({
    required this.id,
    required this.authorId,
    required this.type,
    required this.duration,
    this.imagePaths = const [],
    this.text = '',
    required this.createdAt,
    this.likes = 0,
    this.views = 0,
    this.isLikedByMe = false,
  });

  /// Whether this post is currently in the "Recents" window
  bool get isInRecentsWindow {
    final age = DateTime.now().difference(createdAt);
    switch (duration) {
      case PostDuration.h24:
        return age.inHours < 24;
      case PostDuration.h36:
        return age.inHours < 36;
      case PostDuration.lifetime:
        // Lifetime posts show in Recents for their first 24 hours
        return age.inHours < 24;
    }
  }

  /// Whether this post belongs in the Showcase section
  bool get isInShowcase {
    if (duration != PostDuration.lifetime) return false;
    final age = DateTime.now().difference(createdAt);
    // After 24 hours it graduates from Recents to Showcase
    return age.inHours >= 24;
  }

  /// Friendly relative time label
  String get relativeTime {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  PostModel copyWith({
    bool? isLikedByMe,
    int? likes,
    int? views,
  }) {
    return PostModel(
      id: id,
      authorId: authorId,
      type: type,
      duration: duration,
      imagePaths: imagePaths,
      text: text,
      createdAt: createdAt,
      likes: likes ?? this.likes,
      views: views ?? this.views,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
    );
  }
}

// ─── Demo posts ──────────────────────────────────────────────────────────────
final now = DateTime.now();

final List<PostModel> demoOwnPosts = [
  // Recents — 24h media post (still fresh)
  PostModel(
    id: 'p1',
    authorId: 'me',
    type: PostType.media,
    duration: PostDuration.h24,
    imagePaths: ['assets/test1.jpg', 'assets/test2.jpg'],
    text: 'Golden hour was different today 🌅',
    createdAt: now.subtract(const Duration(hours: 3)),
    likes: 42,
    views: 210,
    isLikedByMe: false,
  ),
  // Recents — 36h media post
  PostModel(
    id: 'p2',
    authorId: 'me',
    type: PostType.media,
    duration: PostDuration.h36,
    imagePaths: ['assets/test3.jpg'],
    text: 'Morning run hits different 🏃',
    createdAt: now.subtract(const Duration(hours: 10)),
    likes: 18,
    views: 95,
    isLikedByMe: true,
  ),
  // Showcase — lifetime post (older than 24h)
  PostModel(
    id: 'p3',
    authorId: 'me',
    type: PostType.media,
    duration: PostDuration.lifetime,
    imagePaths: ['assets/test4.jpg'],
    text: 'From the archives 🗂',
    createdAt: now.subtract(const Duration(days: 5)),
    likes: 134,
    views: 820,
    isLikedByMe: false,
  ),
  PostModel(
    id: 'p4',
    authorId: 'me',
    type: PostType.media,
    duration: PostDuration.lifetime,
    imagePaths: ['assets/test2.jpg', 'assets/test3.jpg'],
    text: 'A weekend well spent',
    createdAt: now.subtract(const Duration(days: 12)),
    likes: 96,
    views: 430,
    isLikedByMe: true,
  ),
  PostModel(
    id: 'p5',
    authorId: 'me',
    type: PostType.media,
    duration: PostDuration.lifetime,
    imagePaths: ['assets/test1.jpg'],
    text: 'This view though 😮',
    createdAt: now.subtract(const Duration(days: 20)),
    likes: 211,
    views: 1100,
    isLikedByMe: false,
  ),
  // Text posts
  PostModel(
    id: 't1',
    authorId: 'me',
    type: PostType.text,
    duration: PostDuration.lifetime,
    text:
        'Found my new favourite line.\n\nThe moment I saw her, a part of me walked out of my body and never came back.',
    createdAt: now.subtract(const Duration(days: 2)),
    likes: 67,
    views: 320,
    isLikedByMe: false,
  ),
  PostModel(
    id: 't2',
    authorId: 'me',
    type: PostType.text,
    duration: PostDuration.lifetime,
    text:
        'Hot take: The best productivity hack is just making the thing you want to do feel impossible to procrastinate on.',
    createdAt: now.subtract(const Duration(days: 8)),
    likes: 88,
    views: 540,
    isLikedByMe: true,
  ),
  PostModel(
    id: 't3',
    authorId: 'me',
    type: PostType.text,
    duration: PostDuration.h24,
    text:
        'Today was weirdly good. The kind of day you want to save somewhere safe.',
    createdAt: now.subtract(const Duration(hours: 5)),
    likes: 14,
    views: 72,
    isLikedByMe: false,
  ),
];
