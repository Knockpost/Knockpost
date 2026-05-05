import 'package:flutter/material.dart';
import '../../utils/global_knock_state.dart';
import '../../utils/global_dismiss_state.dart';
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
import '../../widgets/post_scroll_lock_scope.dart';
import '../../widgets/system_nav_bar_fill.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/post_service.dart';
import '../../services/connection_service.dart';
import '../../services/database_service.dart';
import '../../services/current_user_service.dart';

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
  final ScrollController _scrollController = ScrollController();
  late final PostScrollLockController _postScrollLockController;
  late TabController _tabController;
  late UserModel _user;
  List<PostModel> _posts = [];

  @override
  void initState() {
    super.initState();
    _postScrollLockController = PostScrollLockController()
      ..register(_scrollController);
    _user = widget.user;

    // Always fetch the freshest status from global state
    final globalStatus = GlobalKnockState.getNotifier(
      _user.id,
      _user.knockStatus,
    ).value;
    if (_user.knockStatus != globalStatus) {
      _user = _user.copyWith(knockStatus: globalStatus);
    }

    _tabController = TabController(length: 3, vsync: this);

    // Load posts from Firestore
    PostService.instance.getUserPosts(_user.id).listen((posts) {
      if (mounted) setState(() => _posts = posts);
    });

    // Fetch the latest knock status from Firestore
    ConnectionService.instance.getKnockStatus(_user.id).then((status) {
      if (mounted && _user.knockStatus != status) {
        setState(() => _user = _user.copyWith(knockStatus: status));
        GlobalKnockState.getNotifier(_user.id, status).value = status;
      }
    });
  }

  @override
  void dispose() {
    _postScrollLockController.dispose();
    _scrollController.dispose();
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

    // Broadcast status to all listeners (e.g. PostCard, SuggestionStrip)
    GlobalKnockState.getNotifier(_user.id, status).value = status;

    widget.onKnockStatusChanged?.call(status);
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          otherUser: _user,
        ),
      ),
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
                  onTap: () {
                    Share.share(
                      'Check out ${_user.username} on KnockPost!\nhttps://knockpost.app/@${_user.username}',
                    );
                  },
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
                  icon: Icons.visibility_off_outlined,
                  label: 'Not Interested',
                  onTap: () {
                    GlobalDismissState.dismiss(_user.id);
                    toast("We'll show less content from @${_user.username}");
                  },
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
                  onTap: () async {
                    GlobalDismissState.dismiss(_user.id);
                    final myUid = CurrentUserService.instance.currentUser?.id;
                    if (myUid != null) {
                      await DatabaseService.instance.blockUser(myUid: myUid, targetUid: _user.id);
                      await CurrentUserService.instance.refresh();
                    }
                    toast('@${_user.username} has been blocked');
                  },
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

    final isLocked = !_user.isContentVisible;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: bg,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: bg,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: bg,
            body: PostScrollLockScope(
              controller: _postScrollLockController,
              child: ValueListenableBuilder<bool>(
                valueListenable: _postScrollLockController,
                builder: (context, isScrollLocked, _) {
                  return NestedScrollView(
                    controller: _scrollController,
                    physics: isScrollLocked
                        ? const NeverScrollableScrollPhysics()
                        : const ClampingScrollPhysics(),
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

                      if (!isLocked)
                        SliverPersistentHeader(
                          pinned: false,
                          delegate: ProfileStickyTabBarDelegate(
                            ProfileAnimatedTabBar(
                              controller: _tabController,
                              labels: const ['Recents', 'Showcase', 'Thoughts'],
                              activeColor: textColor,
                              inactiveColor: isDark
                                  ? Colors.white54
                                  : Colors.black45,
                              backgroundColor: bg,
                            ),
                            bg: bg,
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
                                child: RecentsSection(
                                  posts: _posts,
                                  user: _user,
                                  tabController: _tabController,
                                  isOwnProfile: false,
                                ),
                              ),
                              SingleChildScrollView(
                                physics: const NeverScrollableScrollPhysics(),
                                child: ShowcaseGrid(
                                  posts: _posts,
                                  user: _user,
                                  tabController: _tabController,
                                  isOwnProfile: false,
                                ),
                              ),
                              SingleChildScrollView(
                                physics: const NeverScrollableScrollPhysics(),
                                child: TextPostsSection(
                                  posts: _posts,
                                  user: _user,
                                  tabController: _tabController,
                                  isOwnProfile: false,
                                ),
                              ),
                            ],
                          ),
                  );
                },
              ),
            ),
          ),

          // ── SOLID BAR BEHIND SYSTEM NAVIGATION BAR ──────────────────
          // On Android 15+ the system nav bar is always transparent.
          // This draws a solid color behind it so it looks opaque.
          SystemNavBarFill(color: bg),
        ],
      ),
    );
  }
}
