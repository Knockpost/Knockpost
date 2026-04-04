import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
// ignore: unnecessary_import
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import '../utils/haptic_helper.dart';
import '../utils/global_post_state.dart';

import '../models/post_model.dart';
import '../models/user_model.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/people_suggestion_strip.dart';
import '../widgets/post_card.dart';
import '../widgets/thought_card.dart';
import 'package:image_picker/image_picker.dart';
import 'create_post/create_post_screen.dart';
import 'create_post/media_editor_screen.dart';
import 'create_post/final_post_screen.dart';
import 'create_post/post_settings_sheet.dart';
import 'create_post/glimpse_editor_screen.dart';
import 'create_post/glimpse_camera_screen.dart';
import 'dart:io';

import 'profile/profile_screen.dart';
import 'reels/reels_screen.dart';
import 'search/search_screen.dart';
import 'messages/messages_list_screen.dart';
import 'notifications/notifications_screen.dart';
import '../widgets/system_nav_bar_fill.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  late final PageController _pageController;
  late final ValueNotifier<int> _navIndexNotifier;
  double _horizontalDragDistance = 0;
  double _scrollDelta = 0;
  bool _showBars = true;
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentNavIndex);
    _navIndexNotifier = ValueNotifier<int>(_currentNavIndex);
  }

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _navIndexNotifier.dispose();
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setCurrentNavIndex(int index) {
    if (_currentNavIndex == index) return;
    setState(() {
      _currentNavIndex = index;
      // Always show bars when switching tabs — only vertical scroll should hide them
      _showBars = true;
      _scrollDelta = 0;
    });
    _navIndexNotifier.value = index;
  }

  void _animateToTab(int index) {
    if (index < 0 || index > 4 || _currentNavIndex == index) return;

    final int diff = (index - _currentNavIndex).abs();
    _setCurrentNavIndex(index);
    
    if (diff == 1) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    } else {
      _pageController.jumpToPage(index);
    }
  }

  void _handleHorizontalSwipeEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final hasStrongFling = velocity.abs() > 550;
    final hasCommittedDrag = _horizontalDragDistance.abs() > 72;

    if (!hasStrongFling && !hasCommittedDrag) {
      _horizontalDragDistance = 0;
      return;
    }

    if (velocity < 0 || _horizontalDragDistance < 0) {
      _animateToTab(_currentNavIndex + 1);
    } else if (velocity > 0 || _horizontalDragDistance > 0) {
      _animateToTab(_currentNavIndex - 1);
    }

    _horizontalDragDistance = 0;
  }

  /// Handle scroll notifications from the feed (Twitter/X behavior)
  /// Hides bars after scrolling down ~50px, shows immediately on scroll up.
  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;

    if (notification is ScrollUpdateNotification) {
      final dy = notification.scrollDelta ?? 0;
      if (dy > 0) {
        // Scrolling down — accumulate distance
        _scrollDelta += dy;
        if (_scrollDelta > 50 && _showBars) {
          setState(() => _showBars = false);
        }
      } else if (dy < 0) {
        // Scrolling up — show immediately
        _scrollDelta = 0;
        if (!_showBars) {
          setState(() => _showBars = true);
        }
      }
    }
    return false;
  }

  final ImagePicker _imagePicker = ImagePicker();

  void _showCreateMenu(
    BuildContext context,
    bool isDark,
    Color bgColor,
    Color textColor,
  ) {
    final sheetBg = isDark ? const Color(0xFF111111) : const Color(0xFFFAFAFA);
    final labelColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subColor = isDark ? const Color(0xFF888888) : const Color(0xFF999999);
    final captionController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final screenHeight = MediaQuery.of(context).size.height;
        return Container(
          height: screenHeight * 0.6,
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Text compose area ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: isDark
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFEEEEEE),
                        child: Icon(
                          Icons.person_outline_rounded,
                          size: 22,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          controller: captionController,
                          maxLines: 3,
                          minLines: 1,
                          style: TextStyle(
                            fontSize: 16,
                            color: labelColor,
                            height: 1.5,
                          ),
                          decoration: InputDecoration(
                            hintText: "What's on your mind?",
                            hintStyle: TextStyle(
                              fontSize: 16,
                              color: subColor,
                              fontWeight: FontWeight.w300,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Send button row
                Padding(
                  padding: const EdgeInsets.only(right: 20, top: 4),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      height: 34,
                      child: TextButton(
                        onPressed: () async {
                          final text = captionController.text.trim();
                          if (text.isEmpty) return;
                          KnockHaptics.tap();
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          final settings = await showPostSettingsSheet(
                            context,
                            isGlimpse: false,
                          );
                          if (settings == null || !mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FinalPostScreen(
                                files: const [],
                                initialCaption: text,
                                isGlimpse: false,
                                selectedDuration: settings.duration,
                                selectedAudience: settings.audience,
                              ),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.white
                              : const Color(0xFF1A1A1A),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          "Send",
                          style: TextStyle(
                            color: isDark ? Colors.black : Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Action list ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _createMenuItem(
                        icon: Icons.camera_alt_rounded,
                        label: "Camera",
                        subtitle: "Capture a moment",
                        isDark: isDark,
                        onTap: () async {
                          KnockHaptics.tap();
                          Navigator.pop(ctx);
                          final XFile? photo = await _imagePicker.pickImage(
                            source: ImageSource.camera,
                            imageQuality: 85,
                          );
                          if (photo != null && mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MediaEditorScreen(
                                  files: [File(photo.path)],
                                  initialCaption: captionController.text.trim(),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      _createMenuItem(
                        icon: Icons.collections_rounded,
                        label: "Photo / Media",
                        subtitle: "Choose from gallery",
                        isDark: isDark,
                        onTap: () async {
                          KnockHaptics.tap();
                          Navigator.pop(ctx);
                          final List<XFile> files =
                              await _imagePicker.pickMultiImage(imageQuality: 80);
                          if (files.isNotEmpty && mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MediaEditorScreen(
                                  files: files.map((e) => File(e.path)).toList(),
                                  initialCaption: captionController.text.trim(),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      _createMenuItem(
                        icon: Icons.auto_awesome_rounded,
                        label: "Glimpse",
                        subtitle: "Share moments with music",
                        isDark: isDark,
                        onTap: () async {
                          KnockHaptics.tap();
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const GlimpseCameraScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _createMenuItem({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final iconBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F0);
    final iconColor = isDark ? Colors.grey.shade300 : const Color(0xFF555555);
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subtitleColor = isDark
        ? const Color(0xFF666666)
        : const Color(0xFF999999);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: titleColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: subtitleColor),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isReelsTab = _currentNavIndex == 2;
    final isProfileTab = _currentNavIndex == 4;
    final bgColor = isReelsTab
        ? Colors.black
        : (isDark ? Colors.black : Colors.white);
    final textColor = isReelsTab
        ? Colors.white
        : (isDark ? Colors.white : Colors.black);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: isReelsTab
            ? Colors.black
            : (isProfileTab ? Colors.transparent : bgColor),
        statusBarIconBrightness: (isDark || isReelsTab)
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: (isDark || isReelsTab)
            ? Brightness.dark
            : Brightness.light,
        systemNavigationBarColor: isReelsTab ? Colors.black : bgColor,
        systemNavigationBarIconBrightness: (isDark || isReelsTab)
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: PopScope(
        canPop: _currentNavIndex == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_currentNavIndex != 0) {
            _animateToTab(0);
          }
        },
        child: Stack(
          children: [
            Scaffold(
              backgroundColor: bgColor,
              // extendBody makes the body render BEHIND the bottomNavigationBar
              // so when nav slides away, content is already there — no white gap!
              extendBody: true,

              // ── FAB (X/Twitter-style fade + scale) ──────────────────
              floatingActionButton: (_currentNavIndex == 0 || _currentNavIndex == 4)
                  ? AnimatedOpacity(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOut,
                      opacity: _showBars ? 1.0 : 0.0,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                        scale: _showBars ? 1.0 : 0.0,
                        child: FloatingActionButton(
                          backgroundColor: textColor,
                          onPressed: () {
                            KnockHaptics.tap();
                            _showCreateMenu(
                              context,
                              isDark,
                              bgColor,
                              textColor,
                            );
                          },
                          child: Icon(Icons.add, color: bgColor),
                        ),
                      ),
                    )
                  : null,

              // ── BODY ────────────────────────────────────────────────────
              body: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (_) {
                  _horizontalDragDistance = 0;
                },
                onHorizontalDragUpdate: (details) {
                  _horizontalDragDistance += details.delta.dx;
                },
                onHorizontalDragEnd: _handleHorizontalSwipeEnd,
                child: SafeArea(
                  top: !(isReelsTab || isProfileTab),
                  bottom: false,
                  child: PageView(
                    controller: _pageController,
                    allowImplicitScrolling: true,
                    dragStartBehavior: DragStartBehavior.down,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: _setCurrentNavIndex,
                    children: [
                      _KeepAlivePage(
                        child: NotificationListener<ScrollNotification>(
                          onNotification: _onScrollNotification,
                          child: NestedScrollView(
                            physics: const ClampingScrollPhysics(),
                            controller: _scrollController,
                            headerSliverBuilder: (context, innerBoxIsScrolled) {
                              return [
                                SliverAppBar(
                                  backgroundColor: bgColor,
                                  surfaceTintColor: bgColor,
                                  elevation: 0,
                                  floating: true,
                                  snap: true,
                                  titleSpacing: 20,
                                  centerTitle: false,
                                  title: Text(
                                    "KnockPost",
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 21,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  actions: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.notifications_none,
                                        color: textColor,
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ];
                            },
                            body: ValueListenableBuilder<Set<String>>(
                              valueListenable: GlobalPostState.deletedPostIds,
                              builder: (context, deletedIds, _) {
                                // For the demo, let's combine some posts for the home feed
                                // Only show the latest own post in Recents
                                final ownPostsSorted = [...demoOwnPosts]
                                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                                final latestOwnPost = ownPostsSorted.isNotEmpty
                                    ? [ownPostsSorted.first]
                                    : <PostModel>[];

                                final allDemoPosts = [
                                  ...latestOwnPost,
                                  ...getDemoPostsForUser('zayn01'),
                                  ...getDemoPostsForUser('saptarshi01'),
                                ];
                                
                                final activePosts = allDemoPosts
                                    .where((p) => !deletedIds.contains(p.id))
                                    .toList()
                                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                                return ListView.builder(
                                  padding: const EdgeInsets.only(bottom: 90),
                                  itemCount: activePosts.length + 1,
                                  itemBuilder: (context, index) {
                                    const stripIndex = 2;
                                    final totalItems = activePosts.length + 1;
                                    final isLast = index == totalItems - 1;
                                    
                                    if (index == stripIndex) {
                                      return const PeopleSuggestionStrip();
                                    }

                                    final postIndex = index < stripIndex ? index : index - 1;
                                    if (postIndex >= activePosts.length) return const SizedBox.shrink();
                                    
                                    final post = activePosts[postIndex];
                                    final author = post.authorId == 'me' ? demoOwnUser : findDemoUserByUsername(post.authorId == 'zayn01' ? 'zayn.malik' : 'saptarshi.nayak') ?? demoOwnUser;

                                    final dividerColor = isDark
                                        ? const Color(0xFF2A2A2A)
                                        : const Color(0xFFE8E8E8);
                                    final divider = Divider(height: 1, thickness: 1, color: dividerColor);

                                    Widget card;
                                    if (post.type == PostType.text) {
                                      card = ThoughtCard(
                                        user: author,
                                        text: post.text,
                                        likes: post.likes,
                                        views: post.views,
                                        postId: post.id,
                                      );
                                    } else {
                                      card = PostCard(
                                        imagePaths: post.imagePaths,
                                        user: author,
                                        caption: post.text,
                                        likes: post.likes,
                                        views: post.views,
                                        postId: post.id,
                                      );
                                    }

                                    return Column(
                                      children: [
                                        divider,
                                        card,
                                        if (isLast) divider,
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const _KeepAlivePage(child: SearchScreen()),
                      ValueListenableBuilder<int>(
                        valueListenable: _navIndexNotifier,
                        builder: (context, currentIndex, _) {
                          return _KeepAlivePage(
                            child: ReelsScreen(isVisible: currentIndex == 2),
                          );
                        },
                      ),
                      const _KeepAlivePage(child: MessagesScreen()),
                      _KeepAlivePage(
                        child: NotificationListener<ScrollNotification>(
                          onNotification: _onScrollNotification,
                          child: ValueListenableBuilder<List<PostModel>>(
                            valueListenable: demoOwnPostsNotifier,
                            builder: (context, currentPosts, child) {
                              return ProfileScreen(
                                user: demoOwnUser,
                                posts: currentPosts,
                              );
                            },
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.logout, color: textColor),
                        onPressed: () {
                          KnockHaptics.tap();
                          logout(context);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // ── BOTTOM NAV BAR ──────────────────────────────────────────
              // ClipRect ensures the nav is clipped as it slides out of view
              bottomNavigationBar: ClipRect(
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  offset: _showBars ? Offset.zero : const Offset(0, 1),
                  child: ValueListenableBuilder<int>(
                    valueListenable: _navIndexNotifier,
                    builder: (context, currentIndex, _) {
                      return CustomBottomNav(
                        currentIndex: currentIndex,
                        onTap: (index) {
                          if (currentIndex == index) return;
                          _animateToTab(index);
                        },
                      );
                    },
                  ),
                ),
              ),
            ),

            // ── SOLID BAR BEHIND SYSTEM NAVIGATION BAR ──────────────────
            // On Android 15+ the system nav bar is always transparent.
            // This draws a solid color behind it so it looks opaque.
            SystemNavBarFill(color: bgColor),
          ],
        ),
      ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  final Widget child;

  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
