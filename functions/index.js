const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");
admin.initializeApp();

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

exports.sendPushNotification = functions.firestore
  .document("users/{userId}/notifications/{notificationId}")
  .onWrite(async (change, context) => {
    // If the document was deleted, skip
    if (!change.after.exists) {
      console.log("Notification document was deleted. Skipping.");
      return null;
    }

    const notificationData = change.after.data();
    const beforeData = change.before.exists ? change.before.data() : null;
    const receiverId = context.params.userId;
    const triggerUserId = notificationData.triggerUserId;

    // Don't send notification to self
    if (receiverId === triggerUserId) {
      console.log("User triggered their own notification. Skipping.");
      return null;
    }

    // Don't send if notification is already read (prevents re-sending on markAsRead)
    if (notificationData.isRead === true) {
      console.log("Notification is already read. Skipping push.");
      return null;
    }

    // SMART SYSTEM: Prevent Push Notification Spam
    // If the notification was ALREADY unread (e.g. consecutive messages/replies),
    // don't buzz the phone again. The UI will update silently.
    if (beforeData && beforeData.isRead === false) {
      console.log("Notification was already unread. Skipping duplicate push to prevent spam.");
      return null;
    }

    // Fetch both users in parallel for maximum speed
    const [userDoc, triggerUserDoc] = await Promise.all([
      admin.firestore().collection("users").doc(receiverId).get(),
      admin.firestore().collection("users").doc(triggerUserId).get()
    ]);

    if (!userDoc.exists) {
      console.log(`No user found for receiverId: ${receiverId}`);
      return null;
    }

    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;

    if (!fcmToken) {
      console.log(`No FCM token found for user: ${receiverId}`);
      return null;
    }

    const triggerUserData = triggerUserDoc.exists ? triggerUserDoc.data() : {};
    const senderName = triggerUserData.username || triggerUserData.displayName || "Someone";
    const profileImageUrl = triggerUserData.avatarUrl || triggerUserData.profileImageUrl || "";

    let title = "";
    let body = "";

    // Determine notification title and body based on type
    const type = notificationData.type;
    if (type === "message") {
      title = `New message from ${senderName}`;
      body = notificationData.commentSnippet || "Sent you a message";
    } else if (type === "like") {
      title = "New Like";
      body = `${senderName} liked your post.`;
    } else if (type === "comment") {
      title = "New Reply";
      body = `${senderName} replied: "${notificationData.commentSnippet || ""}"`;
    } else if (type === "knock" || type === "knockAccept" || type === "knockBack") {
      let actionText = "knocked you.";
      
      if (type === "knockAccept") {
         actionText = "accepted your knock request.";
      } else if (type === "knockBack") {
         actionText = "knocked you back.";
      } else {
         try {
           const [theirKnockDoc, myKnockDoc] = await Promise.all([
             admin.firestore().collection('connections').doc(`${triggerUserId}_${receiverId}`).get(),
             admin.firestore().collection('connections').doc(`${receiverId}_${triggerUserId}`).get()
           ]);
           
           const theirKnock = theirKnockDoc.exists ? theirKnockDoc.data() : null;
           
           if (theirKnock && theirKnock.status === 'pending') {
             actionText = "requested to knock you.";
           }
         } catch (error) {
            console.error("Error checking connection status for push notification:", error);
         }
      }
      
      title = `${senderName} ${actionText}`;
      body = "";
    } else if (type === "mention") {
      title = "New Mention";
      body = `${senderName} mentioned you in a post.`;
    } else {
      title = "New Notification";
      body = `${senderName} interacted with your post.`;
    }

    const payload = {
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: type || "unknown",
        triggerUserId: triggerUserId || "",
        postId: notificationData.postId || "",
        profileImageUrl: profileImageUrl,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "high_importance_channel",
          priority: "high",
          defaultSound: true,
          defaultVibrateTimings: true,
          icon: "ic_notification",
        },
      },
      token: fcmToken,
    };

    try {
      const response = await admin.messaging().send(payload);
      console.log(`Successfully sent push notification to ${receiverId}:`, response);
    } catch (error) {
      console.error(`Error sending push notification to ${receiverId}:`, error);
      // If the token is invalid, remove it from the user's profile
      if (
        error.code === "messaging/invalid-registration-token" ||
        error.code === "messaging/registration-token-not-registered"
      ) {
        console.log(`Removing invalid FCM token for user: ${receiverId}`);
        await admin.firestore().collection("users").doc(receiverId).update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
      }
    }

    return null;
  });

const nodemailer = require("nodemailer");

// NOTE: You must set up Gmail App Password or use SendGrid in production.
// For now, we will use a dummy account or rely on environment variables if set, 
// and ALWAYS print the OTP to the console so it can be tested during development.
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.SMTP_USER || "knockpostofficial@gmail.com",
    pass: process.env.SMTP_PASS || "znjm kiqn nrdo khvy",
  },
});

exports.sendEmailOtp = functions.https.onCall(async (data, context) => {
  const email = data.email;
  if (!email) {
    throw new functions.https.HttpsError("invalid-argument", "Email is required");
  }

  // Generate 6 digit OTP
  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + 10 * 60 * 1000); // 10 minutes

  // Save OTP in Firestore
  // We keep the collection name "passwordResetOtps" for simplicity or rename to "emailOtps"
  // Let's rename the collection to "emailOtps" for clarity
  await admin.firestore().collection("emailOtps").doc(email).set({
    otp: otp,
    expiresAt: expiresAt,
  });

  console.log(`[DEV ONLY] OTP for ${email} is ${otp}`);

  // Send Email
  const mailOptions = {
    from: "Knockpost <no-reply@knockpost.app>",
    to: email,
    subject: "Your Knockpost Verification Code",
    text: `Your verification code is: ${otp}. It will expire in 10 minutes.`,
  };

  try {
    // We wrap this in a try-catch so it doesn't fail the whole function 
    // if the user hasn't set up SMTP credentials yet. We'll still return success
    // so they can test using the console log.
    await transporter.sendMail(mailOptions);
    console.log(`Email sent to ${email}`);
  } catch (error) {
    console.warn("Failed to send email. Ensure SMTP_USER and SMTP_PASS are set.", error);
  }

  return { success: true };
});

exports.verifyEmailOtp = functions.https.onCall(async (data, context) => {
  const email = data.email;
  const otp = data.otp;
  if (!email || !otp) {
    throw new functions.https.HttpsError("invalid-argument", "Email and OTP are required");
  }

  const otpDocRef = admin.firestore().collection("emailOtps").doc(email);
  const otpDoc = await otpDocRef.get();

  if (!otpDoc.exists) {
    throw new functions.https.HttpsError("not-found", "No OTP request found for this email");
  }

  const otpData = otpDoc.data();
  if (otpData.otp !== otp) {
    throw new functions.https.HttpsError("invalid-argument", "Incorrect OTP");
  }

  if (otpData.expiresAt.toMillis() < Date.now()) {
    throw new functions.https.HttpsError("failed-precondition", "OTP has expired");
  }

  // OTP is valid. We don't delete it yet, we let them proceed.
  return { success: true };
});

exports.resetPasswordWithOtp = functions.https.onCall(async (data, context) => {
  const { email, otp, newPassword } = data;
  if (!email || !otp || !newPassword) {
    throw new functions.https.HttpsError("invalid-argument", "Missing fields");
  }

  const otpDocRef = admin.firestore().collection("emailOtps").doc(email);
  const otpDoc = await otpDocRef.get();

  if (!otpDoc.exists) {
    throw new functions.https.HttpsError("not-found", "No OTP request found for this email");
  }

  const otpData = otpDoc.data();
  if (otpData.otp !== otp) {
    throw new functions.https.HttpsError("invalid-argument", "Incorrect OTP");
  }

  if (otpData.expiresAt.toMillis() < Date.now()) {
    throw new functions.https.HttpsError("failed-precondition", "OTP has expired");
  }

  // OTP is valid, delete it so it can't be reused
  await otpDocRef.delete();

  // Get user by email and update password
  try {
    const userRecord = await admin.auth().getUserByEmail(email);
    await admin.auth().updateUser(userRecord.uid, {
      password: newPassword
    });
  } catch (error) {
    throw new functions.https.HttpsError("internal", "Failed to update user password: " + error.message);
  }

  return { success: true };
});
