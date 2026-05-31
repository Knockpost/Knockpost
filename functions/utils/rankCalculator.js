// ═══════════════════════════════════════════════════════════════════════════════
// Knockpost — Creator Rank Calculator (Server-Side)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Mirrors the rank calculation logic from:
//   lib/services/database_service.dart:16-54
//
// Called by Firestore triggers after stat changes (likes, views, knocks).
// Uses Admin SDK — bypasses security rules.
// ═══════════════════════════════════════════════════════════════════════════════

const admin = require("firebase-admin");
const { CREATOR_RANK_THRESHOLDS } = require("./constants");

/**
 * Recalculate and update the creator rank for a given user.
 * Only updates if the user is a "creator" account type and the rank has changed.
 *
 * @param {string} uid - The user ID to recalculate rank for.
 * @returns {Promise<void>}
 */
async function recalculateCreatorRank(uid) {
  try {
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    if (!userDoc.exists) return;

    const data = userDoc.data();
    if (data.accountType !== "creator") return;

    const totalViews = data.totalViews || 0;
    const totalLikes = data.totalLikes || 0;
    const totalKnocks = data.totalKnocksReceived || 0;

    let newRank = "echo";

    if (
      totalViews >= CREATOR_RANK_THRESHOLDS.impact.totalViews &&
      totalLikes >= CREATOR_RANK_THRESHOLDS.impact.totalLikes &&
      totalKnocks >= CREATOR_RANK_THRESHOLDS.impact.totalKnocksReceived
    ) {
      newRank = "impact";
    } else if (
      totalViews >= CREATOR_RANK_THRESHOLDS.pro.totalViews &&
      totalLikes >= CREATOR_RANK_THRESHOLDS.pro.totalLikes &&
      totalKnocks >= CREATOR_RANK_THRESHOLDS.pro.totalKnocksReceived
    ) {
      newRank = "pro";
    } else if (
      totalViews >= CREATOR_RANK_THRESHOLDS.plus.totalViews &&
      totalLikes >= CREATOR_RANK_THRESHOLDS.plus.totalLikes &&
      totalKnocks >= CREATOR_RANK_THRESHOLDS.plus.totalKnocksReceived
    ) {
      newRank = "plus";
    }

    // Only write if rank actually changed
    const currentRank = data.rank || "echo";
    if (currentRank !== newRank) {
      await admin.firestore().collection("users").doc(uid).update({
        rank: newRank,
      });
      console.log(`Rank updated for ${uid}: ${currentRank} → ${newRank}`);
    }
  } catch (error) {
    console.error(`Error recalculating rank for ${uid}:`, error);
  }
}

module.exports = { recalculateCreatorRank };
