const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();

// ═══════════════════════════════════════════════════════════════════════════════
// KNOCKPOST PUSH NOTIFICATION ENGINE v2.0
// ═══════════════════════════════════════════════════════════════════════════════
//
// Architecture:
//   • Triggered on document CREATE only (not onWrite) — eliminates duplicate
//     pushes from markAsRead updates, merge writes, and field patches.
//   • Human-quality wording: "knocked you", "liked your post" — never robotic.
//   • Priority-based Android channels: high/medium/low.
//   • Deduplication: skips if pushSent flag already true (idempotent).
//   • Multi-device: supports fcmTokens array for future scaling.
//   • Stale token cleanup on delivery failure.
// ═══════════════════════════════════════════════════════════════════════════════

// ── Priority Mapping ─────────────────────────────────────────────────────────

const PRIORITY_CONFIG = {
  // HIGH: instant push + vibration + sound
  knock:       { priority: "high", channelId: "knockpost_high",   sound: true },
  knockAccept: { priority: "high", channelId: "knockpost_high",   sound: true },
  knockBack:   { priority: "high", channelId: "knockpost_high",   sound: true },
  message:     { priority: "high", channelId: "knockpost_high",   sound: true },
  comment:     { priority: "high", channelId: "knockpost_high",   sound: true },
  mention:     { priority: "high", channelId: "knockpost_high",   sound: true },
  // MEDIUM: normal push
  like:        { priority: "high", channelId: "knockpost_medium", sound: true },
  waveLike:    { priority: "high", channelId: "knockpost_medium", sound: true },
  // LOW: silent/grouped
  suggestion:  { priority: "normal", channelId: "knockpost_low",  sound: false },
  milestone:   { priority: "normal", channelId: "knockpost_low",  sound: false },
};

// ── Human-Style Notification Wording ─────────────────────────────────────────

function buildNotificationContent(type, senderName, data) {
  switch (type) {
    case "knock":
      // Check if this is a pending request or direct knock
      if (data.isPendingRequest === true) {
        return {
          title: "knockpost",
          body: `${senderName} requested to knock you`,
        };
      }
      return {
        title: "knockpost",
        body: `${senderName} knocked you`,
      };

    case "knockAccept":
      return {
        title: "knockpost",
        body: `${senderName} accepted your knock request`,
      };

    case "knockBack":
      return {
        title: "knockpost",
        body: `${senderName} knocked you back`,
      };

    case "like":
      return {
        title: "knockpost",
        body: `${senderName} liked your post`,
      };

    case "waveLike":
      return {
        title: "knockpost",
        body: `${senderName} liked your Wave`,
      };

    case "comment": {
      const snippet = data.commentSnippet || "";
      if (snippet) {
        return {
          title: "knockpost",
          body: `${senderName} replied on your post: "${snippet}"`,
        };
      }
      return {
        title: "knockpost",
        body: `${senderName} replied on your post`,
      };
    }

    case "mention":
      return {
        title: "knockpost",
        body: `${senderName} mentioned you`,
      };

    case "message": {
      const msgSnippet = data.commentSnippet || "";
      if (msgSnippet) {
        return {
          title: senderName,
          body: msgSnippet,
        };
      }
      return {
        title: senderName,
        body: "sent you a message",
      };
    }

    default:
      return {
        title: "knockpost",
        body: `${senderName} interacted with you`,
      };
  }
}

// ── Main Cloud Function ──────────────────────────────────────────────────────

exports.sendPushNotification = functions.firestore
  .document("users/{userId}/notifications/{notificationId}")
  .onCreate(async (snapshot, context) => {
    const notificationData = snapshot.data();
    const receiverId = context.params.userId;
    const notificationId = context.params.notificationId;
    const triggerUserId = notificationData.triggerUserId;

    // ── Guard: Don't send notification to self ──
    if (receiverId === triggerUserId) {
      console.log("Self-notification. Skipping.");
      return null;
    }

    // ── Guard: Already processed (idempotent safety) ──
    if (notificationData.pushSent === true) {
      console.log(`Push already sent for ${notificationId}. Skipping.`);
      return null;
    }

    // ── Guard: Already read (race condition safety) ──
    if (notificationData.isRead === true) {
      console.log("Notification already read. Skipping push.");
      return null;
    }

    try {
      // ── Fetch receiver + sender profiles in parallel ──
      const [userDoc, triggerUserDoc] = await Promise.all([
        db.collection("users").doc(receiverId).get(),
        db.collection("users").doc(triggerUserId).get(),
      ]);

      if (!userDoc.exists) {
        console.log(`Receiver ${receiverId} not found.`);
        return null;
      }

      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;

      if (!fcmToken) {
        console.log(`No FCM token for ${receiverId}.`);
        return null;
      }

      // ── Build sender info ──
      const triggerUserData = triggerUserDoc.exists ? triggerUserDoc.data() : {};
      const senderName = triggerUserData.username || triggerUserData.displayName || "Someone";
      const profileImageUrl = triggerUserData.avatarUrl || triggerUserData.profileImageUrl || "";

      // ── Determine notification type and check for pending knock request ──
      const type = notificationData.type || "unknown";
      let enrichedData = { ...notificationData };

      if (type === "knock") {
        try {
          const connectionDoc = await db
            .collection("connections")
            .doc(`${triggerUserId}_${receiverId}`)
            .get();
          if (connectionDoc.exists && connectionDoc.data().status === "pending") {
            enrichedData.isPendingRequest = true;
          }
        } catch (err) {
          console.error("Error checking connection status:", err);
        }
      }

      // ── Build human-style content ──
      const content = buildNotificationContent(type, senderName, enrichedData);

      // ── Priority config ──
      const config = PRIORITY_CONFIG[type] || PRIORITY_CONFIG.like;

      // ── Build FCM payload ──
      const payload = {
        notification: {
          title: content.title,
          body: content.body,
        },
        data: {
          type: type,
          triggerUserId: triggerUserId || "",
          postId: notificationData.postId || "",
          notificationId: notificationId,
          profileImageUrl: profileImageUrl,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: config.priority,
          notification: {
            channelId: config.channelId,
            priority: config.priority === "high" ? "max" : "default",
            defaultSound: config.sound,
            defaultVibrateTimings: config.sound,
            icon: "ic_notification",
            // Group notifications by type for smart stacking
            tag: `${type}_${notificationData.postId || triggerUserId}`,
          },
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title: content.title,
                body: content.body,
              },
              sound: config.sound ? "default" : null,
              badge: 1,
              "mutable-content": 1,
              "thread-id": type,
            },
          },
        },
        token: fcmToken,
      };

      // ── Send push ──
      const response = await admin.messaging().send(payload);
      console.log(`✓ Push sent to ${receiverId} [${type}]:`, response);

      // ── Mark as pushSent (idempotent flag) ──
      await snapshot.ref.update({ pushSent: true });

    } catch (error) {
      console.error(`✗ Push failed for ${receiverId}:`, error);

      // ── Stale token cleanup ──
      if (
        error.code === "messaging/invalid-registration-token" ||
        error.code === "messaging/registration-token-not-registered"
      ) {
        console.log(`Removing stale FCM token for ${receiverId}`);
        await db.collection("users").doc(receiverId).update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
      }
    }

    return null;
  });

// ═══════════════════════════════════════════════════════════════════════════════
// NOTIFICATION UPDATE HANDLER
// ═══════════════════════════════════════════════════════════════════════════════
// Handles document UPDATES (e.g., when a notification doc is overwritten via
// merge-set for deduplication). Only sends a push if the notification was
// previously read (isRead was true) and is now unread again — indicating a
// genuinely new interaction that the user should know about.
// ═══════════════════════════════════════════════════════════════════════════════

exports.sendPushOnNotificationUpdate = functions.firestore
  .document("users/{userId}/notifications/{notificationId}")
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const receiverId = context.params.userId;
    const notificationId = context.params.notificationId;
    const triggerUserId = afterData.triggerUserId;

    // ── Guard: Don't send notification to self ──
    if (receiverId === triggerUserId) return null;

    // ── Guard: Only re-push if the notification was PREVIOUSLY READ and is now UNREAD ──
    // This handles the case where a user already read a notification,
    // but then the same person interacts again (e.g., sends another comment).
    // The merge-set resets isRead to false, and this triggers a new push.
    if (!(beforeData.isRead === true && afterData.isRead === false)) {
      console.log(`Update for ${notificationId}: not a re-trigger. Skipping.`);
      return null;
    }

    // ── Guard: Skip if just marked as read (no content change) ──
    if (beforeData.isRead === false && afterData.isRead === true) {
      return null;
    }

    try {
      // ── Fetch receiver + sender profiles in parallel ──
      const [userDoc, triggerUserDoc] = await Promise.all([
        db.collection("users").doc(receiverId).get(),
        db.collection("users").doc(triggerUserId).get(),
      ]);

      if (!userDoc.exists) return null;

      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;
      if (!fcmToken) return null;

      const triggerUserData = triggerUserDoc.exists ? triggerUserDoc.data() : {};
      const senderName = triggerUserData.username || triggerUserData.displayName || "Someone";
      const profileImageUrl = triggerUserData.avatarUrl || triggerUserData.profileImageUrl || "";

      const type = afterData.type || "unknown";
      let enrichedData = { ...afterData };

      if (type === "knock") {
        try {
          const connectionDoc = await db
            .collection("connections")
            .doc(`${triggerUserId}_${receiverId}`)
            .get();
          if (connectionDoc.exists && connectionDoc.data().status === "pending") {
            enrichedData.isPendingRequest = true;
          }
        } catch (err) {
          console.error("Error checking connection status:", err);
        }
      }

      const content = buildNotificationContent(type, senderName, enrichedData);
      const config = PRIORITY_CONFIG[type] || PRIORITY_CONFIG.like;

      const payload = {
        notification: {
          title: content.title,
          body: content.body,
        },
        data: {
          type: type,
          triggerUserId: triggerUserId || "",
          postId: afterData.postId || "",
          notificationId: notificationId,
          profileImageUrl: profileImageUrl,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: config.priority,
          notification: {
            channelId: config.channelId,
            priority: config.priority === "high" ? "max" : "default",
            defaultSound: config.sound,
            defaultVibrateTimings: config.sound,
            icon: "ic_notification",
            tag: `${type}_${afterData.postId || triggerUserId}`,
          },
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title: content.title,
                body: content.body,
              },
              sound: config.sound ? "default" : null,
              badge: 1,
              "mutable-content": 1,
              "thread-id": type,
            },
          },
        },
        token: fcmToken,
      };

      const response = await admin.messaging().send(payload);
      console.log(`✓ Re-push sent to ${receiverId} [${type}]:`, response);

      // Mark pushSent
      await change.after.ref.update({ pushSent: true });

    } catch (error) {
      console.error(`✗ Re-push failed for ${receiverId}:`, error);

      if (
        error.code === "messaging/invalid-registration-token" ||
        error.code === "messaging/registration-token-not-registered"
      ) {
        await db.collection("users").doc(receiverId).update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
      }
    }

    return null;
  });
