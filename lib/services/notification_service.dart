import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../widgets/custom_in_app_notification.dart';
import '../main.dart';
import 'auth_service.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  String? get _myUid => AuthService.instance.currentUser?.uid;

  CollectionReference _userNotifs(String uid) =>
      _db.collection('users').doc(uid).collection('notifications');

  // ─── Push Notifications Setup ─────────────────────────────────────────────

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
      
      debugPrint('User granted permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // 2. Get FCM token
        String? token = await _fcm.getToken();
        debugPrint('FCM Token: $token');
        if (token != null && _myUid != null) {
          // Save token to user profile
          await _db.collection('users').doc(_myUid).update({
            'fcmToken': token,
          });
        }

        // 3. Listen for token refresh
        _fcm.onTokenRefresh.listen((newToken) async {
          debugPrint('FCM Token Refreshed: $newToken');
          if (_myUid != null) {
            await _db.collection('users').doc(_myUid).update({
              'fcmToken': newToken,
            });
          }
        });

        // 4. Set foreground notification presentation options (iOS & Android 13+)
        await _fcm.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        // 5. Listen to foreground messages and show custom banner
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('Got a message whilst in the foreground: ${message.data}');
          debugPrint('Notification title: ${message.notification?.title}');
          debugPrint('Notification body: ${message.notification?.body}');
          
          if (message.notification != null) {
            final context = navigatorKey.currentContext;
            if (context != null && context.mounted) {
              final type = message.data['type'] as String? ?? 'notification';
              final profileImageUrl = message.data['profileImageUrl'] as String?;
              
              CustomInAppNotification.show(
                context,
                title: message.notification!.title ?? 'New Notification',
                body: message.notification!.body ?? '',
                type: type,
                profileImageUrl: profileImageUrl,
                onTap: () {
                  // Handle tap if needed
                },
              );
            }
          }
        });

        // 6. Handle notification tap when app is in background (but not killed)
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          debugPrint('Notification opened app: ${message.data}');
          // You can navigate to specific screen based on message.data here
        });

        // 7. Check if app was opened from a terminated state via notification
        RemoteMessage? initialMessage = await _fcm.getInitialMessage();
        if (initialMessage != null) {
          debugPrint('App opened from terminated state via notification: ${initialMessage.data}');
          // You can navigate to specific screen based on initialMessage.data here
        }
      } else {
        debugPrint('User declined or has not accepted notification permission');
      }
    } catch (e) {
      debugPrint("FCM Init error: $e");
    }
  }

  // ─── In-App Notifications (Firestore) ───────────────────────────────────

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

  Future<void> markAsRead(String notificationId) async {
    final uid = _myUid;
    if (uid == null) return;
    try {
      await _userNotifs(uid).doc(notificationId).update({'isRead': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

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

  Future<void> markAllAsRead() async {
    final uid = _myUid;
    if (uid == null) return;
    try {
      final unreadSnap = await _userNotifs(uid)
          .where('isRead', isEqualTo: false)
          .get();
      
      final batch = _db.batch();
      for (final doc in unreadSnap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  /// Sends a notification to [receiverUid].
  /// Ignores if [receiverUid] is the same as the current user.
  Future<void> sendNotification({
    required String receiverUid,
    required NotificationType type,
    String? postId,
    String? commentSnippet,
    String? postThumbnailUrl,
  }) async {
    final triggerUid = _myUid;
    if (triggerUid == null || triggerUid == receiverUid) return;

    try {
      // Create a specific ID to prevent duplicate like/knock spam
      String? docId;
      if (type == NotificationType.like && postId != null) {
        docId = 'like_${postId}_$triggerUid';
      } else if (type == NotificationType.knock || type == NotificationType.knockAccept || type == NotificationType.knockBack) {
        docId = 'knock_$triggerUid';
      } else if (type == NotificationType.message) {
        docId = 'message_$triggerUid'; // Update the same notification for consecutive messages
      } else if (type == NotificationType.comment && postId != null) {
        // SMART SYSTEM: Group ALL consecutive comments from the same user into ONE single notification.
        // It automatically selects and shows only the latest reply, preventing UI spam.
        docId = 'comment_$triggerUid'; 
      }

      final notifRef = docId != null 
          ? _userNotifs(receiverUid).doc(docId) 
          : _userNotifs(receiverUid).doc();

      final notif = NotificationModel(
        id: notifRef.id,
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
    }
  }

  /// Adds a notification to an existing Firestore batch.
  /// This eliminates sequential network round trips, ensuring notifications trigger instantly.
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

    String? docId;
    if (type == NotificationType.like && postId != null) {
      docId = 'like_${postId}_$triggerUid';
    } else if (type == NotificationType.knock) {
      docId = 'knock_$triggerUid';
    } else if (type == NotificationType.message) {
      docId = 'message_$triggerUid';
    } else if (type == NotificationType.comment && postId != null) {
      docId = 'comment_$triggerUid';
    }

    final notifRef = docId != null 
        ? _userNotifs(receiverUid).doc(docId) 
        : _userNotifs(receiverUid).doc();

    final notif = NotificationModel(
      id: notifRef.id,
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
}

