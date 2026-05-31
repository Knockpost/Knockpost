import 'package:flutter/material.dart';
import 'package:knockpost/widgets/knockpost_refresh.dart';
import '../models/user_model.dart';
import '../screens/profile/other_profile_screen.dart';
import '../utils/haptic_helper.dart';
import '../theme/app_typography.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/like_service.dart';
import '../services/post_service.dart';
import '../services/current_user_service.dart';
import '../services/database_service.dart';
import '../widgets/knockpost_avatar.dart';

class PostAnalyticsSheet extends StatefulWidget {
  final String postId;
  final int initialIndex;
  final String? userReaction;
  final int totalViews;

  const PostAnalyticsSheet({
    super.key,
    required this.postId,
    this.initialIndex = 0,
    this.userReaction,
    this.totalViews = 0,
  });

  static void show(
    BuildContext context, {
    required String postId,
    int initialIndex = 0,
    String? userReaction,
    int totalViews = 0,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PostAnalyticsSheet(
        postId: postId,
        initialIndex: initialIndex,
        userReaction: userReaction,
        totalViews: totalViews,
      ),
    );
  }

  @override
  State<PostAnalyticsSheet> createState() => _PostAnalyticsSheetState();
}

class _PostAnalyticsSheetState extends State<PostAnalyticsSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        KnockHaptics.selection();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      height: MediaQuery.of(context).size.height * 0.65 + MediaQuery.of(context).viewPadding.bottom,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          
          // Tab Bar
          Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: textColor,
              unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
              indicatorColor: textColor,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: AppTypography.sectionHeader,
              unselectedLabelStyle: AppTypography.sectionHeader,
              dividerColor: isDark ? Colors.white10 : Colors.black12,
              tabs: [
                Tab(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: PostService.instance.getPostViewers(widget.postId),
                    builder: (context, snapshot) {
                      // Use actual subcollection count as single source of truth.
                      // Fall back to totalViews only while loading.
                      final count = snapshot.hasData
                          ? snapshot.data!.length
                          : widget.totalViews;
                      return Text.rich(
                        TextSpan(
                          text: "Views ",
                          children: [
                            TextSpan(
                              text: "($count)",
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Tab(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: LikeService.instance.getPostReactions(widget.postId),
                    builder: (context, snapshot) {
                      final count = snapshot.hasData ? snapshot.data!.length : 0;
                      return Text.rich(
                        TextSpan(
                          text: "Reactions ",
                          children: [
                            TextSpan(
                              text: "($count)",
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Views Tab
                _ViewsList(
                  postId: widget.postId,
                  totalViews: widget.totalViews,
                  isDark: isDark,
                  bgColor: bgColor,
                  textColor: textColor,
                ),

                // Reactions Tab
                _ReactionsList(
                  postId: widget.postId,
                  isDark: isDark,
                  bgColor: bgColor,
                  textColor: textColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Views List ──────────────────────────────────────────────────────────────

class _ViewsList extends StatelessWidget {
  final String postId;
  final int totalViews;
  final bool isDark;
  final Color bgColor;
  final Color textColor;

  const _ViewsList({
    required this.postId,
    required this.totalViews,
    required this.isDark,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: PostService.instance.getPostViewers(postId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: KnockPostLoadingIndicator());
        }

        final viewers = snapshot.data ?? [];
        
        if (viewers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.visibility_off_outlined,
                  size: 48,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
                const SizedBox(height: 16),
                Text(
                  "No views yet",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: viewers.length,
          itemBuilder: (context, index) {
            final viewer = viewers[index];
                        final String userId = viewer['userId'];
                        final Timestamp? viewedAt = viewer['viewedAt'];
                        
                        String timeAgo = '';
                        if (viewedAt != null) {
                          final diff = DateTime.now().difference(viewedAt.toDate());
                          if (diff.inMinutes < 1) {
                            timeAgo = 'Just now';
                          } else if (diff.inHours < 1) {
                            timeAgo = '${diff.inMinutes}m ago';
                          } else if (diff.inHours < 24) {
                            timeAgo = '${diff.inHours}h ago';
                          } else if (diff.inDays < 7) {
                            timeAgo = '${diff.inDays}d ago';
                          } else {
                            timeAgo = '${(diff.inDays / 7).floor()}w ago';
                          }
                        }

                        return FutureBuilder<Map<String, dynamic>?>(
                          future: DatabaseService.instance.getUserProfile(userId, useCache: true),
                          builder: (context, snap) {
                            final data = snap.data;
                            if (data == null) {
                              return const SizedBox.shrink();
                            }
                            final user = UserModel.fromMap(data, userId);

                            return _UserTile(
                              user: user,
                              timeString: timeAgo,
                              isDark: isDark,
                              bgColor: bgColor,
                              textColor: textColor,
                            );
                          },
                        );
                      },
        );
      },
    );
  }
}

// ── Reactions List ──────────────────────────────────────────────────────────────

class _ReactionsList extends StatelessWidget {
  final String postId;
  final bool isDark;
  final Color bgColor;
  final Color textColor;

  const _ReactionsList({
    required this.postId,
    required this.isDark,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: LikeService.instance.getPostReactions(postId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: KnockPostLoadingIndicator());
        }

        final reactors = snapshot.data ?? [];

        if (reactors.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.favorite_border_rounded,
                  size: 48,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
                const SizedBox(height: 16),
                Text(
                  "No reactions yet",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          );
        }

        final currentUser = CurrentUserService.instance.currentUser;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: reactors.length,
          itemBuilder: (context, index) {
            final reactor = reactors[index];
            final String userId = reactor['userId'];
            final String reaction = reactor['reaction'] ?? '❤';

            if (userId == currentUser?.id) {
              return _UserTile(
                user: currentUser!,
                reaction: reaction,
                isDark: isDark,
                bgColor: bgColor,
                textColor: textColor,
              );
            }

            return FutureBuilder<Map<String, dynamic>?>(
              future: DatabaseService.instance.getUserProfile(userId, useCache: true),
              builder: (context, snap) {
                final data = snap.data;
                if (data == null) {
                  return const SizedBox.shrink();
                }
                final user = UserModel.fromMap(data, userId);

                return _UserTile(
                  user: user,
                  reaction: reaction,
                  isDark: isDark,
                  bgColor: bgColor,
                  textColor: textColor,
                );
              },
            );
          },
        );
      },
    );
  }
}

// ── Generic User Tile ──────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final UserModel user;
  final String? reaction; // If null, it's a view
  final String? timeString;
  final bool isDark;
  final Color bgColor;
  final Color textColor;

  const _UserTile({
    required this.user,
    this.reaction,
    this.timeString,
    required this.isDark,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        KnockHaptics.selection();
        Navigator.pop(context);
        if (!user.isOwnProfile) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtherProfileScreen(
                user: user,
                posts: const [],
              ),
            ),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                KnockPostAvatar(
                  url: user.avatarAsset,
                  radius: 24,
                  name: user.displayName,
                ),
                if (reaction != null)
                  Positioned(
                    right: -4,
                    bottom: -2,
                    child: Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F0),
                        shape: BoxShape.circle,
                        border: Border.all(color: bgColor, width: 2.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        reaction!,
                        style: const TextStyle(fontSize: 12, height: 1.1),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.username.isEmpty ? '...' : user.username,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.displayName.isEmpty ? '...' : user.displayName,
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontSize: 13.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (timeString != null && timeString!.isNotEmpty) ...[
                        Text(
                          ' • ',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontSize: 13.5,
                          ),
                        ),
                        Text(
                          timeString!,
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Profile',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
