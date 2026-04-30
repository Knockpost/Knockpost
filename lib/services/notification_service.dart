import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
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

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // 2. Get FCM token
        String? token = await _fcm.getToken();
        debugPrint('FCM Token: $token');
        if (token != null && _myUid != null) {
          // Save token to user profile
          await _db.collection('users').doc(_myUid).update({
            'fcmToken': token,
          });
        }

        // 3. Listen to foreground messages (Optional: show local notification)
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('Got a message whilst in the foreground!');
          debugPrint('Message data: ${message.data}');
          if (message.notification != null) {
            debugPrint('Message also contained a notification: ${message.notification}');
          }
        });
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
      // For comment, we let it be auto-generated so multiple comments notify multiple times
      String? docId;
      if (type == NotificationType.like && postId != null) {
        docId = 'like_${postId}_$triggerUid';
      } else if (type == NotificationType.knock) {
        docId = 'knock_$triggerUid';
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
}
