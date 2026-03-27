// KnockPost — Post Model

enum PostDuration {
  h24, // 24-hour post — stays in Recents for 3 days then disappears
  h36, // 36-hour post — stays in Recents for 3 days then disappears
  lifetime, // Lifetime post — stays in Recents for 3 days AND always in Showcase
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

  /// Whether this post is currently in the "Recents" window.
  /// All post types stay in Recents for 3 days (72 hours).
  bool get isInRecentsWindow {
    final age = DateTime.now().difference(createdAt);
    return age.inHours < 72; // 3-day window for all post types
  }

  /// Whether this post belongs in the Showcase section.
  /// Only lifetime posts belong in Showcase — they appear here permanently.
  /// Dynamic-time posts (24h / 36h) never go to Showcase.
  bool get isInShowcase => duration == PostDuration.lifetime;

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
];

List<PostModel> getDemoPostsForUser(String userId) {
  if (userId == 'leo01') return const [];
  if (userId == 'me') return demoOwnPosts;
  
  int seed;
  switch (userId) {
    case 'zayn01': seed = 1; break;
    case 'justin01': seed = 2; break;
    case 'suman01': seed = 3; break;
    case 'saptarshi01': seed = 4; break;
    case 'arya01': seed = 5; break;
    default: seed = userId.hashCode.abs() % 10 + 1; break;
  }
  
  final now = DateTime.now();
  const pool = [
    'assets/test1.jpg',
    'assets/test2.jpg',
    'assets/test3.jpg',
    'assets/test4.jpg',
  ];
  final first = pool[seed % pool.length];
  final second = pool[(seed + 1) % pool.length];

  return [
    PostModel(
      id: '${userId}_recent',
      authorId: userId,
      type: PostType.media,
      duration: PostDuration.h24,
      imagePaths: [first, second],
      text: 'Evening dump from today.',
      createdAt: now.subtract(Duration(hours: 2 + seed)),
      likes: 12 + seed * 3,
      views: 90 + seed * 12,
    ),
  ];
}
