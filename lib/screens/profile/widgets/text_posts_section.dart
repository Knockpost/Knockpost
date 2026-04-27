import 'package:flutter/material.dart';
import '../../../models/post_model.dart';
import '../../../models/user_model.dart';
import '../../thoughts/thought_card.dart';
import '../../../utils/global_post_state.dart';
import '../../../widgets/staggered_entry_animation.dart';
import 'profile_ui_helpers.dart';

/// Scrollable list of text-only posts (Thoughts tab on profile).
/// Uses the same ThoughtCard widget as the home feed.
class TextPostsSection extends StatelessWidget {
  final List<PostModel> posts;
  final UserModel? user;
  final TabController? tabController;
  final bool isOwnProfile;

  const TextPostsSection({
    super.key,
    required this.posts,
    this.user,
    this.tabController,
    this.isOwnProfile = true,
  });

  List<PostModel> get _textPosts =>
      posts.where((p) => p.type == PostType.text).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<Set<String>>(
      valueListenable: GlobalPostState.deletedPostIds,
      builder: (context, deletedIds, _) {
        final textPosts = _textPosts.where((p) => !deletedIds.contains(p.id)).toList();

        if (textPosts.isEmpty) {
          return ProfileEmptySection(
            icon: Icons.format_quote_rounded,
            message: 'No thoughts yet',
            subtitle: isOwnProfile
                ? 'Share what you feel'
                : 'No thoughts shared yet',
            gradientColors: const [Color(0xFFB388FF), Color(0xFF7C4DFF)],
            tabController: tabController,
            tabIndex: 2,
          );
        }

        final dividerColor = isDark
            ? const Color(0xFF2A2A2A)
            : const Color(0xFFE8E8E8);

        final divider = Divider(height: 1, thickness: 1, color: dividerColor);

        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: textPosts.length,
          itemBuilder: (context, i) {
            final post = textPosts[i];
            final isLast = i == textPosts.length - 1;

            return StaggeredEntryAnimation(
              index: i,
              child: Column(
                children: [
                  divider,
                  ThoughtCard(
                    user: user ?? const UserModel(
                      id: 'unknown',
                      displayName: 'User',
                      username: 'user',
                      friendsCount: 0,
                      accountType: AccountType.normal,
                      knockStatus: KnockStatus.none,
                    ),
                    text: post.text,
                    likes: post.likes,
                    views: post.views,
                    postId: post.id,
                    disableProfileNavigation: true,
                    timestamp: post.timestampText,
                  ),
                  if (isLast) divider,
                ],
              ),
            );
          },
        );
      },
    );
  }
}
