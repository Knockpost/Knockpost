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

/// Own profile screen — shown when tapping the Profile tab in bottom nav.
class ProfileScreen extends StatefulWidget {
  final UserModel user;
  final List<PostModel> posts;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.posts,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late UserModel _user;
  late List<PostModel> _posts;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _posts = widget.posts;
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openEdit() async {
    final updated = await Navigator.push<UserModel>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(user: _user),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _user = updated);
    }
  }

  void _openSettings() async {
    final updated = await Navigator.push<UserModel>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileSettingsScreen(user: _user),
      ),
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
    final divColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: bg,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: bg,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              backgroundColor: bg,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              floating: true,
              snap: true,
              pinned: false,
              automaticallyImplyLeading: false,
              titleSpacing: 16,
              centerTitle: false,
              title: Text(
                _user.username,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              actions: [
                // Settings gear
                IconButton(
                  icon: Icon(Icons.settings_outlined,
                      color: textColor, size: 24),
                  onPressed: _openSettings,
                ),
              ],
            ),

            // ── Profile Header ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: ProfileHeader(
                user: _user,
                onEditTap: _openEdit,
              ),
            ),

            // ── Divider ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Divider(height: 1, color: divColor),
              ),
            ),

            // ── Tab bar ────────────────────────────────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBarDelegate(
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
          body: TabBarView(
            controller: _tabController,
            children: [
              // Recents
              SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: RecentsSection(posts: _posts),
              ),
              // Showcase
              SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: ShowcaseGrid(posts: _posts),
              ),
              // Text
              SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: TextPostsSection(posts: _posts),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pinned tab bar delegate for SliverPersistentHeader
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color bg;
  final Color divColor;

  const _StickyTabBarDelegate(this.tabBar,
      {required this.bg, required this.divColor});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          tabBar,
          Divider(height: 1, color: divColor),
        ],
      ),
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  double get minExtent => tabBar.preferredSize.height + 1;

  @override
  bool shouldRebuild(_StickyTabBarDelegate old) =>
      old.tabBar != tabBar || old.bg != bg;
}
