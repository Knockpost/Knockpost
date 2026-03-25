import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../utils/haptic_helper.dart';
import '../messages/chat_screen.dart';
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
  final ValueChanged<KnockStatus>? onKnockStatusChanged;

  const OtherProfileScreen({
    super.key,
    required this.user,
    required this.posts,
    this.onKnockStatusChanged,
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
    final nextStatus = _user.isEffectivelyOpen
        ? KnockStatus.knocked
        : KnockStatus.pending;
    _updateKnockStatus(nextStatus);
  }

  void _updateKnockStatus(KnockStatus status) {
    setState(() => _user = _user.copyWith(knockStatus: status));
    widget.onKnockStatusChanged?.call(status);
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
  }

  void _showProfileActions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF171717) : Colors.white;
    final div = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEAEAEA);
    final textColor = isDark ? Colors.white : Colors.black87;
    const danger = Color(0xFFE53935);

    Widget action({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      Color? color,
    }) {
      final effectiveColor = color ?? textColor;
      return InkWell(
        onTap: () {
          KnockHaptics.selection();
          Navigator.pop(context);
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: effectiveColor),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  color: effectiveColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    void toast(String message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    }

    KnockHaptics.tap();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: div),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 8),
                action(
                  icon: Icons.share_outlined,
                  label: 'Share profile',
                  onTap: () => toast('Profile share options will appear here.'),
                ),
                action(
                  icon: Icons.link_rounded,
                  label: 'Copy profile link',
                  onTap: () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text: 'https://knockpost.app/@${_user.username}',
                      ),
                    );
                    toast('Profile link copied');
                  },
                ),
                action(
                  icon: Icons.info_outline_rounded,
                  label: 'About this account',
                  onTap: () => toast('Account insights panel coming soon.'),
                ),
                Divider(height: 1, color: div),
                action(
                  icon: Icons.visibility_off_outlined,
                  label: 'Restrict',
                  onTap: () => toast('@${_user.username} has been restricted'),
                ),
                action(
                  icon: Icons.block_outlined,
                  label: 'Block',
                  color: danger,
                  onTap: () => toast('@${_user.username} has been blocked'),
                ),
                action(
                  icon: Icons.flag_outlined,
                  label: 'Report',
                  color: danger,
                  onTap: () => toast('Thanks. Report submitted.'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final divColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);

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
                showSettingsButton: true,
                onBackTap: () => Navigator.of(context).maybePop(),
                onSettingsTap: _showProfileActions,
                onKnockStatusChanged: _updateKnockStatus,
                onMessageTap: _openChat,
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
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
                    unselectedLabelColor: isDark
                        ? Colors.white38
                        : Colors.black38,
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
