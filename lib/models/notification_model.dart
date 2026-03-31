import 'user_model.dart';

// ─── Notification Types ──────────────────────────────────────────────────────

enum NotificationType {
  knock,    // Someone knocked on your post/profile
  like,     // Someone liked your knock
  comment,  // Someone commented on your knock
}

// ─── Model ───────────────────────────────────────────────────────────────────

class NotificationModel {
  final String id;
  final NotificationType type;
  final UserModel triggerUser;
  final DateTime timestamp;
  final bool isRead;

  // For like / comment: thumbnail of the post
  final String? postThumbnail;

  // For comment: the comment text preview
  final String? commentSnippet;

  // For Firebase: The unqiue ID of the post this notification is about
  final String? postId;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.triggerUser,
    required this.timestamp,
    this.isRead = false,
    this.postThumbnail,
    this.commentSnippet,
    this.postId,
  });
}

// ─── Dummy Data ───────────────────────────────────────────────────────────────

List<NotificationModel> get dummyNotifications {
  final now = DateTime.now();

  return [
    // ── This week ──────────────────────────────────────────────────────────
    NotificationModel(
      id: '1',
      type: NotificationType.like,
      triggerUser: demoAryaLayek,
      timestamp: now.subtract(const Duration(minutes: 3)),
      isRead: false,
      postThumbnail: 'assets/test2.jpg',
    ),
    NotificationModel(
      id: '2',
      type: NotificationType.knock,
      triggerUser: demoJustinBieber,
      timestamp: now.subtract(const Duration(minutes: 25)),
      isRead: false,
    ),
    NotificationModel(
      id: '3',
      type: NotificationType.comment,
      triggerUser: demoSaptarshiNayak,
      timestamp: now.subtract(const Duration(hours: 2)),
      isRead: false,
      commentSnippet: 'This is absolutely fire! 🔥',
      postThumbnail: 'assets/test1.jpg',
    ),
    NotificationModel(
      id: '4',
      type: NotificationType.like,
      triggerUser: demoZaynMalik,
      timestamp: now.subtract(const Duration(hours: 5)),
      isRead: true,
      postThumbnail: 'assets/test3.jpg',
    ),
    NotificationModel(
      id: '5',
      type: NotificationType.knock,
      triggerUser: demoSumanPatra,
      timestamp: now.subtract(const Duration(hours: 18)),
      isRead: true,
    ),
    // ── Earlier ────────────────────────────────────────────────────────────
    NotificationModel(
      id: '6',
      type: NotificationType.comment,
      triggerUser: demoLeonardoDiCaprio,
      timestamp: now.subtract(const Duration(days: 3)),
      isRead: true,
      commentSnippet: 'Love this perspective, really made me think.',
      postThumbnail: 'assets/test4.jpg',
    ),
    NotificationModel(
      id: '7',
      type: NotificationType.like,
      triggerUser: demoAryaLayek,
      timestamp: now.subtract(const Duration(days: 5)),
      isRead: true,
      postThumbnail: 'assets/test2.jpg',
    ),
    NotificationModel(
      id: '8',
      type: NotificationType.knock,
      triggerUser: demoZaynMalik,
      timestamp: now.subtract(const Duration(days: 7)),
      isRead: true,
    ),
  ];
}
