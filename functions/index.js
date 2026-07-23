const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");
const crypto = require("crypto");
const sharp = require("sharp");
const { v4: uuidv4 } = require("uuid");
const path = require("path");
const os = require("os");
const fs = require("fs");
admin.initializeApp();

const db = admin.firestore();

// ── Phase 1 Security Utilities ──
const { recalculateCreatorRank } = require("./utils/rankCalculator");
const { sendNotification, deleteNotification } = require("./utils/notificationSender");
const { cascadeDeleteUser } = require("./utils/cascadeDelete");

// ─── Phase S2 Sharing Fan-Out ────────────────────────────────────────────────

exports.sharePostToConnections = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "You must be logged in.");
  }

  const senderId = context.auth.uid;
  const { text, recipientUids } = data;

  if (!text || !recipientUids || !Array.isArray(recipientUids)) {
    throw new functions.https.HttpsError("invalid-argument", "Missing text or recipientUids array.");
  }

  if (recipientUids.length > 2500) {
    throw new functions.https.HttpsError("resource-exhausted", "Too many recipients (max 2500).");
  }
  if (recipientUids.length === 0) {
    return { success: true, count: 0 };
  }

  const userDoc = await db.collection("users").doc(senderId).get();
  if (!userDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Sender user not found.");
  }
  const userData = userDoc.data();
  const triggerUserName = userData.displayName || userData.username || "Someone";
  const triggerAvatarUrl = userData.profileImageUrl || "";

  // ── S4 Anti-Abuse Rate Limiting ──
  // Check rate limit: Max 3 shares per minute per user.
  const rateLimitRef = db.collection("rate_limits").doc(`share_${senderId}`);
  await db.runTransaction(async (transaction) => {
    const rlDoc = await transaction.get(rateLimitRef);
    const now = admin.firestore.Timestamp.now();
    let attempts = 1;
    if (rlDoc.exists) {
      const rlData = rlDoc.data();
      const oneMinuteAgo = now.toMillis() - (60 * 1000);
      if (rlData.lastAttempt.toMillis() > oneMinuteAgo) {
        attempts = (rlData.attempts || 0) + 1;
        if (attempts > 3) {
          throw new functions.https.HttpsError("resource-exhausted", "Too many shares. Please wait a minute.");
        }
      }
    }
    transaction.set(rateLimitRef, { attempts: attempts, lastAttempt: now });
  });

  // 4 operations per recipient (message, chat meta, notification, user badge). Max batch size is 500.
  const CHUNK_SIZE = 120;
  const chunks = [];
  for (let i = 0; i < recipientUids.length; i += CHUNK_SIZE) {
    chunks.push(recipientUids.slice(i, i + CHUNK_SIZE));
  }

  const getChatId = (uid1, uid2) => {
    return uid1 < uid2 ? `${uid1}_${uid2}` : `${uid2}_${uid1}`;
  };

  const promises = chunks.map(async (chunk) => {
    const batch = db.batch();
    const timestamp = admin.firestore.FieldValue.serverTimestamp();
    const now = new Date();

    chunk.forEach((recipientId) => {
      if (recipientId === senderId) return;

      const chatId = getChatId(senderId, recipientId);
      const chatRef = db.collection("chats").doc(chatId);
      const msgRef = chatRef.collection("messages").doc(); 

      // 1. Message Doc
      batch.set(msgRef, {
        senderId: senderId,
        text: text,
        timestamp: timestamp,
        seen: false,
        status: "sent",
        clientId: msgRef.id,
      });

      let snippet = text;
      if (snippet.length > 50) snippet = snippet.substring(0, 50) + "...";

      // 2. Chat Metadata
      batch.set(chatRef, {
        participants: [senderId, recipientId],
        lastMessage: snippet,
        lastMessageTime: timestamp,
        lastSenderId: senderId,
        unreadCount: { [recipientId]: admin.firestore.FieldValue.increment(1), [senderId]: 0 },
      }, { merge: true });

      // 3. Notification Doc
      const notifDocId = `message_${senderId}_${now.getTime()}_${Math.floor(Math.random() * 10000)}`;
      const notifRef = db.collection("users").doc(recipientId).collection("notifications").doc(notifDocId);
      
      batch.set(notifRef, {
        id: notifDocId,
        type: "message",
        triggerUserId: senderId,
        timestamp: timestamp,
        isRead: false,
        postId: null,
        commentSnippet: snippet,
        postThumbnailUrl: null,
        triggerUserName: triggerUserName,
        triggerAvatarUrl: triggerAvatarUrl,
      }, { merge: true });

      // 4. Update recipient's unread notification badge
      const userRef = db.collection("users").doc(recipientId);
      batch.update(userRef, {
        unreadNotificationCount: admin.firestore.FieldValue.increment(1),
      });
    });

    return batch.commit();
  });

  await Promise.all(promises);

  return { success: true, count: recipientUids.length };
});

/**
 * Hash a string using SHA-256.
 * Used for OTP storage — we never store plaintext OTPs.
 */
function hashOtp(otp) {
  return crypto.createHash("sha256").update(otp).digest("hex");
}

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

const BRAND_NAME = "KnockPost";
const MAX_FCM_TOKENS_PER_USER = 10;
const CHANNEL_IDS = {
  high: "knockpost_high",
  medium: "knockpost_medium",
  low: "knockpost_low",
};

const PRIORITY_CONFIG = {
  // HIGH: user-actionable and time-sensitive.
  knock:       { priority: "high",   channelId: CHANNEL_IDS.high,   sound: true,  vibrate: true,  notificationPriority: "max" },
  knockAccept: { priority: "high",   channelId: CHANNEL_IDS.high,   sound: true,  vibrate: true,  notificationPriority: "max" },
  knockBack:   { priority: "high",   channelId: CHANNEL_IDS.high,   sound: true,  vibrate: true,  notificationPriority: "max" },
  message:     { priority: "high",   channelId: CHANNEL_IDS.high,   sound: true,  vibrate: true,  notificationPriority: "max" },
  comment:     { priority: "high",   channelId: CHANNEL_IDS.high,   sound: true,  vibrate: true,  notificationPriority: "max" },
  mention:     { priority: "high",   channelId: CHANNEL_IDS.high,   sound: true,  vibrate: true,  notificationPriority: "max" },

  // MEDIUM: visible, relevant, not urgent.
  like:         { priority: "normal", channelId: CHANNEL_IDS.medium, sound: false, vibrate: false, notificationPriority: "default" },
  waveLike:     { priority: "normal", channelId: CHANNEL_IDS.medium, sound: false, vibrate: false, notificationPriority: "default" },
  friendActivity: { priority: "normal", channelId: CHANNEL_IDS.medium, sound: false, vibrate: false, notificationPriority: "default", collapseKey: "friend_activity" },

  // LOW: calm catch-up nudges.
  engagement:  { priority: "normal", channelId: CHANNEL_IDS.low,    sound: false, vibrate: false, notificationPriority: "low", collapseKey: "engagement", ttl: 6 * 60 * 60 * 1000 },
  suggestion:  { priority: "normal", channelId: CHANNEL_IDS.low,    sound: false, vibrate: false, notificationPriority: "low" },
  milestone:   { priority: "normal", channelId: CHANNEL_IDS.low,    sound: false, vibrate: false, notificationPriority: "low" },
};

// ── Human-Style Notification Wording ─────────────────────────────────────────

const FRIEND_ACTIVITY_TEMPLATES = [
  "{name} shared an update.",
  "{name} shared something new.",
  "{name} added a new moment.",
  "{name} shared a fresh thought.",
  "{name} has something new for you.",
  "There is something new from {name}.",
  "{name} posted a new moment.",
  "{name} added something worth catching.",
  "{name} shared a quiet update.",
  "{name} has a fresh moment waiting.",
  "{name} brought something new to your feed.",
  "{name} shared a new piece of their day.",
  "{name} added a fresh post.",
  "{name} shared what is new today.",
  "{name} has a new update in your feed.",
  "{name} added a moment you may like.",
  "{name} shared something recent.",
  "{name} has a new post waiting.",
  "{name} added something fresh.",
  "Someone you know shared something today.",
];

const LIKE_TEMPLATES = [
  "{name} liked your post.",
  "{name} reacted to your post.",
  "{name} left a little love on your post.",
  "{name} noticed something you shared.",
  "{name} liked your latest moment.",
];

const WAVE_LIKE_TEMPLATES = [
  "{name} liked your Wave.",
  "{name} reacted to your Wave.",
  "{name} noticed your Wave.",
  "{name} liked something you shared in Waves.",
];

const MENTION_TEMPLATES = [
  "{name} mentioned you.",
  "{name} brought you into a post.",
  "{name} mentioned you in a new update.",
];

const KNOCK_TEMPLATES = {
  pending: [
    "{name} requested to knock you.",
    "{name} would like to connect.",
    "{name} sent you a Knock request.",
  ],
  direct: [
    "{name} knocked you.",
    "{name} connected with you.",
    "{name} sent you a Knock.",
  ],
  accepted: [
    "{name} accepted your Knock request.",
    "{name} approved your Knock.",
    "{name} welcomed your Knock.",
  ],
  back: [
    "{name} knocked you back.",
    "{name} connected back with you.",
    "{name} returned your Knock.",
  ],
};

const ENGAGEMENT_TEMPLATES = {
  morning: [
    "Good morning. Something new is waiting for you.",
    "Start your day with fresh updates from people you care about.",
    "Your friends shared new moments while you were away.",
    "A few fresh updates arrived overnight.",
    "Your feed has a quiet catch-up waiting.",
    "New moments are ready when you are.",
    "Fresh posts from your people are waiting.",
    "There is something new to start the day with.",
  ],
  afternoon: [
    "Take a short break. Something new is waiting.",
    "Fresh updates have arrived.",
    "Catch up in under a minute.",
    "A few new moments landed in your feed.",
    "Your people shared something new today.",
    "There is a quick catch-up waiting for you.",
    "Fresh posts are ready when you have a moment.",
    "A small update from your circle is waiting.",
  ],
  evening: [
    "Wind down with today's latest updates.",
    "End your day with fresh moments from friends.",
    "Your KnockPost feed has something new.",
    "A few new moments are waiting from today.",
    "Catch up with what your people shared today.",
    "There is something new to settle into.",
    "Fresh updates from your circle are waiting.",
    "Your evening catch-up is ready.",
  ],
};

function hashString(value) {
  const text = String(value || "");
  let hash = 0;
  for (let i = 0; i < text.length; i++) {
    hash = ((hash << 5) - hash) + text.charCodeAt(i);
    hash |= 0;
  }
  return Math.abs(hash);
}

function pickTemplate(templates, seed) {
  return templates[hashString(seed) % templates.length];
}

function renderTemplate(template, values) {
  return template.replace(/\{(\w+)\}/g, (_, key) => values[key] || "");
}

function cleanDisplayName(name) {
  const trimmed = typeof name === "string" ? name.trim() : "";
  return trimmed || "Someone";
}

function truncateText(value, maxLength = 96) {
  const text = typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
  if (text.length <= maxLength) return text;
  return `${text.slice(0, maxLength - 3).trim()}...`;
}

function friendActivityBody(senderName, seed) {
  return renderTemplate(
    pickTemplate(FRIEND_ACTIVITY_TEMPLATES, seed),
    { name: cleanDisplayName(senderName) }
  );
}

function buildNotificationContent(type, senderName, data = {}) {
  const name = cleanDisplayName(senderName);
  const seed = `${type}_${data.postId || ""}_${data.notificationId || ""}_${name}`;

  switch (type) {
    case "knock":
      if (data.isPendingRequest === true) {
        return {
          title: BRAND_NAME,
          body: renderTemplate(pickTemplate(KNOCK_TEMPLATES.pending, seed), { name }),
        };
      }
      return {
        title: BRAND_NAME,
        body: renderTemplate(pickTemplate(KNOCK_TEMPLATES.direct, seed), { name }),
      };

    case "knockAccept":
      return {
        title: BRAND_NAME,
        body: renderTemplate(pickTemplate(KNOCK_TEMPLATES.accepted, seed), { name }),
      };

    case "knockBack":
      return {
        title: BRAND_NAME,
        body: renderTemplate(pickTemplate(KNOCK_TEMPLATES.back, seed), { name }),
      };

    case "like":
      return {
        title: BRAND_NAME,
        body: renderTemplate(pickTemplate(LIKE_TEMPLATES, seed), { name }),
      };

    case "waveLike":
      return {
        title: BRAND_NAME,
        body: renderTemplate(pickTemplate(WAVE_LIKE_TEMPLATES, seed), { name }),
      };

    case "friendActivity":
      return {
        title: BRAND_NAME,
        body: friendActivityBody(name, seed),
      };

    case "comment": {
      const snippet = truncateText(data.commentSnippet || "");
      return {
        title: BRAND_NAME,
        body: snippet ? `${name} replied on your post: "${snippet}"` : `${name} replied on your post.`,
      };
    }

    case "mention":
      return {
        title: BRAND_NAME,
        body: renderTemplate(pickTemplate(MENTION_TEMPLATES, seed), { name }),
      };

    case "message": {
      const msgSnippet = truncateText(data.commentSnippet || "");
      return {
        title: name,
        body: msgSnippet || "Sent you a message.",
      };
    }

    default:
      return {
        title: BRAND_NAME,
        body: `${name} shared something new.`,
      };
  }
}

function stringifyData(data) {
  return Object.fromEntries(
    Object.entries(data)
      .filter(([, value]) => value !== undefined && value !== null)
      .map(([key, value]) => [key, String(value)])
  );
}

function buildPushPayload({ type, content, data, config, tag, badge = 1 }) {
  const aps = {
    alert: {
      title: content.title,
      body: content.body,
    },
    badge,
    "thread-id": type,
  };
  if (config.sound) {
    aps.sound = "default";
  }

  const android = {
    priority: config.priority,
    notification: {
      channelId: config.channelId,
      priority: config.notificationPriority || (config.priority === "high" ? "max" : "default"),
      defaultSound: config.sound,
      defaultVibrateTimings: config.vibrate === true,
      icon: "ic_notification",
      color: "#111111",
      tag,
    },
  };
  if (config.collapseKey) {
    android.collapseKey = config.collapseKey;
  }
  if (config.ttl) {
    android.ttl = config.ttl;
  }

  return {
    notification: {
      title: content.title,
      body: content.body,
    },
    data: stringifyData(data),
    android,
    apns: { payload: { aps } },
  };
}

function getFcmTokens(userData) {
  const tokens = new Set();
  if (typeof userData.fcmToken === "string" && userData.fcmToken.trim()) {
    tokens.add(userData.fcmToken.trim());
  }
  if (Array.isArray(userData.fcmTokens)) {
    userData.fcmTokens.forEach((token) => {
      if (typeof token === "string" && token.trim()) {
        tokens.add(token.trim());
      }
    });
  }
  return Array.from(tokens).slice(0, MAX_FCM_TOKENS_PER_USER);
}

function isStaleFcmError(error) {
  return error?.code === "messaging/invalid-registration-token" ||
    error?.code === "messaging/registration-token-not-registered";
}

async function cleanUpStaleTokens(userRef, userData, staleTokens) {
  if (!staleTokens.length) return;
  const updates = {
    fcmTokens: admin.firestore.FieldValue.arrayRemove(...staleTokens),
  };
  if (staleTokens.includes(userData.fcmToken)) {
    updates.fcmToken = admin.firestore.FieldValue.delete();
  }
  await userRef.update(updates);
}

async function sendPayloadToUser({ userRef, userData, payload }) {
  const tokens = getFcmTokens(userData);
  if (tokens.length === 0) {
    return { successCount: 0, failureCount: 0 };
  }

  if (tokens.length === 1) {
    try {
      const response = await admin.messaging().send({ ...payload, token: tokens[0] });
      return { successCount: 1, failureCount: 0, response };
    } catch (error) {
      if (isStaleFcmError(error)) {
        await cleanUpStaleTokens(userRef, userData, [tokens[0]]);
      }
      throw error;
    }
  }

  const response = await admin.messaging().sendEachForMulticast({
    ...payload,
    tokens,
  });

  const staleTokens = [];
  response.responses.forEach((sendResponse, index) => {
    if (!sendResponse.success && isStaleFcmError(sendResponse.error)) {
      staleTokens.push(tokens[index]);
    }
  });
  await cleanUpStaleTokens(userRef, userData, staleTokens);
  return response;
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
    from: `"KnockPost" <${process.env.GMAIL_EMAIL || "knockpostofficial@gmail.com"}>`,
    to: email,
    subject: `Your KnockPost code is ${otp}`,
    html: `
      <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 32px; color: #1a1a1a;">
        <h1 style="font-size: 28px; font-weight: 700; margin-bottom: 32px; color: #000;">KnockPost</h1>
        
        <p style="font-size: 16px; margin-bottom: 24px; color: #333;">Enter this temporary verification code to continue:</p>
        
        <div style="background-color: #f3f3f4; border-radius: 12px; padding: 24px; text-align: left; margin-bottom: 24px;">
          <span style="font-size: 32px; font-weight: 400; letter-spacing: 2px; color: #1a1a1a;">${otp}</span>
        </div>
        
        <p style="font-size: 14px; margin-bottom: 32px; color: #333; line-height: 1.5;">
          If you were not trying to log in to KnockPost, please ignore this email or reset your password.
        </p>
        
        <div style="margin-bottom: 48px;">
          <p style="font-size: 14px; color: #666; margin: 0;">Best,</p>
          <p style="font-size: 14px; color: #666; margin: 0;">The KnockPost team</p>
        </div>
        
        <hr style="border: none; border-top: 1px solid #eaeaea; margin-bottom: 24px;" />
        
        <h2 style="font-size: 16px; font-weight: 700; margin-bottom: 16px; color: #000;">KnockPost</h2>
        
        <div style="font-size: 12px; color: #888;">
          <p style="margin: 0 0 4px 0;">KnockPost</p>
          <p style="margin: 0;">Help center</p>
        </div>
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
      // ── Fetch receiver profile only ──
      // Security Hardening (Phase N2): The sender info is securely embedded in the payload, 
      // eliminating 50% of the read load (triggerUserDoc read is removed).
      const userRef = db.collection("users").doc(receiverId);
      const userDoc = await userRef.get();

      if (!userDoc.exists) {
        console.log(`Receiver ${receiverId} not found.`);
        return null;
      }

      const userData = userDoc.data();

      if (getFcmTokens(userData).length === 0) {
        console.log(`No FCM token for ${receiverId}.`);
        return null;
      }

      // ── S4 Anti-Spoofing: Build sender info authoritatively ──
      // Ignore client-provided names, fetch the REAL user from Firestore
      const triggerUserDoc = await db.collection("users").doc(triggerUserId).get();
      const triggerUserData = triggerUserDoc.exists ? triggerUserDoc.data() : {};
      const senderName = triggerUserData.username || triggerUserData.displayName || "Someone";
      const profileImageUrl = triggerUserData.avatarUrl || triggerUserData.profileImageUrl || "";

      // ── Determine notification type and check for pending knock request ──
      const type = notificationData.type || "unknown";
      let enrichedData = { ...notificationData, notificationId };

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
      const tag = `${type}_${notificationData.postId || triggerUserId}`;

      // ── Build FCM payload ──
      const payload = buildPushPayload({
        type,
        content,
        data: {
          type: type,
          triggerUserId: triggerUserId || "",
          postId: notificationData.postId || "",
          notificationId: notificationId,
          profileImageUrl: profileImageUrl,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        config,
        tag,
        badge: Math.max(1, userData.unreadNotificationCount || 1),
      });

      // ── Send push ──
      const response = await sendPayloadToUser({ userRef, userData, payload });
      console.log(`✓ Push sent to ${receiverId} [${type}]:`, response);

      // ── Mark as pushSent (idempotent flag) ──
      await snapshot.ref.update({ pushSent: true });

    } catch (error) {
      console.error(`✗ Push failed for ${receiverId}:`, error);
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

    if (afterData.isRead !== false || beforeData.isRead !== true) {
      console.log(`Update for ${notificationId}: notification was not re-opened from a read state. Skipping.`);
      return null;
    }

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
      const userRef = db.collection("users").doc(receiverId);
      const [userDoc, triggerUserDoc] = await Promise.all([
        userRef.get(),
        db.collection("users").doc(triggerUserId).get(),
      ]);

      if (!userDoc.exists) return null;

      const userData = userDoc.data();
      if (getFcmTokens(userData).length === 0) return null;

      // ── S4 Anti-Spoofing: Build sender info authoritatively ──
      const triggerUserData = triggerUserDoc.exists ? triggerUserDoc.data() : {};
      const senderName = triggerUserData.username || triggerUserData.displayName || "Someone";
      const profileImageUrl = triggerUserData.avatarUrl || triggerUserData.profileImageUrl || "";

      const type = afterData.type || "unknown";
      let enrichedData = { ...afterData, notificationId };

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
      const tag = `${type}_${afterData.postId || triggerUserId}`;

      const payload = buildPushPayload({
        type,
        content,
        data: {
          type: type,
          triggerUserId: triggerUserId || "",
          postId: afterData.postId || "",
          notificationId: notificationId,
          profileImageUrl: profileImageUrl,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        config,
        tag,
        badge: Math.max(1, userData.unreadNotificationCount || 1),
      });

      const response = await sendPayloadToUser({ userRef, userData, payload });
      console.log(`✓ Re-push sent to ${receiverId} [${type}]:`, response);

      // Mark pushSent
      await change.after.ref.update({ pushSent: true });

    } catch (error) {
      console.error(`✗ Re-push failed for ${receiverId}:`, error);
    }

    return null;
  });

// ═══════════════════════════════════════════════════════════════════════════════
// SMART DAILY RE-ENGAGEMENT
// ═══════════════════════════════════════════════════════════════════════════════
// A calm catch-up system:
//   • no push while the user is active or recently opened the app
//   • no push without fresh content from connected people
//   • local daytime/evening only
//   • one catch-up per local day, with adaptive spacing
//   • personalized friend activity copy beats generic reminders
// ═══════════════════════════════════════════════════════════════════════════════

const ENGAGEMENT_MAX_USERS_PER_RUN = 300;
const ENGAGEMENT_CONCURRENCY = 20;
const ENGAGEMENT_CONNECTION_LIMIT = 120;
const ENGAGEMENT_AUTHOR_CHUNK_SIZE = 30;
const ENGAGEMENT_MIN_IDLE_HOURS = 6;
const ENGAGEMENT_QUIET_START_HOUR = 22;
const ENGAGEMENT_QUIET_END_HOUR = 8;

function timestampMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  return 0;
}

function localDateKey(now, timezoneOffsetMinutes = 0) {
  const local = new Date(now.getTime() + timezoneOffsetMinutes * 60 * 1000);
  return local.toISOString().slice(0, 10);
}

function localHour(now, timezoneOffsetMinutes = 0) {
  const local = new Date(now.getTime() + timezoneOffsetMinutes * 60 * 1000);
  return local.getUTCHours();
}

function isQuietHour(hour) {
  return hour >= ENGAGEMENT_QUIET_START_HOUR || hour < ENGAGEMENT_QUIET_END_HOUR;
}

function engagementTimeBucket(hour) {
  if (hour < 12) return "morning";
  if (hour < 17) return "afternoon";
  return "evening";
}

function engagementMinGapHours(idleHours) {
  if (idleHours < 24) return 36;      // active users get fewer reminders
  if (idleHours < 72) return 24;      // recently inactive users get gentle help
  if (idleHours < 168) return 36;     // longer idle, slower cadence
  return 72;                          // dormant users should not be chased
}

function isPostStillRelevant(postData, createdAtMillis, now) {
  const ageHours = (now.getTime() - createdAtMillis) / (60 * 60 * 1000);
  const duration = postData.duration || "lifetime";
  if (duration === "h24") return ageHours < 24;
  if (duration === "h36") return ageHours < 36;
  return true;
}

function chunkArray(items, size) {
  const chunks = [];
  for (let i = 0; i < items.length; i += size) {
    chunks.push(items.slice(i, i + size));
  }
  return chunks;
}

async function getConnectionRanks(uid) {
  const ranks = new Map();
  const [mutualSnap, sentSnap, receivedSnap] = await Promise.all([
    db.collection("mutual_connections")
      .where("participants", "array-contains", uid)
      .limit(ENGAGEMENT_CONNECTION_LIMIT)
      .get(),
    db.collection("connections")
      .where("fromUid", "==", uid)
      .where("status", "==", "accepted")
      .limit(ENGAGEMENT_CONNECTION_LIMIT)
      .get(),
    db.collection("connections")
      .where("toUid", "==", uid)
      .where("status", "==", "accepted")
      .limit(ENGAGEMENT_CONNECTION_LIMIT)
      .get(),
  ]);

  mutualSnap.docs.forEach((doc) => {
    const participants = Array.isArray(doc.data().participants) ? doc.data().participants : [];
    const otherUid = participants.find((id) => id !== uid);
    if (otherUid) ranks.set(otherUid, 0);
  });
  sentSnap.docs.forEach((doc) => {
    const otherUid = doc.data().toUid;
    if (otherUid && !ranks.has(otherUid)) ranks.set(otherUid, 1);
  });
  receivedSnap.docs.forEach((doc) => {
    const otherUid = doc.data().fromUid;
    if (otherUid && !ranks.has(otherUid)) ranks.set(otherUid, 1);
  });

  return ranks;
}

async function getAuthorProfiles(authorIds) {
  if (authorIds.length === 0) return new Map();
  const refs = authorIds.map((authorId) => db.collection("users").doc(authorId));
  const docs = await db.getAll(...refs);
  const profiles = new Map();
  docs.forEach((doc) => {
    if (doc.exists) profiles.set(doc.id, doc.data());
  });
  return profiles;
}

async function getFreshConnectedPosts({ uid, userData, connectionRanks, afterMillis, now }) {
  const connectedIds = Array.from(connectionRanks.keys()).slice(0, ENGAGEMENT_CONNECTION_LIMIT);
  if (connectedIds.length === 0) return { posts: [], authorProfiles: new Map() };

  const afterTimestamp = admin.firestore.Timestamp.fromMillis(afterMillis);
  const posts = [];

  for (const chunk of chunkArray(connectedIds, ENGAGEMENT_AUTHOR_CHUNK_SIZE)) {
    const snap = await db.collection("posts")
      .where("authorId", "in", chunk)
      .where("createdAt", ">", afterTimestamp)
      .orderBy("createdAt", "desc")
      .limit(12)
      .get();

    snap.docs.forEach((doc) => {
      const data = doc.data();
      const createdAtMillis = timestampMillis(data.createdAt);
      if (!createdAtMillis || !isPostStillRelevant(data, createdAtMillis, now)) return;
      posts.push({
        id: doc.id,
        authorId: data.authorId,
        createdAtMillis,
        rank: connectionRanks.get(data.authorId) ?? 2,
        type: data.type || "post",
      });
    });
  }

  posts.sort((a, b) => (a.rank - b.rank) || (b.createdAtMillis - a.createdAtMillis));
  const authorIds = Array.from(new Set(posts.map((post) => post.authorId)));
  const authorProfiles = await getAuthorProfiles(authorIds);
  const viewerBlocked = new Set(Array.isArray(userData.blockedUsers) ? userData.blockedUsers : []);

  const visiblePosts = posts.filter((post) => {
    const author = authorProfiles.get(post.authorId);
    if (!author) return false;
    if (viewerBlocked.has(post.authorId)) return false;
    if (Array.isArray(author.blockedUsers) && author.blockedUsers.includes(uid)) return false;
    return true;
  });

  return { posts: visiblePosts, authorProfiles };
}

function buildEngagementContent({ uid, posts, authorProfiles, localHourValue }) {
  const bucket = engagementTimeBucket(localHourValue);
  const topPost = posts[0];
  if (!topPost) {
    return {
      title: BRAND_NAME,
      body: pickTemplate(ENGAGEMENT_TEMPLATES[bucket], `${uid}_${bucket}`),
      reason: "generic",
    };
  }

  const topAuthor = authorProfiles.get(topPost.authorId) || {};
  const topName = cleanDisplayName(topAuthor.displayName || topAuthor.username);
  const uniqueAuthorIds = Array.from(new Set(posts.map((post) => post.authorId)));

  if (uniqueAuthorIds.length === 1 && posts.length === 1) {
    return {
      title: BRAND_NAME,
      body: friendActivityBody(topName, `${uid}_${topPost.id}_${bucket}`),
      reason: "single_friend_post",
    };
  }

  if (uniqueAuthorIds.length === 1) {
    return {
      title: BRAND_NAME,
      body: `${topName} shared ${posts.length} new updates.`,
      reason: "single_friend_multiple_posts",
    };
  }

  const otherCount = uniqueAuthorIds.length - 1;
  return {
    title: BRAND_NAME,
    body: `${topName} and ${otherCount} other${otherCount === 1 ? "" : "s"} shared new moments.`,
    reason: "multiple_friends",
  };
}

async function processEngagementCandidate(userDoc, now) {
  const uid = userDoc.id;
  const userData = userDoc.data();
  const userRef = userDoc.ref;

  if (userData.isOnline === true || getFcmTokens(userData).length === 0) {
    return { sent: false, reason: "active_or_no_token" };
  }

  const lastSeenMillis = timestampMillis(userData.lastSeen) || timestampMillis(userData.lastAppOpenedAt);
  if (!lastSeenMillis) {
    return { sent: false, reason: "missing_last_seen" };
  }

  const idleHours = (now.getTime() - lastSeenMillis) / (60 * 60 * 1000);
  if (idleHours < ENGAGEMENT_MIN_IDLE_HOURS) {
    return { sent: false, reason: "recently_active" };
  }

  const timezoneOffsetMinutes = Number.isFinite(userData.timezoneOffsetMinutes)
    ? userData.timezoneOffsetMinutes
    : 0;
  const localHourValue = localHour(now, timezoneOffsetMinutes);
  if (isQuietHour(localHourValue)) {
    return { sent: false, reason: "quiet_hours" };
  }

  const engagementState = userData.notificationState?.engagement || {};
  const todayKey = localDateKey(now, timezoneOffsetMinutes);
  const sentTodayCount = engagementState.lastSentLocalDate === todayKey
    ? engagementState.sentTodayCount || 0
    : 0;
  if (sentTodayCount >= 1) {
    return { sent: false, reason: "daily_cap" };
  }

  const lastSentMillis = timestampMillis(engagementState.lastSentAt);
  const minGapHours = engagementMinGapHours(idleHours);
  if (lastSentMillis && ((now.getTime() - lastSentMillis) / (60 * 60 * 1000)) < minGapHours) {
    return { sent: false, reason: "adaptive_gap" };
  }

  const lastContentWatermarkMillis = timestampMillis(engagementState.lastContentWatermark);
  const afterMillis = Math.max(lastSeenMillis, lastContentWatermarkMillis || 0);
  const connectionRanks = await getConnectionRanks(uid);
  const { posts, authorProfiles } = await getFreshConnectedPosts({
    uid,
    userData,
    connectionRanks,
    afterMillis,
    now,
  });

  if (posts.length === 0) {
    return { sent: false, reason: "no_new_connected_content" };
  }

  const latestContentMillis = Math.max(...posts.map((post) => post.createdAtMillis));
  const content = buildEngagementContent({
    uid,
    posts,
    authorProfiles,
    localHourValue,
  });
  const config = PRIORITY_CONFIG.engagement;
  const payload = buildPushPayload({
    type: "engagement",
    content,
    data: {
      type: "engagement",
      reason: content.reason,
      newPostCount: posts.length,
      topAuthorId: posts[0].authorId,
      topPostId: posts[0].id,
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    config,
    tag: `engagement_${uid}`,
    badge: Math.max(1, userData.unreadNotificationCount || 1),
  });

  const response = await sendPayloadToUser({ userRef, userData, payload });
  await userRef.update({
    "notificationState.engagement.lastSentAt": admin.firestore.FieldValue.serverTimestamp(),
    "notificationState.engagement.lastSentLocalDate": todayKey,
    "notificationState.engagement.sentTodayCount": sentTodayCount + 1,
    "notificationState.engagement.lastContentWatermark": admin.firestore.Timestamp.fromMillis(latestContentMillis),
    "notificationState.engagement.lastReason": content.reason,
  });

  return { sent: true, reason: content.reason, response };
}

exports.sendSmartEngagementNotifications = functions.pubsub
  .schedule("every 60 minutes")
  .timeZone("UTC")
  .onRun(async () => {
    const now = new Date();
    const usersSnapshot = await db.collection("users")
      .where("fcmToken", "!=", null)
      .limit(ENGAGEMENT_MAX_USERS_PER_RUN)
      .get();

    let sent = 0;
    const skipped = {};
    const docs = usersSnapshot.docs;

    for (let i = 0; i < docs.length; i += ENGAGEMENT_CONCURRENCY) {
      const batch = docs.slice(i, i + ENGAGEMENT_CONCURRENCY);
      const results = await Promise.all(batch.map(async (doc) => {
        try {
          return await processEngagementCandidate(doc, now);
        } catch (error) {
          console.error(`Engagement notification failed for ${doc.id}:`, error);
          return { sent: false, reason: "error" };
        }
      }));

      results.forEach((result) => {
        if (result.sent) {
          sent++;
        } else {
          skipped[result.reason] = (skipped[result.reason] || 0) + 1;
        }
      });
    }

    console.log("Smart engagement notification run complete.", {
      candidates: docs.length,
      sent,
      skipped,
    });
    return null;
  });

// ═══════════════════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════════
// EMAIL OTP FUNCTIONS (Forgot Password)
// ═══════════════════════════════════════════════════════════════════════════════

exports.checkEmailTaken = functions.https.onCall(async (data, context) => {
  const email = data.email;
  if (!email || typeof email !== "string") {
    throw new functions.https.HttpsError("invalid-argument", "Email is required");
  }

  try {
    await admin.auth().getUserByEmail(email);
    return { taken: true };
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      return { taken: false };
    }
    console.error("Error checking email in auth:", error);
    throw new functions.https.HttpsError("internal", "Error checking email");
  }
});

exports.checkUsernameTaken = functions.https.onCall(async (data, context) => {
  const username = data.username;
  if (!username || typeof username !== "string") {
    throw new functions.https.HttpsError("invalid-argument", "Username is required");
  }

  try {
    const snapshot = await admin.firestore().collection("users")
      .where("username", "==", username.toLowerCase().trim())
      .limit(1)
      .get();
    
    return { taken: !snapshot.empty };
  } catch (error) {
    console.error("Error checking username in firestore:", error);
    throw new functions.https.HttpsError("internal", "Error checking username");
  }
});

exports.getEmailFromUsername = functions.https.onCall(async (data, context) => {
  const username = data.username;
  if (!username || typeof username !== "string") {
    throw new functions.https.HttpsError("invalid-argument", "Username is required");
  }

  try {
    const snapshot = await admin.firestore().collection("users")
      .where("username", "==", username.toLowerCase().trim())
      .limit(1)
      .get();
    
    if (snapshot.empty) {
      return { email: null };
    }
    
    const userData = snapshot.docs[0].data();
    return { email: userData.email };
  } catch (error) {
    console.error("Error getting email by username:", error);
    throw new functions.https.HttpsError("internal", "Error getting email by username");
  }
});

// Email transporter for forgot-password OTP flow.
// Credentials loaded from functions/.env (GMAIL_EMAIL and GMAIL_PASSWORD).
// Uses the same transporter as the 2FA OTP flow above.
const transporter = gmailTransporter;

exports.sendEmailOtp = functions.https.onCall(async (data, context) => {
  const email = data.email;
  if (!email || typeof email !== "string") {
    throw new functions.https.HttpsError("invalid-argument", "Email is required");
  }

  const otpDocRef = admin.firestore().collection("emailOtps").doc(email);

  // ── Rate Limiting: Max 3 OTP sends per email per hour ──
  const existingDoc = await otpDocRef.get();
  if (existingDoc.exists) {
    const existingData = existingDoc.data();
    const sendCount = existingData.sendCount || 0;
    const firstSendAt = existingData.firstSendAt ? existingData.firstSendAt.toMillis() : 0;
    const oneHourAgo = Date.now() - (60 * 60 * 1000);

    if (firstSendAt > oneHourAgo && sendCount >= 30) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        "Too many OTP requests. Please try again later."
      );
    }
  }

  // Generate 6-digit OTP
  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + 10 * 60 * 1000); // 10 minutes

  // Save hashed OTP in Firestore with rate-limiting metadata
  const isNewWindow = !existingDoc.exists ||
    !existingDoc.data().firstSendAt ||
    existingDoc.data().firstSendAt.toMillis() < (Date.now() - 60 * 60 * 1000);

  await otpDocRef.set({
    otpHash: hashOtp(otp),
    expiresAt: expiresAt,
    attempts: 0,
    sendCount: isNewWindow ? 1 : admin.firestore.FieldValue.increment(1),
    firstSendAt: isNewWindow
      ? admin.firestore.FieldValue.serverTimestamp()
      : (existingDoc.exists ? existingDoc.data().firstSendAt : admin.firestore.FieldValue.serverTimestamp()),
  });

  // Send Email
  const mailOptions = {
    from: `"KnockPost" <${process.env.GMAIL_EMAIL || "knockpostofficial@gmail.com"}>`,
    to: email,
    subject: `Your KnockPost code is ${otp}`,
    html: `
      <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 32px; color: #1a1a1a;">
        <h1 style="font-size: 28px; font-weight: 700; margin-bottom: 32px; color: #000;">KnockPost</h1>
        
        <p style="font-size: 16px; margin-bottom: 24px; color: #333;">Enter this temporary verification code to continue:</p>
        
        <div style="background-color: #f3f3f4; border-radius: 12px; padding: 24px; text-align: left; margin-bottom: 24px;">
          <span style="font-size: 32px; font-weight: 400; letter-spacing: 2px; color: #1a1a1a;">${otp}</span>
        </div>
        
        <p style="font-size: 14px; margin-bottom: 32px; color: #333; line-height: 1.5;">
          If you were not trying to log in to KnockPost, please ignore this email or reset your password.
        </p>
        
        <div style="margin-bottom: 48px;">
          <p style="font-size: 14px; color: #666; margin: 0;">Best,</p>
          <p style="font-size: 14px; color: #666; margin: 0;">The KnockPost team</p>
        </div>
        
        <hr style="border: none; border-top: 1px solid #eaeaea; margin-bottom: 24px;" />
        
        <h2 style="font-size: 16px; font-weight: 700; margin-bottom: 16px; color: #000;">KnockPost</h2>
        
        <div style="font-size: 12px; color: #888;">
          <p style="margin: 0 0 4px 0;">KnockPost</p>
          <p style="margin: 0;">Help center</p>
        </div>
      </div>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
  } catch (error) {
    console.error("Failed to send OTP email:", error.message);
  }

  return { success: true };
});

exports.verifyEmailOtp = functions.https.onCall(async (data, context) => {
  const email = data.email;
  const otp = data.otp;
  if (!email || !otp || typeof otp !== "string") {
    throw new functions.https.HttpsError("invalid-argument", "Email and OTP are required");
  }

  const otpDocRef = admin.firestore().collection("emailOtps").doc(email);
  const otpDoc = await otpDocRef.get();

  if (!otpDoc.exists) {
    throw new functions.https.HttpsError("not-found", "No OTP request found for this email");
  }

  const otpData = otpDoc.data();

  // ── Attempt Counting: Max 5 attempts, then invalidate ──
  const attempts = (otpData.attempts || 0) + 1;
  if (attempts > 5) {
    await otpDocRef.delete();
    throw new functions.https.HttpsError(
      "resource-exhausted",
      "Too many incorrect attempts. Please request a new OTP."
    );
  }

  // Check expiry
  if (otpData.expiresAt.toMillis() < Date.now()) {
    await otpDocRef.delete();
    throw new functions.https.HttpsError("failed-precondition", "OTP has expired");
  }

  // Compare hashed OTP (supports both legacy plaintext and new hashed format)
  const submittedHash = hashOtp(otp);
  const isValid = otpData.otpHash
    ? otpData.otpHash === submittedHash
    : otpData.otp === otp; // Legacy plaintext fallback for unexpired pre-migration OTPs

  if (!isValid) {
    // Increment attempt counter
    await otpDocRef.update({ attempts: attempts });
    throw new functions.https.HttpsError("invalid-argument", "Incorrect OTP");
  }

  // OTP is valid — mark as verified, keep for resetPasswordWithOtp
  await otpDocRef.update({ verified: true, attempts: attempts });
  return { success: true };
});

exports.resetPasswordWithOtp = functions.https.onCall(async (data, context) => {
  const { email, otp, newPassword } = data;
  if (!email || !otp || !newPassword) {
    throw new functions.https.HttpsError("invalid-argument", "Missing fields");
  }

  if (typeof newPassword !== "string" || newPassword.length < 6) {
    throw new functions.https.HttpsError("invalid-argument", "Password must be at least 6 characters");
  }

  const otpDocRef = admin.firestore().collection("emailOtps").doc(email);
  const otpDoc = await otpDocRef.get();

  if (!otpDoc.exists) {
    throw new functions.https.HttpsError("not-found", "No OTP request found for this email");
  }

  const otpData = otpDoc.data();

  // Re-verify expiry at reset time
  if (otpData.expiresAt.toMillis() < Date.now()) {
    await otpDocRef.delete();
    throw new functions.https.HttpsError("failed-precondition", "OTP has expired");
  }

  // Verify OTP (supports both hashed and legacy plaintext)
  const submittedHash = hashOtp(otp);
  const isValid = otpData.otpHash
    ? otpData.otpHash === submittedHash
    : otpData.otp === otp;

  if (!isValid) {
    throw new functions.https.HttpsError("invalid-argument", "Incorrect OTP");
  }

  // Verify that OTP was previously verified via verifyEmailOtp
  if (otpData.verified !== true) {
    throw new functions.https.HttpsError("failed-precondition", "OTP has not been verified yet");
  }

  // OTP is valid — delete it so it can't be reused
  await otpDocRef.delete();

  // Get user by email and update password
  try {
    const userRecord = await admin.auth().getUserByEmail(email);
    await admin.auth().updateUser(userRecord.uid, {
      password: newPassword,
    });
  } catch (error) {
    throw new functions.https.HttpsError("internal", "Failed to update user password: " + error.message);
  }

  return { success: true };
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

// ═══════════════════════════════════════════════════════════════════════════════
// PHASE 1 — SECURITY HARDENING: FIRESTORE TRIGGERS
// ═══════════════════════════════════════════════════════════════════════════════
//
// These triggers run alongside existing client-side writes during the
// dual-write transition period. They use the Admin SDK to perform
// cross-user stat updates that will be blocked by security rules in Phase 3.
//
// During dual-write: stats may be ~2x actual (both client + trigger increment).
// After Phase 2 (client writes removed): stats will be exactly correct.
// ═══════════════════════════════════════════════════════════════════════════════

// ── Like Triggers ────────────────────────────────────────────────────────────

exports.onLikeCreated = functions.firestore
  .document("posts/{postId}/likes/{userId}")
  .onCreate(async (snapshot, context) => {
    const { postId } = context.params;

    try {
      // Get the post to find the author
      const postDoc = await db.collection("posts").doc(postId).get();
      if (!postDoc.exists) return null;

      const authorId = postDoc.data().authorId;
      if (!authorId) return null;

      // Increment author's totalLikes
      await db.collection("users").doc(authorId).update({
        totalLikes: admin.firestore.FieldValue.increment(1),
      });

      // Recalculate creator rank
      await recalculateCreatorRank(authorId);

      console.log(`✓ onLikeCreated: post=${postId}, author=${authorId}`);
    } catch (error) {
      console.error("onLikeCreated error:", error);
    }

    return null;
  });

exports.onLikeDeleted = functions.firestore
  .document("posts/{postId}/likes/{userId}")
  .onDelete(async (snapshot, context) => {
    const { postId } = context.params;

    try {
      const postDoc = await db.collection("posts").doc(postId).get();
      if (!postDoc.exists) return null;

      const authorId = postDoc.data().authorId;
      if (!authorId) return null;

      // Decrement author's totalLikes (floor at 0)
      const userDoc = await db.collection("users").doc(authorId).get();
      if (userDoc.exists) {
        const currentLikes = userDoc.data().totalLikes || 0;
        if (currentLikes > 0) {
          await db.collection("users").doc(authorId).update({
            totalLikes: admin.firestore.FieldValue.increment(-1),
          });
        }
      }

      await recalculateCreatorRank(authorId);

      console.log(`✓ onLikeDeleted: post=${postId}, author=${authorId}`);
    } catch (error) {
      console.error("onLikeDeleted error:", error);
    }

    return null;
  });

// ── View Trigger ─────────────────────────────────────────────────────────────

exports.onViewerCreated = functions.firestore
  .document("posts/{postId}/viewers/{userId}")
  .onCreate(async (snapshot, context) => {
    const { postId } = context.params;

    try {
      const postDoc = await db.collection("posts").doc(postId).get();
      if (!postDoc.exists) return null;

      const authorId = postDoc.data().authorId;
      if (!authorId) return null;

      // Increment author's totalViews
      await db.collection("users").doc(authorId).update({
        totalViews: admin.firestore.FieldValue.increment(1),
      });

      await recalculateCreatorRank(authorId);

      console.log(`✓ onViewerCreated: post=${postId}, author=${authorId}`);
    } catch (error) {
      console.error("onViewerCreated error:", error);
    }

    return null;
  });

// ── Knock / Connection Triggers ──────────────────────────────────────────────

exports.onKnockCreated = functions.firestore
  .document("connections/{docId}")
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    const fromUid = data.fromUid;
    const toUid = data.toUid;

    if (!toUid || !fromUid) return null;

    try {
      // Guard: Skip stat increment for reciprocal acceptance documents.
      // When acceptKnock creates connections/{B}_{A}, a reciprocal doc
      // connections/{A}_{B} already exists. This means User B is accepting
      // User A's knock, NOT sending a new knock. Only genuine new knocks
      // (from sendKnock) should increment totalKnocksReceived.
      const reciprocalDocId = `${toUid}_${fromUid}`;
      const reciprocalDoc = await db.collection("connections").doc(reciprocalDocId).get();

      if (reciprocalDoc.exists) {
        console.log(`⊘ onKnockCreated: reciprocal ${reciprocalDocId} exists — acceptance, not new knock. Skipping.`);
        return null;
      }

      // Genuine new knock — increment receiver's totalKnocksReceived
      await db.collection("users").doc(toUid).update({
        totalKnocksReceived: admin.firestore.FieldValue.increment(1),
      });

      await recalculateCreatorRank(toUid);

      console.log(`✓ onKnockCreated: to=${toUid}`);
    } catch (error) {
      console.error("onKnockCreated error:", error);
    }

    return null;
  });

exports.onKnockDeleted = functions.firestore
  .document("connections/{docId}")
  .onDelete(async (snapshot, context) => {
    const data = snapshot.data();
    const toUid = data.toUid;

    if (!toUid) return null;

    try {
      // Decrement receiver's totalKnocksReceived (floor at 0)
      const userDoc = await db.collection("users").doc(toUid).get();
      if (userDoc.exists) {
        const currentKnocks = userDoc.data().totalKnocksReceived || 0;
        if (currentKnocks > 0) {
          await db.collection("users").doc(toUid).update({
            totalKnocksReceived: admin.firestore.FieldValue.increment(-1),
          });
        }
      }

      await recalculateCreatorRank(toUid);

      console.log(`✓ onKnockDeleted: to=${toUid}`);
    } catch (error) {
      console.error("onKnockDeleted error:", error);
    }

    return null;
  });

exports.onKnockUpdated = functions.firestore
  .document("connections/{docId}")
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // Only act on status changes
    if (beforeData.status === afterData.status) return null;

    try {
      // If status changed to 'accepted', the knock was approved
      if (afterData.status === "accepted" && beforeData.status === "pending") {
        console.log(`✓ onKnockUpdated: ${afterData.fromUid} → ${afterData.toUid} accepted`);
      }
    } catch (error) {
      console.error("onKnockUpdated error:", error);
    }

    return null;
  });

// ═══════════════════════════════════════════════════════════════════════════════
// PHASE 1 — CALLABLE FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * sendNotificationToUser — Callable function for secure notification sending.
 * Replaces client-side direct writes to users/{uid}/notifications/ in Phase 2.
 * In Phase 1 this is deployed but not yet called by the client.
 */
exports.sendNotificationToUser = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "You must be logged in.");
  }

  const { receiverUid, type, postId, commentSnippet } = data;

  if (!receiverUid || !type) {
    throw new functions.https.HttpsError("invalid-argument", "receiverUid and type are required.");
  }

  // Validate receiver exists
  const receiverDoc = await db.collection("users").doc(receiverUid).get();
  if (!receiverDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Receiver not found.");
  }

  await sendNotification({
    receiverUid,
    triggerUserId: context.auth.uid,
    type,
    postId: postId || null,
    commentSnippet: commentSnippet || null,
  });

  return { success: true };
});

/**
 * deleteNotificationForUser — Callable function to retract a sent notification.
 * Used when a user un-knocks or un-likes (removes the notification they triggered).
 */
exports.deleteNotificationForUser = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "You must be logged in.");
  }

  const { receiverUid, docId } = data;

  if (!receiverUid || !docId) {
    throw new functions.https.HttpsError("invalid-argument", "receiverUid and docId are required.");
  }

  await deleteNotification(receiverUid, docId);

  return { success: true };
});

/**
 * deleteUserAccount — Callable function for GDPR-compliant account deletion.
 * Cascade-deletes all user data: posts, connections, chats, notifications, storage.
 * Must be called by the authenticated user who owns the account.
 */
exports.deleteUserAccount = functions
  .runWith({ timeoutSeconds: 540 }) // 9 minutes — cascade deletion can be slow
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "You must be logged in.");
    }

    const uid = context.auth.uid;

    try {
      // Cascade delete all user data
      const summary = await cascadeDeleteUser(uid);

      // Delete Firebase Auth account
      try {
        await admin.auth().deleteUser(uid);
      } catch (authError) {
        // Auth account may already be deleted by client — not a fatal error
        console.warn(`Auth account deletion for ${uid}:`, authError.message);
      }

      console.log(`✓ Account deleted for ${uid}:`, summary);
      return { success: true, summary };
    } catch (error) {
      console.error(`deleteUserAccount error for ${uid}:`, error);
      throw new functions.https.HttpsError("internal", "Account deletion failed. Please try again.");
    }
  });

// ═══════════════════════════════════════════════════════════════════════════════
// PHASE C1 — MEDIA OPTIMIZATION PIPELINE
// ═══════════════════════════════════════════════════════════════════════════════

exports.onMediaUpload = functions.storage.object().onFinalize(async (object) => {
  const filePath = object.name;
  const contentType = object.contentType;
  const customMetadata = object.metadata || {};

  // Only process images (skip WebP if it's already optimized to prevent loops)
  if (!contentType.startsWith('image/') || filePath.endsWith('_1080x1080.webp')) {
    return null;
  }

  // Only process if we have a target document to update
  const targetDoc = customMetadata.targetDoc;
  const targetField = customMetadata.targetField || 'optimizedImagePaths';
  
  if (!targetDoc) {
    console.log(`Skipping ${filePath} - No targetDoc metadata`);
    return null;
  }

  const bucket = admin.storage().bucket(object.bucket);
  const fileName = path.basename(filePath);
  const tempFilePath = path.join(os.tmpdir(), fileName);
  const optimizedFileName = fileName.replace(/\.[^/.]+$/, "") + '_1080x1080.webp';
  const optimizedFilePath = path.join(path.dirname(filePath), optimizedFileName);
  const tempOptimizedPath = path.join(os.tmpdir(), optimizedFileName);

  try {
    // 1. Download original image
    await bucket.file(filePath).download({ destination: tempFilePath });
    console.log(`Downloaded ${filePath} to ${tempFilePath}`);

    // 2. Resize and convert to WebP
    await sharp(tempFilePath)
      .resize(1080, 1080, { fit: 'inside', withoutEnlargement: true })
      .webp({ quality: 80 })
      .toFile(tempOptimizedPath);
    console.log(`Optimized image created at ${tempOptimizedPath}`);

    // 3. Generate persistent download token
    const downloadToken = uuidv4();

    // 4. Upload optimized image with the token
    await bucket.upload(tempOptimizedPath, {
      destination: optimizedFilePath,
      metadata: {
        contentType: 'image/webp',
        cacheControl: 'public, max-age=31536000, immutable',
        metadata: {
          firebaseStorageDownloadTokens: downloadToken,
        }
      }
    });

    // 5. Construct Firebase HTTP download URL
    // Firebase encode path replaces %2F with /
    const encodedPath = encodeURIComponent(optimizedFilePath).replace(/%2F/g, '/');
    const optimizedUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodedPath}?alt=media&token=${downloadToken}`;
    console.log(`Optimized URL generated: ${optimizedUrl}`);

    // 6. Update Firestore Document
    const docRef = db.doc(targetDoc);
    
    // Depending on the field type, we update it
    if (targetField === 'optimizedImagePaths') {
      // Assuming it's an array
      await docRef.update({
        [targetField]: admin.firestore.FieldValue.arrayUnion(optimizedUrl)
      });
    } else {
      // Assuming it's a string
      await docRef.update({
        [targetField]: optimizedUrl
      });
    }
    
    console.log(`Updated Firestore document ${targetDoc} with optimized URL.`);

  } catch (error) {
    console.error(`Error processing ${filePath}:`, error);
  } finally {
    // Cleanup temp files
    if (fs.existsSync(tempFilePath)) fs.unlinkSync(tempFilePath);
    if (fs.existsSync(tempOptimizedPath)) fs.unlinkSync(tempOptimizedPath);
  }

  return null;
});
