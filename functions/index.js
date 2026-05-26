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
