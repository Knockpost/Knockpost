import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../widgets/custom_in_app_notification.dart';
import '../main.dart';
import 'auth_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KNOCKPOST NOTIFICATION SERVICE v2.0
// ═══════════════════════════════════════════════════════════════════════════════
//
// Features:
//   • Deterministic document IDs for deduplication (same interaction = same doc)
//   • Smart re-trigger: only re-pushes when a previously read notification
//     gets a new interaction (not on every merge write)
//   • Batch-compatible for zero-latency notification creation
//   • Unread count stream for real-time badge updates
//   • Consistent human-style wording via NotificationModel.actionText()
//   • FCM token management with refresh handling
// ═══════════════════════════════════════════════════════════════════════════════

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // ── In-flight deduplication: prevents duplicate pushes from rapid taps ──
  final Set<String> _recentlySentIds = {};

  String? get _myUid => AuthService.instance.currentUser?.uid;

  CollectionReference _userNotifs(String uid) =>
      _db.collection('users').doc(uid).collection('notifications');

  // ═══════════════════════════════════════════════════════════════════════════
  // PUSH NOTIFICATION SETUP (FCM)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> initFCM() async {
    try {
      // 1. Request Permission
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      debugPrint('FCM permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // 2. Get and save FCM token
        await _saveToken();

        // 3. Listen for token refresh (critical for reliability)
        _fcm.onTokenRefresh.listen((newToken) async {
          debugPrint('FCM Token Refreshed');
          if (_myUid != null) {
            await _db.collection('users').doc(_myUid).update({
              'fcmToken': newToken,
            });
          }
        });

        // 4. Foreground notification presentation (iOS & Android 13+)
        await _fcm.setForegroundNotificationPresentationOptions(
          alert: false,  // We handle foreground display ourselves with our custom banner
          badge: true,
          sound: false,  // Our custom banner handles this
        );

        // 5. Foreground messages → show elegant in-app banner
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // 6. Background notification tap → navigate
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

        // 7. Terminated state → check if opened via notification
        RemoteMessage? initialMessage = await _fcm.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationTap(initialMessage);
        }
      } else {
        debugPrint('Notification permission denied');
      }
    } catch (e) {
      debugPrint("FCM Init error: $e");
    }
  }

  /// Save FCM token to Firestore. Called on init and app restart.
  Future<void> _saveToken() async {
    try {
      String? token = await _fcm.getToken();
      if (token != null && _myUid != null) {
        await _db.collection('users').doc(_myUid).update({
          'fcmToken': token,
        });
        debugPrint('FCM token saved');
      }
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Handle foreground FCM message — show custom in-app notification banner.
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message: ${message.data}');
    
    if (message.notification != null) {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        final type = message.data['type'] as String? ?? 'notification';
        final profileImageUrl = message.data['profileImageUrl'] as String?;
        
        CustomInAppNotification.show(
          context,
          title: message.notification!.title ?? 'knockpost',
          body: message.notification!.body ?? '',
          type: type,
          profileImageUrl: profileImageUrl,
          onTap: () {
            // Navigation based on notification type is handled by _handleNotificationTap
          },
        );
      }
    }
  }

  /// Handle notification tap (background/terminated) → navigate to relevant screen.
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.data}');
    // Navigation logic is handled at the app level
    // The notification data contains type, triggerUserId, postId
    // which the app can use to navigate to the correct screen
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // IN-APP NOTIFICATIONS (FIRESTORE STREAMS)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Real-time stream of all notifications for the current user.
  /// Ordered by timestamp descending. Used by NotificationsScreen.
  Stream<List<NotificationModel>> streamNotifications() {
    final uid = _myUid;
    if (uid == null) return const Stream.empty();

    return _userNotifs(uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) =>
                NotificationModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  /// Real-time stream of unread notification count.
  /// Used by the notification bell icon for the red dot badge.
  Stream<int> streamUnreadCount() {
    final uid = _myUid;
    if (uid == null) return const Stream.empty();

    return _userNotifs(uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // READ / UNREAD MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> markAsRead(String notificationId) async {
    final uid = _myUid;
    if (uid == null) return;
    try {
      await _userNotifs(uid).doc(notificationId).update({'isRead': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    final uid = _myUid;
    if (uid == null) return;
    try {
      final unreadSnap = await _userNotifs(uid)
          .where('isRead', isEqualTo: false)
          .get();
      
      if (unreadSnap.docs.isEmpty) return;

      final batch = _db.batch();
      for (final doc in unreadSnap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DELETE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> deleteNotification(String notificationId) async {
    final uid = _myUid;
    if (uid == null) return;
    try {
      await _userNotifs(uid).doc(notificationId).delete();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  Future<void> deleteSentNotification(String receiverUid, String docId) async {
    try {
      await _userNotifs(receiverUid).doc(docId).delete();
    } catch (e) {
      debugPrint('Error deleting sent notification: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SEND NOTIFICATION — with deduplication
  // ═══════════════════════════════════════════════════════════════════════════
  //
  // Deduplication strategy:
  //   • Each notification type + interaction pair gets a DETERMINISTIC document ID.
  //   • Like on post X by user Y → always doc "like_postX_userY"
  //   • This means repeated taps or retries overwrite the SAME document,
  //     and the Cloud Function's onCreate only fires ONCE per unique doc.
  //   • For repeated interactions (user unlikes then relikes), the merge-set
  //     updates the existing doc. The onUpdate Cloud Function handles this:
  //     it only re-pushes if the notification was previously read.
  //
  // ═══════════════════════════════════════════════════════════════════════════

  /// Generate a deterministic document ID for deduplication.
  String _generateDocId({
    required String triggerUid,
    required NotificationType type,
    String? postId,
  }) {
    switch (type) {
      case NotificationType.like:
        return postId != null ? 'like_${postId}_$triggerUid' : 'like_$triggerUid';
      case NotificationType.waveLike:
        return postId != null ? 'wavelike_${postId}_$triggerUid' : 'wavelike_$triggerUid';
      case NotificationType.knock:
      case NotificationType.knockAccept:
      case NotificationType.knockBack:
        return 'knock_$triggerUid';
      case NotificationType.message:
        return 'message_$triggerUid';
      case NotificationType.comment:
        // Group ALL consecutive comments from the same user into ONE notification.
        // Shows only the latest reply, preventing notification spam.
        return 'comment_${triggerUid}_${postId ?? "global"}';
      case NotificationType.mention:
        return postId != null ? 'mention_${postId}_$triggerUid' : 'mention_$triggerUid';
    }
  }

  /// Sends a notification to [receiverUid].
  /// Skips if [receiverUid] is the same as the current user.
  /// Uses deterministic doc IDs for deduplication.
  Future<void> sendNotification({
    required String receiverUid,
    required NotificationType type,
    String? postId,
    String? commentSnippet,
    String? postThumbnailUrl,
  }) async {
    final triggerUid = _myUid;
    if (triggerUid == null || triggerUid == receiverUid) return;

    // Generate deterministic ID
    final docId = _generateDocId(
      triggerUid: triggerUid,
      type: type,
      postId: postId,
    );

    // In-flight deduplication: prevent rapid duplicate sends
    if (_recentlySentIds.contains(docId)) return;
    _recentlySentIds.add(docId);
    // Remove from dedup set after 2 seconds to allow future sends
    Future.delayed(const Duration(seconds: 2), () {
      _recentlySentIds.remove(docId);
    });

    try {
      final notifRef = _userNotifs(receiverUid).doc(docId);

      final notif = NotificationModel(
        id: docId,
        type: type,
        triggerUserId: triggerUid,
        timestamp: DateTime.now(),
        isRead: false,
        postId: postId,
        commentSnippet: commentSnippet,
        postThumbnailUrl: postThumbnailUrl,
      );

      await notifRef.set(notif.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error sending notification: $e');
      _recentlySentIds.remove(docId);
    }
  }

  /// Adds a notification to an existing Firestore batch.
  /// Eliminates sequential network round trips for instant triggering.
  void sendNotificationInBatch(
    WriteBatch batch, {
    required String receiverUid,
    required NotificationType type,
    String? postId,
    String? commentSnippet,
    String? postThumbnailUrl,
  }) {
    final triggerUid = _myUid;
    if (triggerUid == null || triggerUid == receiverUid) return;

    final docId = _generateDocId(
      triggerUid: triggerUid,
      type: type,
      postId: postId,
    );

    final notifRef = _userNotifs(receiverUid).doc(docId);

    final notif = NotificationModel(
      id: docId,
      type: type,
      triggerUserId: triggerUid,
      timestamp: DateTime.now(),
      isRead: false,
      postId: postId,
      commentSnippet: commentSnippet,
      postThumbnailUrl: postThumbnailUrl,
    );

    batch.set(notifRef, notif.toMap(), SetOptions(merge: true));
  }

  /// Clean up old notifications (30+ days) — called once per session.
  Future<void> cleanupOldNotifications() async {
    final uid = _myUid;
    if (uid == null) return;

    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      final oldSnap = await _userNotifs(uid)
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoff))
          .get();

      if (oldSnap.docs.isEmpty) return;

      final batch = _db.batch();
      for (final doc in oldSnap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      debugPrint('Cleaned up ${oldSnap.docs.length} old notifications');
    } catch (e) {
      debugPrint('Error cleaning up old notifications: $e');
    }
  }
}
