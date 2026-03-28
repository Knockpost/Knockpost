import 'user_model.dart';

enum NotificationType {
  like,        // Instagram style
  comment,     // Instagram style
  follow,      // Instagram style
  mention,     // Twitter/Substack style
  newPost,    // Substack style (article/thought published)
}

class NotificationModel {
  final String id;
  final NotificationType type;
  final UserModel triggerUser;
  final DateTime timestamp;
  final bool isRead;
  
  // Optional parameters depending on NotificationType
  final String? contentSnippet;  // For comments, mentions, newPost previews
  final String? postThumbnail;   // The thumbnail image of the post liked/commented on (Instagram style)
  final String? postTitle;       // The title of the article/thought (Substack style)

  const NotificationModel({
    required this.id,
    required this.type,
    required this.triggerUser,
    required this.timestamp,
    this.isRead = false,
    this.contentSnippet,
    this.postThumbnail,
    this.postTitle,
  });
}

// ─────────────────────────────────────────────
// Dummy Data
// ─────────────────────────────────────────────

List<NotificationModel> get dummyNotifications {
  final now = DateTime.now();
  
  return [
    NotificationModel(
      id: '1',
      type: NotificationType.newPost,
      triggerUser: demoZaynMalik,
      timestamp: now.subtract(const Duration(minutes: 5)),
      isRead: false,
      postTitle: 'The Future of Deep Tech',
      contentSnippet: 'Why artificial intelligence might fundamentally change how we interact with apps...',
    ),
    NotificationModel(
      id: '2',
      type: NotificationType.like,
      triggerUser: demoAryaLayek,
      timestamp: now.subtract(const Duration(minutes: 15)),
      isRead: false,
      postThumbnail: 'assets/test2.jpg',
    ),
    NotificationModel(
      id: '3',
      type: NotificationType.follow,
      triggerUser: demoJustinBieber,
      timestamp: now.subtract(const Duration(hours: 1)),
      isRead: true,
    ),
    NotificationModel(
      id: '4',
      type: NotificationType.comment,
      triggerUser: demoSaptarshiNayak,
      timestamp: now.subtract(const Duration(hours: 3)),
      isRead: true,
      contentSnippet: 'This is absolutely amazing! Can\'t wait to see more.',
      postThumbnail: 'assets/test1.jpg',
    ),
    NotificationModel(
      id: '5',
      type: NotificationType.newPost,
      triggerUser: demoAryaLayek,
      timestamp: now.subtract(const Duration(days: 1)),
      isRead: true,
      postTitle: 'Weekend Getaway Guide',
      contentSnippet: 'A comprehensive guide on how to spend your perfect weekend without burning your wallet.',
    ),
    NotificationModel(
      id: '6',
      type: NotificationType.mention,
      triggerUser: demoSaptarshiNayak,
      timestamp: now.subtract(const Duration(days: 2)),
      isRead: true,
      contentSnippet: 'Hey @suman, you really need to check out the new design system update!',
    ),
  ];
}
