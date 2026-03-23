import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import 'widgets/profile_header.dart';
import 'widgets/private_lock_overlay.dart';
import 'widgets/recents_section.dart';
import 'widgets/showcase_grid.dart';
import 'widgets/text_posts_section.dart';
import 'widgets/profile_ui_helpers.dart';

/// Viewing someone ELSE's profile.
class OtherProfileScreen extends StatefulWidget {
  final UserModel user;
  final List<PostModel> posts;

  const OtherProfileScreen({
    super.key,
    required this.user,
    required this.posts,
  });

  @override
  State<OtherProfileScreen> createState() => _OtherProfileScreenState();
}

class _OtherProfileScreenState extends State<OtherProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late UserModel _user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _sendKnock() {
    final nextStatus = _user.privacyType == PrivacyType.open
        ? KnockStatus.knocked
        : KnockStatus.pending;
    setState(() {
      _user = _user.copyWith(knockStatus: nextStatus);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final divColor =
        isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);

    final isLocked = !_user.isContentVisible;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: bg,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: bg,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [

            // Profile Header
            SliverToBoxAdapter(
              child: ProfileHeader(
                user: _user,
                showBackButton: true,
                onKnockStatusChanged: (status) {
                  setState(() {
                    _user = _user.copyWith(knockStatus: status);
                  });
                },
                onMessageTap: () {
                  // Navigate to messages
                },
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Divider(height: 1, color: divColor),
              ),
            ),

            if (!isLocked)
              SliverPersistentHeader(
                pinned: true,
                delegate: ProfileStickyTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    labelColor: textColor,
                    unselectedLabelColor:
                        isDark ? Colors.white38 : Colors.black38,
                    indicatorColor: textColor,
                    indicatorSize: TabBarIndicatorSize.label,
                    indicatorWeight: 2,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    tabs: const [
                      Tab(text: 'Recents'),
                      Tab(text: 'Showcase'),
                      Tab(text: 'Text'),
                    ],
                  ),
                  bg: bg,
                  divColor: divColor,
                ),
              ),
          ],
          body: isLocked
              ? SingleChildScrollView(
                  child: PrivateLockOverlay(
                    knockStatus: _user.knockStatus,
                    onKnock: _sendKnock,
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: RecentsSection(posts: widget.posts),
                    ),
                    SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: ShowcaseGrid(posts: widget.posts),
                    ),
                    SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: TextPostsSection(posts: widget.posts),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
