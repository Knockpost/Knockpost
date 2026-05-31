// ═══════════════════════════════════════════════════════════════════════════════
// Knockpost — Notification Sender (Server-Side)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Shared utility for writing notification documents to a user's
// notifications subcollection using the Admin SDK.
//
// Used by:
//   - Firestore triggers (knock, like, view)
//   - sendNotificationToUser callable function
//
// This replaces the client-side direct writes to
//   users/{receiverUid}/notifications/{docId}
// which will be blocked by Firestore Security Rules in Phase 3.
// ═══════════════════════════════════════════════════════════════════════════════

const admin = require("firebase-admin");

/**
 * Send an in-app notification to a user by writing to their notifications subcollection.
 * Uses merge-write for idempotency — same docId = same notification, no duplicates.
 *
 * @param {Object} params
 * @param {string} params.receiverUid - The UID of the notification recipient.
 * @param {string} params.triggerUserId - The UID of the user who caused the notification.
 * @param {string} params.type - Notification type (knock, knockBack, knockAccept, like, waveLike, comment, message, mention).
 * @param {string} [params.postId] - Optional post ID related to the notification.
 * @param {string} [params.commentSnippet] - Optional comment/message snippet.
 * @param {string} [params.docId] - Optional custom document ID. Auto-generated if not provided.
 * @returns {Promise<void>}
 */
async function sendNotification({ receiverUid, triggerUserId, type, postId, commentSnippet, docId }) {
  if (!receiverUid || !triggerUserId || !type) {
    console.error("sendNotification: missing required fields", { receiverUid, triggerUserId, type });
    return;
  }

  // Don't send notification to self
  if (receiverUid === triggerUserId) return;

  // Generate a deterministic doc ID for deduplication if not provided
  const notifDocId = docId || `${type}_${triggerUserId}${postId ? `_${postId}` : ""}`;

  const notifData = {
    type: type,
    triggerUserId: triggerUserId,
    isRead: false,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (postId) notifData.postId = postId;
  if (commentSnippet) notifData.commentSnippet = commentSnippet;

  try {
    await admin.firestore()
      .collection("users")
      .doc(receiverUid)
      .collection("notifications")
      .doc(notifDocId)
      .set(notifData, { merge: true });
  } catch (error) {
    console.error(`Failed to send notification to ${receiverUid}:`, error);
  }
}

/**
 * Delete a notification document from a user's notifications subcollection.
 *
 * @param {string} receiverUid - The UID of the notification owner.
 * @param {string} docId - The notification document ID to delete.
 * @returns {Promise<void>}
 */
async function deleteNotification(receiverUid, docId) {
  if (!receiverUid || !docId) return;

  try {
    await admin.firestore()
      .collection("users")
      .doc(receiverUid)
      .collection("notifications")
      .doc(docId)
      .delete();
  } catch (error) {
    console.error(`Failed to delete notification ${docId} for ${receiverUid}:`, error);
  }
}

module.exports = { sendNotification, deleteNotification };
