import '../models/post_model.dart';
import '../models/daily_glimpse_card_model.dart';

class DailyGlimpseService {
  DailyGlimpseService._internal();
  static final DailyGlimpseService instance = DailyGlimpseService._internal();

  /// Groups a user's active glimpses by calendar date
  List<DailyGlimpseCard> groupGlimpsesByDate(List<PostModel> glimpses) {
    final Map<String, List<PostModel>> grouped = {};
    
    for (final glimpse in glimpses) {
      if (!glimpse.isActiveForArchive) continue;
      
      final date = glimpse.createdAt.toLocal();
      // YYYY-MM-DD key
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(glimpse);
    }
    
    final cards = <DailyGlimpseCard>[];
    for (final entry in grouped.entries) {
      final dateParts = entry.key.split('-');
      final date = DateTime(
        int.parse(dateParts[0]), 
        int.parse(dateParts[1]), 
        int.parse(dateParts[2])
      );
      
      final glimpseIds = entry.value.map((e) => e.id).toList();
      
      // Find the most recent createdAt in this group
      DateTime newestCreatedAt = entry.value.first.createdAt;
      for(final glimpse in entry.value) {
        if(glimpse.createdAt.isAfter(newestCreatedAt)) {
          newestCreatedAt = glimpse.createdAt;
        }
      }
      
      cards.add(DailyGlimpseCard(
        id: '${entry.value.first.authorId}_${entry.key}',
        userId: entry.value.first.authorId,
        date: date,
        glimpseIds: glimpseIds,
        createdAt: newestCreatedAt,
      ));
    }
    
    // Sort cards newest date first
    cards.sort((a, b) => b.date.compareTo(a.date));
    return cards;
  }
  
  /// Filters out expired glimpses based on their duration
  List<PostModel> filterActiveGlimpses(List<PostModel> glimpses) {
    return glimpses.where((g) => g.isActiveForArchive).toList();
  }

  /// Returns active daily cards (cards with at least 1 non-expired glimpse)
  List<DailyGlimpseCard> getActiveDailyCards(List<PostModel> allPosts) {
    final glimpses = allPosts.where((p) => p.type == PostType.glimps).toList();
    return groupGlimpsesByDate(glimpses);
  }
  
  /// Checks if a daily card is the newest (today's date) for animated ring
  bool isNewestCard(DailyGlimpseCard card) {
    final now = DateTime.now();
    return card.date.year == now.year && 
           card.date.month == now.month && 
           card.date.day == now.day;
  }
  
  /// Returns the glimpses for a specific card, sorted by upload time ascending
  List<PostModel> getGlimpsesForCard(DailyGlimpseCard card, List<PostModel> allGlimpses) {
    final glimpses = allGlimpses.where((g) => card.glimpseIds.contains(g.id)).toList();
    glimpses.sort((a, b) => a.createdAt.compareTo(b.createdAt)); // Chronological play order
    return glimpses;
  }
}
