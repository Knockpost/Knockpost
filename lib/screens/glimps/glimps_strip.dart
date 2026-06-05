import 'package:flutter/material.dart';
import '../../../models/post_model.dart';
import '../../../models/user_model.dart';
import '../../../services/post_service.dart';
import '../../../services/current_user_service.dart';
import '../../../services/database_service.dart';
import '../../../services/glimps_feed_manager.dart';
import 'glimps_card.dart';

class GlimpsStrip extends StatefulWidget {
  const GlimpsStrip({super.key});

  @override
  State<GlimpsStrip> createState() => _GlimpsStripState();
}

class _GlimpsStripState extends State<GlimpsStrip> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (GlimpsFeedManager.instance.glimpses.isEmpty) {
      GlimpsFeedManager.instance.loadInitial();
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (GlimpsFeedManager.instance.hasMore && !GlimpsFeedManager.instance.isLoadingMore) {
        GlimpsFeedManager.instance.loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: GlimpsFeedManager.instance,
      builder: (context, _) {
        final allGlimpses = GlimpsFeedManager.instance.glimpses;
        final authorsCache = GlimpsFeedManager.instance.authors;

        if (allGlimpses.isEmpty && !GlimpsFeedManager.instance.isLoading) return const SizedBox.shrink();
        
        if (allGlimpses.isEmpty && GlimpsFeedManager.instance.isLoading) {
           return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
        }

        // Group by authorId
        final Map<String, List<PostModel>> groupedGlimpses = {};
        for (final glimpse in allGlimpses) {
          if (!groupedGlimpses.containsKey(glimpse.authorId)) {
            groupedGlimpses[glimpse.authorId] = [];
          }
          groupedGlimpses[glimpse.authorId]!.add(glimpse);
        }

        // Get unique authors list (maintain order of first glimpse appearance)
        final authorIds = groupedGlimpses.keys.toList();

        // Move current user to front if they have glimpses
        final currentUser = CurrentUserService.instance.currentUser;
        if (currentUser != null && authorIds.contains(currentUser.id)) {
          authorIds.remove(currentUser.id);
          authorIds.insert(0, currentUser.id);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: isDark ? Colors.white : Colors.black87,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Glimpses",
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),

            // ── Horizontal Glimpse Carousel ──
            SizedBox(
              height: MediaQuery.sizeOf(context).width * 0.53 * (16 / 9),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: authorIds.length + (GlimpsFeedManager.instance.isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == authorIds.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final authorId = authorIds[index];
                  final userGlimpses = groupedGlimpses[authorId]!;
                  final firstGlimpse = userGlimpses.first;
                  
                  if (currentUser != null && authorId == currentUser.id) {
                    return GlimpsCard(
                      glimpse: firstGlimpse,
                      user: currentUser,
                      allGlimpses: userGlimpses,
                      glimpseIndex: 0,
                      groupedGlimpses: groupedGlimpses,
                      authorIds: authorIds,
                      initialAuthorIndex: index,
                      preloadedUsers: {currentUser.id: currentUser},
                    );
                  }

                  // Non-blocking UI cache lookup
                  final author = authorsCache[authorId] ?? 
                      UserModel(id: authorId, displayName: 'User', username: '...');

                  return GlimpsCard(
                    glimpse: firstGlimpse,
                    user: author,
                    allGlimpses: userGlimpses,
                    glimpseIndex: 0,
                    groupedGlimpses: groupedGlimpses,
                    authorIds: authorIds,
                    initialAuthorIndex: index,
                    preloadedUsers: authorsCache,
                  );
                },
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}
