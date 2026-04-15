// KnockPost — Post Model
import 'package:flutter/foundation.dart';

enum PostDuration {
  h24, // 24-hour post — stays in Recents for 3 days then disappears
  h36, // 36-hour post — stays in Recents for 3 days then disappears
  lifetime, // Lifetime post — stays in Recents for 3 days AND always in Showcase
}

enum PostType {
  media, // Image(s) — Post
  text, // Text-only — Thoughts
  glimps, // Photo + Music story — Glimps (Instagram Stories)
  waves, // Video up to 2m30s — Waves (Instagram Reels)
}

class PostModel {
  final String id;
  final String authorId;

  final PostType type;
  final PostDuration duration;

  final List<String> imagePaths; // empty for text posts
  final String text; // empty for media-only posts

  final String? musicUrl;
  final String? musicTitle;
  final String? musicArtist;

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
    this.musicUrl,
    this.musicTitle,
    this.musicArtist,
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

  /// Formatted timestamp for post cards
  String get timestampText {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago'; // e.g. 15m ago
    if (diff.inHours < 24) return '${diff.inHours}h ago'; // exactly as user requested
    if (diff.inDays < 7) return '${diff.inDays}d ago'; // e.g. 1d ago
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago'; // e.g. 1w ago
    
    // Older than ~a month, show date
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[createdAt.month - 1]} ${createdAt.day}, ${createdAt.year}';
  }

  PostModel copyWith({
    bool? isLikedByMe,
    int? likes,
    int? views,
    String? musicUrl,
    String? musicTitle,
    String? musicArtist,
  }) {
    return PostModel(
      id: id,
      authorId: authorId,
      type: type,
      duration: duration,
      imagePaths: imagePaths,
      text: text,
      musicUrl: musicUrl ?? this.musicUrl,
      musicTitle: musicTitle ?? this.musicTitle,
      musicArtist: musicArtist ?? this.musicArtist,
      createdAt: createdAt,
      likes: likes ?? this.likes,
      views: views ?? this.views,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
    );
  }
}

// ─── Demo posts ──────────────────────────────────────────────────────────────
final now = DateTime.now();

final ValueNotifier<List<PostModel>> demoOwnPostsNotifier = ValueNotifier<List<PostModel>>(demoOwnPosts);

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
    // Recents — 24h text-only post (Thought)
    PostModel(
      id: 'p3',
      authorId: 'me',
      type: PostType.text,
      duration: PostDuration.h24,
      imagePaths: const [],
      text: 'Sometimes you just have to log off and step outside. Life is beautiful when you actually look at it without a screen in the way. 🍃✨',
      createdAt: now.subtract(const Duration(hours: 15)),
      likes: 56,
      views: 120,
    ),
  // ── 24h Glimpse ────────────────────────────────────────────────────────
  PostModel(
    id: 'p_recent_glimpse',
    authorId: 'me',
    type: PostType.glimps,
    duration: PostDuration.h24,
    imagePaths: ['assets/test2.jpg'],
    text: '',
    createdAt: now.subtract(const Duration(hours: 12)),
    likes: 125,
    views: 890,
  ),

  // ── Showcase (lifetime) glimpses ─────────────────────────────────────────
  PostModel(
    id: 'p_show_glimpse1',
    authorId: 'me',
    type: PostType.glimps,
    duration: PostDuration.lifetime,
    imagePaths: ['assets/test3.jpg'],
    text: '',
    createdAt: now.subtract(const Duration(hours: 24)), // Shows in both Recents & Showcase
    likes: 210,
    views: 1200,
  ),
  PostModel(
    id: 'p_show_glimpse2',
    authorId: 'me',
    type: PostType.glimps,
    duration: PostDuration.lifetime,
    imagePaths: ['assets/test4.jpg'],
    text: '',
    createdAt: now.subtract(const Duration(days: 4)), // Only in Showcase
    likes: 450,
    views: 2400,
  ),
  PostModel(
    id: 'p_show_glimpse3',
    authorId: 'me',
    type: PostType.glimps,
    duration: PostDuration.lifetime,
    imagePaths: ['assets/test1.jpg'],
    text: '',
    createdAt: now.subtract(const Duration(days: 12)),
    likes: 520,
    views: 3100,
  ),
  PostModel(
    id: 'p_show_glimpse4',
    authorId: 'me',
    type: PostType.glimps,
    duration: PostDuration.lifetime,
    imagePaths: ['assets/test2.jpg'],
    text: '',
    createdAt: now.subtract(const Duration(days: 18)),
    likes: 315,
    views: 1850,
  ),
  PostModel(
    id: 'p_show_glimpse5',
    authorId: 'me',
    type: PostType.glimps,
    duration: PostDuration.lifetime,
    imagePaths: ['assets/test3.jpg'],
    text: '',
    createdAt: now.subtract(const Duration(days: 22)),
    likes: 280,
    views: 1900,
  ),
  PostModel(
    id: 'p_show_glimpse6',
    authorId: 'me',
    type: PostType.glimps,
    duration: PostDuration.lifetime,
    imagePaths: ['assets/test1.jpg'],
    text: '',
    createdAt: now.subtract(const Duration(days: 35)),
    likes: 670,
    views: 4500,
  ),

  // ── Showcase (lifetime) posts ────────────────────────────────────────────
  PostModel(
    id: 'p_show1',
    authorId: 'me',
    type: PostType.media,
    duration: PostDuration.lifetime,
    imagePaths: ['assets/test4.jpg', 'assets/test1.jpg'],
    text: 'This one stays forever 🖤',
    createdAt: now.subtract(const Duration(days: 14)),
    likes: 320,
    views: 1800,
  ),
  PostModel(
    id: 'p_show2',
    authorId: 'me',
    type: PostType.media,
    duration: PostDuration.lifetime,
    imagePaths: ['assets/test2.jpg'],
    text: 'Core memory unlocked ✨',
    createdAt: now.subtract(const Duration(days: 30)),
    likes: 185,
    views: 920,
  ),
  PostModel(
    id: 'p_show3',
    authorId: 'me',
    type: PostType.media,
    duration: PostDuration.lifetime,
    imagePaths: ['assets/test3.jpg', 'assets/test4.jpg', 'assets/test2.jpg'],
    text: 'Kolkata diaries 🌇',
    createdAt: now.subtract(const Duration(days: 60)),
    likes: 540,
    views: 3200,
  ),
    PostModel(
      id: 'p_show4',
      authorId: 'me',
      type: PostType.media,
      duration: PostDuration.lifetime,
      imagePaths: ['assets/test1.jpg'],
      text: 'First post on KnockPost 🚀',
      createdAt: now.subtract(const Duration(days: 120)),
      likes: 870,
      views: 5100,
    ),
    PostModel(
      id: 'p_show5',
      authorId: 'me',
      type: PostType.text,
      duration: PostDuration.lifetime,
      imagePaths: const [],
      text: 'Dreaming big since day one. 💭',
      createdAt: now.subtract(const Duration(days: 150)),
      likes: 310,
      views: 1400,
    ),
  ];

List<PostModel> getDemoPostsForUser(String userId) {
  if (userId == 'leo01') return const [];
  if (userId == 'me') return demoOwnPosts;
  
  final now = DateTime.now();
  
  if (userId == 'zayn01') {
    // Only 1 lifetime glimpse. No recents. No normal posts.
    return [
      PostModel(
        id: '${userId}_glimpse1',
        authorId: userId,
        type: PostType.glimps,
        duration: PostDuration.lifetime,
        imagePaths: ['assets/test1.jpg'],
        text: '',
        createdAt: now.subtract(const Duration(days: 10)),
        likes: 120, views: 500,
      ),
    ];
  }
  
  if (userId == 'justin01') {
    // Only glimpses (1 lifetime, 1 24h). No normal dashboard posts.
    return [
      PostModel(
        id: '${userId}_glimpse1',
        authorId: userId,
        type: PostType.glimps,
        duration: PostDuration.lifetime,
        imagePaths: ['assets/test3.jpg'],
        text: '',
        createdAt: now.subtract(const Duration(days: 5)),
        likes: 300, views: 1000,
      ),
      PostModel(
        id: '${userId}_glimpse2',
        authorId: userId,
        type: PostType.glimps,
        duration: PostDuration.h24,
        imagePaths: ['assets/test2.jpg'],
        text: '',
        createdAt: now.subtract(const Duration(hours: 5)),
        likes: 150, views: 800,
      ),
    ];
  }
  
  if (userId == 'suman01') {
    // Showcase has exactly 1 glimpse and 1 post. No recents.
    return [
      PostModel(
        id: '${userId}_glimpse1',
        authorId: userId,
        type: PostType.glimps,
        duration: PostDuration.lifetime,
        imagePaths: ['assets/test4.jpg'],
        text: '',
        createdAt: now.subtract(const Duration(days: 20)),
        likes: 400, views: 1500,
      ),
      PostModel(
        id: '${userId}_post1',
        authorId: userId,
        type: PostType.media,
        duration: PostDuration.lifetime,
        imagePaths: ['assets/test1.jpg'],
        text: 'Just a single memory.',
        createdAt: now.subtract(const Duration(days: 15)),
        likes: 250, views: 900,
      ),
    ];
  }

  // Fallback for saptarshi01, arya01
  int seed;
  switch (userId) {
    case 'saptarshi01': seed = 4; break;
    case 'arya01': seed = 5; break;
    default: seed = userId.hashCode.abs() % 10 + 1; break;
  }
  
  const pool = [
    'assets/test1.jpg',
    'assets/test2.jpg',
    'assets/test3.jpg',
    'assets/test4.jpg',
  ];
  final first = pool[seed % pool.length];
  final second = pool[(seed + 1) % pool.length];
  final third = pool[(seed + 2) % pool.length];

  return [
    // Glimpse (24h)
    PostModel(
      id: '${userId}_glimpse',
      authorId: userId,
      type: PostType.glimps,
      duration: PostDuration.h24,
      imagePaths: [second],
      text: 'Good vibes only ✨',
      musicTitle: 'Trending Track',
      createdAt: now.subtract(Duration(hours: 1 + seed)),
      likes: 85 + seed * 4,
      views: 400 + seed * 25,
    ),
    // Recent post
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
    // Showcase (lifetime) posts
    PostModel(
      id: '${userId}_show1',
      authorId: userId,
      type: PostType.media,
      duration: PostDuration.lifetime,
      imagePaths: [second, third],
      text: 'A moment worth keeping 💫',
      createdAt: now.subtract(Duration(days: 10 + seed * 3)),
      likes: 60 + seed * 15,
      views: 400 + seed * 50,
    ),
    PostModel(
      id: '${userId}_show2',
      authorId: userId,
      type: PostType.media,
      duration: PostDuration.lifetime,
      imagePaths: [third],
      text: 'Timeless vibes ✨',
      createdAt: now.subtract(Duration(days: 25 + seed * 5)),
      likes: 120 + seed * 20,
      views: 800 + seed * 80,
    ),
  ];
}

final List<PostModel> demoGlimpseFeed = [
  ...getDemoPostsForUser('arya01').where((p) => p.type == PostType.glimps),
  ...getDemoPostsForUser('saptarshi01').where((p) => p.type == PostType.glimps),
  ...getDemoPostsForUser('justin01').where((p) => p.type == PostType.glimps),
  ...getDemoPostsForUser('suman01').where((p) => p.type == PostType.glimps),
  ...getDemoPostsForUser('zayn01').where((p) => p.type == PostType.glimps),
];
