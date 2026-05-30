// ═══════════════════════════════════════════════════════════════════════════════
// Knockpost — Cascade Delete Utility
// ═══════════════════════════════════════════════════════════════════════════════
//
// Recursively deletes all data associated with a user account.
// Used by the deleteUserAccount callable Cloud Function.
//
// Uses Admin SDK — bypasses all security rules.
// Designed to be idempotent — calling twice will not throw errors.
// ═══════════════════════════════════════════════════════════════════════════════

const admin = require("firebase-admin");

const db = admin.firestore();

// Lazy-init storage bucket — only accessed when cascade delete is called.
// This avoids a crash when the module is loaded outside a Firebase environment.
function getStorageBucket() {
  return admin.storage().bucket();
}

/**
 * Delete all documents in a subcollection using batched deletes.
 * Firestore does not cascade-delete subcollections, so we must do it manually.
 *
 * @param {FirebaseFirestore.CollectionReference} collectionRef
 * @returns {Promise<number>} Number of documents deleted
 */
async function deleteCollection(collectionRef) {
  let deletedCount = 0;
  const batchSize = 400;

  while (true) {
    const snapshot = await collectionRef.limit(batchSize).get();
    if (snapshot.empty) break;

    const batch = db.batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
      deletedCount++;
    }
    await batch.commit();
  }

  return deletedCount;
}

/**
 * Delete all Storage files under a given prefix (folder).
 *
 * @param {string} prefix - Storage path prefix (e.g., "users/uid123/")
 * @returns {Promise<number>} Number of files deleted
 */
async function deleteStorageFolder(prefix) {
  try {
    const [files] = await getStorageBucket().getFiles({ prefix });
    let count = 0;
    for (const file of files) {
      await file.delete().catch(() => {});
      count++;
    }
    return count;
  } catch (error) {
    console.error(`Error deleting storage folder ${prefix}:`, error);
    return 0;
  }
}

/**
 * Cascade-delete all data for a user.
 *
 * Deletes:
 * 1. All posts by the user (and their subcollections: likes, viewers, threads)
 * 2. All connections involving the user
 * 3. All chat rooms involving the user (and their messages)
 * 4. All notifications for the user
 * 5. All Storage files for the user
 * 6. The user document itself
 *
 * @param {string} uid - The user ID to delete all data for.
 * @returns {Promise<Object>} Summary of what was deleted.
 */
async function cascadeDeleteUser(uid) {
  const summary = {
    posts: 0,
    connections: 0,
    chats: 0,
    notifications: 0,
    storageFiles: 0,
  };

  console.log(`Starting cascade delete for user: ${uid}`);

  // ── 1. Delete all posts by this user + subcollections ──
  try {
    const postsSnapshot = await db.collection("posts")
      .where("authorId", "==", uid)
      .get();

    for (const postDoc of postsSnapshot.docs) {
      // Delete subcollections first
      await deleteCollection(postDoc.ref.collection("likes"));
      await deleteCollection(postDoc.ref.collection("viewers"));

      // Delete thread subcollections (threads -> messages)
      const threadsSnapshot = await postDoc.ref.collection("threads").get();
      for (const threadDoc of threadsSnapshot.docs) {
        await deleteCollection(threadDoc.ref.collection("messages"));
        await threadDoc.ref.delete();
      }

      // Delete the post document
      await postDoc.ref.delete();
      summary.posts++;
    }
  } catch (error) {
    console.error("Error deleting user posts:", error);
  }

  // ── 2. Delete all connections involving this user ──
  try {
    // Connections where this user is the sender
    const sentSnapshot = await db.collection("connections")
      .where("fromUid", "==", uid)
      .get();
    const batch1 = db.batch();
    for (const doc of sentSnapshot.docs) {
      batch1.delete(doc.ref);
      summary.connections++;
    }
    if (!sentSnapshot.empty) await batch1.commit();

    // Connections where this user is the receiver
    const receivedSnapshot = await db.collection("connections")
      .where("toUid", "==", uid)
      .get();
    const batch2 = db.batch();
    for (const doc of receivedSnapshot.docs) {
      batch2.delete(doc.ref);
      summary.connections++;
    }
    if (!receivedSnapshot.empty) await batch2.commit();
  } catch (error) {
    console.error("Error deleting user connections:", error);
  }

  // ── 3. Delete all chats involving this user ──
  try {
    const chatsSnapshot = await db.collection("chats")
      .where("participants", "array-contains", uid)
      .get();

    for (const chatDoc of chatsSnapshot.docs) {
      await deleteCollection(chatDoc.ref.collection("messages"));
      await chatDoc.ref.delete();
      summary.chats++;
    }
  } catch (error) {
    console.error("Error deleting user chats:", error);
  }

  // ── 4. Delete all notifications ──
  try {
    const notifsRef = db.collection("users").doc(uid).collection("notifications");
    summary.notifications = await deleteCollection(notifsRef);
  } catch (error) {
    console.error("Error deleting user notifications:", error);
  }

  // ── 5. Delete Storage files ──
  try {
    const userFiles = await deleteStorageFolder(`users/${uid}/`);
    const postFiles = await deleteStorageFolder(`posts/${uid}/`);
    summary.storageFiles = userFiles + postFiles;
  } catch (error) {
    console.error("Error deleting user storage files:", error);
  }

  // ── 6. Delete the user document itself ──
  try {
    // Delete OTP subcollection first
    await deleteCollection(db.collection("users").doc(uid).collection("otp"));
    await db.collection("users").doc(uid).delete();
  } catch (error) {
    console.error("Error deleting user document:", error);
  }

  console.log(`Cascade delete complete for ${uid}:`, summary);
  return summary;
}

module.exports = { cascadeDeleteUser, deleteCollection, deleteStorageFolder };
