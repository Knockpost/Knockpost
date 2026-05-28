const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");
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

// ─── Email OTP 2FA ────────────────────────────────────────────

const gmailTransporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.GMAIL_EMAIL || "knockpostofficial@gmail.com",
    pass: process.env.GMAIL_PASSWORD || "",
  },
});

/**
 * sendOtp — Callable function that generates a 6-digit OTP,
 * saves it in Firestore, and emails it to the user.
 */
exports.sendOtp = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "You must be logged in.");
  }

  const uid = context.auth.uid;
  const userDoc = await admin.firestore().collection("users").doc(uid).get();

  if (!userDoc.exists) {
    throw new functions.https.HttpsError("not-found", "User not found.");
  }

  const email = context.auth.token.email;
  if (!email) {
    throw new functions.https.HttpsError("failed-precondition", "No email associated with this account.");
  }

  // Generate 6-digit OTP
  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  const expiresAt = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + 5 * 60 * 1000) // 5 minutes
  );

  // Save OTP in Firestore
  await admin.firestore().collection("users").doc(uid).collection("otp").doc("current").set({
    code: otp,
    expiresAt: expiresAt,
    verified: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Send email
  const mailOptions = {
    from: `"Knockpost" <${process.env.GMAIL_EMAIL || "knockpostofficial@gmail.com"}>`,
    to: email,
    subject: "Your Knockpost Verification Code",
    html: `
      <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 480px; margin: 0 auto; padding: 32px;">
        <div style="text-align: center; margin-bottom: 32px;">
          <h1 style="color: #1a1a1a; font-size: 24px; margin-bottom: 8px;">Knockpost</h1>
          <p style="color: #666; font-size: 14px;">Two-Step Verification</p>
        </div>
        <div style="background: #f8f8f8; border-radius: 12px; padding: 24px; text-align: center;">
          <p style="color: #333; font-size: 14px; margin-bottom: 16px;">Your verification code is:</p>
          <div style="font-size: 36px; font-weight: 700; letter-spacing: 8px; color: #1a1a1a; margin-bottom: 16px;">${otp}</div>
          <p style="color: #999; font-size: 12px;">This code will expire in 5 minutes.</p>
        </div>
        <p style="color: #999; font-size: 12px; text-align: center; margin-top: 24px;">
          If you didn't request this code, please ignore this email.
        </p>
      </div>
    `,
  };

  try {
    await gmailTransporter.sendMail(mailOptions);
    return { success: true, message: "OTP sent to your email." };
  } catch (error) {
    console.error("Error sending OTP email:", error);
    throw new functions.https.HttpsError("internal", "Failed to send OTP email.");
  }
});

/**
 * verifyOtp — Callable function that verifies the user's OTP.
 */
exports.verifyOtp = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "You must be logged in.");
  }

  const uid = context.auth.uid;
  const { code } = data;

  if (!code || typeof code !== "string" || code.length !== 6) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid OTP format.");
  }

  const otpDoc = await admin.firestore().collection("users").doc(uid).collection("otp").doc("current").get();

  if (!otpDoc.exists) {
    throw new functions.https.HttpsError("not-found", "No OTP found. Please request a new one.");
  }

  const otpData = otpDoc.data();
  const now = admin.firestore.Timestamp.now();

  // Check expiry
  if (otpData.expiresAt.toMillis() < now.toMillis()) {
    await otpDoc.ref.delete();
    throw new functions.https.HttpsError("deadline-exceeded", "OTP has expired. Please request a new one.");
  }

  // Check code
  if (otpData.code !== code) {
    throw new functions.https.HttpsError("permission-denied", "Incorrect OTP.");
  }

  // Mark as verified and delete
  await otpDoc.ref.delete();

  return { success: true, message: "OTP verified successfully." };
});

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

    // ── Guard: Ensure this is a GENUINE new interaction from the client ──
    // The client always updates the `timestamp` field with FieldValue.serverTimestamp()
    // on every new interaction. If the timestamp hasn't changed (e.g., just `isRead: true`
    // or our own `pushSent: true` update), we safely ignore it.
    const beforeTime = beforeData.timestamp ? beforeData.timestamp.toMillis() : 0;
    const afterTime = afterData.timestamp ? afterData.timestamp.toMillis() : 0;

    if (afterTime <= beforeTime) {
      console.log(`Update for ${notificationId}: timestamp unchanged (not a new interaction). Skipping.`);
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

// ═══════════════════════════════════════════════════════════════════════════════
// DAILY GLIMPSE CLEANUP
// ═══════════════════════════════════════════════════════════════════════════════

exports.cleanupExpiredGlimpses = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    console.log("Starting daily glimpse cleanup...");
    
    // Calculate cutoff times
    const now = new Date();
    
    const cutoff24h = new Date(now.getTime() - (24 * 60 * 60 * 1000));
    const cutoff36h = new Date(now.getTime() - (36 * 60 * 60 * 1000));

    let deletedCount = 0;

    try {
      const glimpsesSnapshot = await db.collection("posts")
        .where("type", "==", "glimps")
        .get();

      // We can't reuse the same batch object for more than 500 ops.
      // So we commit and create a new one.
      let batch = db.batch();
      let batchCount = 0;

      for (const doc of glimpsesSnapshot.docs) {
        const data = doc.data();
        if (!data.createdAt || !data.duration) continue;

        const createdAt = data.createdAt.toDate();
        let isExpired = false;

        switch (data.duration) {
          case "h24":
            isExpired = createdAt < cutoff24h;
            break;
          case "h36":
            isExpired = createdAt < cutoff36h;
            break;
          case "lifetime":
            isExpired = false;
            break;
        }

        if (isExpired) {
          batch.delete(doc.ref);
          batchCount++;
          deletedCount++;
        }

        if (batchCount === 490) {
          await batch.commit();
          batch = db.batch();
          batchCount = 0;
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }

      console.log(`Daily glimpse cleanup finished. Deleted ${deletedCount} expired glimpses.`);
    } catch (error) {
      console.error("Error during glimpse cleanup:", error);
    }
    
    return null;
  });
