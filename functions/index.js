const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.sendPushNotification = functions.firestore
  .document("users/{userId}/notifications/{notificationId}")
  .onWrite(async (change, context) => {
    // If the document was deleted, skip
    if (!change.after.exists) {
      console.log("Notification document was deleted. Skipping.");
      return null;
    }

    const notificationData = change.after.data();
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

    // Fetch the receiver's FCM token
    const userDoc = await admin.firestore().collection("users").doc(receiverId).get();
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

    // Fetch the trigger user's data (to get their name/avatar)
    const triggerUserDoc = await admin.firestore().collection("users").doc(triggerUserId).get();
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
      title = "New Comment";
      body = `${senderName} commented: "${notificationData.commentSnippet || ""}"`;
    } else if (type === "knock") {
      title = "New Knock";
      body = `${senderName} knocked your post!`;
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
