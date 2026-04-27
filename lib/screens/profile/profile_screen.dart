import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import 'widgets/profile_header.dart';
import 'widgets/recents_section.dart';
import 'widgets/showcase_grid.dart';
import 'widgets/text_posts_section.dart';
import 'edit_profile_screen.dart';
import 'profile_settings_screen.dart';
import 'widgets/profile_ui_helpers.dart';
import '../../widgets/post_scroll_lock_scope.dart';

/// Own profile screen — shown when tapping the Profile tab in bottom nav.
class ProfileScreen extends StatefulWidget {
  final UserModel user;
  final List<PostModel> posts;

  const ProfileScreen({super.key, required this.user, required this.posts});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late final PostScrollLockController _postScrollLockController;
  late TabController _tabController;
  late UserModel _user;
  late List<PostModel> _posts;

  @override
  void initState() {
    super.initState();
    _postScrollLockController = PostScrollLockController()
      ..register(_scrollController);
    _user = widget.user;
    _posts = widget.posts;
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _postScrollLockController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.posts != oldWidget.posts) {
      setState(() {
        _posts = widget.posts;
      });
    }
  }

  void _openEdit() async {
    final updated = await Navigator.push<UserModel>(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(user: _user)),
    );
    if (updated != null && mounted) {
      setState(() => _user = updated);
    }
  }

  void _openSettings() async {
    final updated = await Navigator.push<UserModel>(
      context,
      MaterialPageRoute(builder: (_) => ProfileSettingsScreen(user: _user)),
    );
    if (updated != null && mounted) {
      setState(() => _user = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: bg,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: bg,
        body: PostScrollLockScope(
          controller: _postScrollLockController,
          child: ValueListenableBuilder<bool>(
            valueListenable: _postScrollLockController,
            builder: (context, isScrollLocked, _) {
              return NestedScrollView(
                controller: _scrollController,
                // ClampingScrollPhysics prevents the bounce gap between tab bar and posts
                physics: isScrollLocked
                    ? const NeverScrollableScrollPhysics()
                    : const ClampingScrollPhysics(),
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  // ── Profile Header ─────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: ProfileHeader(
                      user: _user,
                      onEditTap: _openEdit,
                      showSettingsButton: true,
                      onSettingsTap: _openSettings,
                    ),
                  ),

                  // ── Tab bar ───────────────────────────────────────────────────
                  SliverPersistentHeader(
                    pinned: false,
                    delegate: ProfileStickyTabBarDelegate(
                      ProfileAnimatedTabBar(
                        controller: _tabController,
                        labels: const ['Recents', 'Showcase', 'Thoughts'],
                        activeColor: textColor,
                        inactiveColor: isDark ? Colors.white54 : Colors.black45,
                        backgroundColor: bg,
                      ),
                      bg: bg,
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    // Recents
                    SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: RecentsSection(
                        posts: _posts,
                        user: _user,
                        tabController: _tabController,
                      ),
                    ),
                    // Showcase
                    SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: ShowcaseGrid(
                        posts: _posts,
                        user: _user,
                        tabController: _tabController,
                      ),
                    ),
                    // Text
                    SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: TextPostsSection(
                        posts: _posts,
                        user: _user,
                        tabController: _tabController,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
