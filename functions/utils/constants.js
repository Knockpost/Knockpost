// ═══════════════════════════════════════════════════════════════════════════════
// Knockpost — Shared Constants
// ═══════════════════════════════════════════════════════════════════════════════

// Creator Rank thresholds — must stay in sync with database_service.dart:32-43
const CREATOR_RANK_THRESHOLDS = {
  impact: { totalViews: 10000, totalLikes: 5000, totalKnocksReceived: 500 },
  pro:    { totalViews: 5000,  totalLikes: 2000, totalKnocksReceived: 100 },
  plus:   { totalViews: 1000,  totalLikes: 500,  totalKnocksReceived: 50 },
  echo:   { totalViews: 0,     totalLikes: 0,    totalKnocksReceived: 0 },
};

// Rank order from highest to lowest
const RANK_ORDER = ["impact", "pro", "plus", "echo"];

module.exports = {
  CREATOR_RANK_THRESHOLDS,
  RANK_ORDER,
};
