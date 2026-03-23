import 'package:flutter/material.dart';
import '../../../models/user_model.dart';

/// Color-coded rank chip shown on Creator profiles.
/// ECHO = grey | PLUS = blue | PRO = purple | IMPACT = gold
class CreatorRankBadge extends StatelessWidget {
  final CreatorRank rank;
  final bool large;

  const CreatorRankBadge({super.key, required this.rank, this.large = false});

  static Color rankColor(CreatorRank rank) {
    switch (rank) {
      case CreatorRank.echo:
        return const Color(0xFF8A8A8A);
      case CreatorRank.plus:
        return const Color(0xFF2B8EFF);
      case CreatorRank.pro:
        return const Color(0xFF9B59B6);
      case CreatorRank.impact:
        return const Color.fromARGB(223, 244, 167, 0);
    }
  }

  static Color rankTextColor(CreatorRank rank) {
    switch (rank) {
      case CreatorRank.echo:
        return Colors.white;
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = rankColor(rank);
    final label = rank.name.toUpperCase();
    final fs = large ? 11.0 : 9.0;
    final px = large ? 9.0 : 7.0;
    final py = large ? 4.0 : 2.5;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: px, vertical: py),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, Colors.black, 0.18)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fs,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Rank explanation tooltip / info card shown in settings
class RankInfoCard extends StatelessWidget {
  const RankInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const ranks = [
      (CreatorRank.echo, 'ECHO', 'Starting rank. Keep posting to grow.'),
      (CreatorRank.plus, 'PLUS', '500+ likes or 5K+ views.'),
      (CreatorRank.pro, 'PRO', '2K+ likes or 20K+ views.'),
      (CreatorRank.impact, 'IMPACT', '10K+ likes or 100K+ views.'),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Creator Ranks',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          ...ranks.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CreatorRankBadge(rank: r.$1, large: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      r.$3,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
