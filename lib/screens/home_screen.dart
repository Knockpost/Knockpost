import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
// ignore: unnecessary_import
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import '../utils/haptic_helper.dart';
import '../utils/global_post_state.dart';
import '../utils/image_helper.dart';
import '../widgets/knockpost_avatar.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../theme/app_typography.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/people_suggestion_strip.dart';
import '../widgets/knockpost_refresh.dart';
import 'post/post_card.dart';
import 'thoughts/thought_card.dart';
import 'waves/waves_feed_card.dart';
import 'package:image_picker/image_picker.dart';
import 'glimps/glimps_strip.dart';
import 'post/media_editor_screen.dart';
import 'post/image_crop_screen.dart';
import 'post/video_post_editor_screen.dart';
import 'shared/final_post_screen.dart';
import 'waves/waves_editor_screen.dart';
import 'waves/waves_camera_screen.dart';
import 'waves/waves_gallery_sheet.dart';

import 'profile/profile_screen.dart';
import 'waves/waves_feed_screen.dart';
import 'search/search_screen.dart';
import 'messages/messages_list_screen.dart';
import 'notifications/notifications_screen.dart';
import '../widgets/post_scroll_lock_scope.dart';
import '../utils/waves_feed_state.dart';
import '../services/current_user_service.dart';
import '../services/post_service.dart';
import '../services/notification_service.dart';
import '../services/performance_service.dart';
import '../services/feed_cache_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  late final PostScrollLockController _postScrollLockController;
  late final PostPageSwipeLockController _postPageSwipeLockController;
  late final PageController _pageController;
  late final ValueNotifier<int> _navIndexNotifier;
  double _scrollDelta = 0;
  final ValueNotifier<bool> _showBarsNotifier = ValueNotifier<bool>(true);
  int _currentNavIndex = 0;
  int _feedSeed = 0;

  List<({PostModel post, UserModel author})> _feedItems = [];
  List<({PostModel post, UserModel author})> _processedFeedItems = [];
  bool _isLoadingFeed = true;
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastFeedDoc;
  bool _hasMoreFeed = true;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.initFCM();
    _scrollController.addListener(_onScroll);
    _postScrollLockController = PostScrollLockController()
      ..register(_scrollController);
    _pageController = PageController(initialPage: _currentNavIndex);
    _postPageSwipeLockController = PostPageSwipeLockController()
      ..register(_pageController);
    _navIndexNotifier = ValueNotifier<int>(_currentNavIndex);
    GlobalPostState.deletedPostIds.addListener(_onDeletedPostsChanged);
    _loadFeed(refresh: true);
  }

  void _onDeletedPostsChanged() {
    final deletedIds = GlobalPostState.deletedPostIds.value;
    bool changed = false;
    final newProcessed = _processedFeedItems.where((item) {
      if (deletedIds.contains(item.post.id)) {
        changed = true;
        return false;
      }
      return true;
    }).toList();
    
    if (changed) {
      setState(() {
        _processedFeedItems = newProcessed;
      });
    }
  }

  void _processAndAppendFeedItems(List<({PostModel post, UserModel author})> newItems, {bool isRefresh = false}) {
    if (isRefresh) {
      _processedFeedItems.clear();
      _feedSeed = DateTime.now().millisecondsSinceEpoch;
    }

    final deletedIds = GlobalPostState.deletedPostIds.value;
    final filteredNew = newItems.where((item) => 
      !deletedIds.contains(item.post.id) && 
      item.post.type != PostType.glimps
    ).toList();
    
    // Sort the new batch safely
    filteredNew.sort((a, b) => b.post.createdAt.compareTo(a.post.createdAt));
    
    // Interleave waves for the new batch
    final interleavedNew = <({PostModel post, UserModel author})>[];
    final pendingWaves = <({PostModel post, UserModel author})>[];
    for (final item in filteredNew) {
      if (item.post.type == PostType.waves) {
        if (interleavedNew.isNotEmpty && interleavedNew.last.post.type == PostType.waves) {
          pendingWaves.add(item);
        } else {
          interleavedNew.add(item);
        }
      } else {
        interleavedNew.add(item);
        if (pendingWaves.isNotEmpty) {
          interleavedNew.add(pendingWaves.removeAt(0));
        }
      }
    }
    // Fix: add any remaining waves that weren't added
    interleavedNew.addAll(pendingWaves);
    
    // Shuffle the new batch independently if seed is set
    if (_feedSeed != 0 && interleavedNew.isNotEmpty) {
      // Use _processedFeedItems.length to offset the seed, ensuring stable shuffle per batch
      interleavedNew.shuffle(Random(_feedSeed + _processedFeedItems.length));
    }

    _processedFeedItems.addAll(interleavedNew);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 800) {
      _loadFeed(refresh: false);
    }
  }

  Future<void> _loadFeed({bool refresh = false, bool isManualRefresh = false}) async {
    if (isManualRefresh) {
      if (!FeedCacheService.instance.canManualRefresh) {
        if (FeedCacheService.instance.hasValidCache && _feedItems.isEmpty) {
          final cache = FeedCacheService.instance.getCache()!;
          setState(() {
            _feedItems = cache.posts;
            _processAndAppendFeedItems(cache.posts, isRefresh: true);
            _lastFeedDoc = cache.lastDoc;
            _hasMoreFeed = true;
            _isLoadingFeed = false;
          });
        }
        return;
      }
      FeedCacheService.instance.recordManualRefresh();
      FeedCacheService.instance.clear();
    }

    if (refresh) {
      if (!isManualRefresh && FeedCacheService.instance.hasValidCache) {
        final cache = FeedCacheService.instance.getCache()!;
        setState(() {
          _feedItems = cache.posts;
          _processAndAppendFeedItems(cache.posts, isRefresh: true);
          _lastFeedDoc = cache.lastDoc;
          _hasMoreFeed = true;
          _isLoadingFeed = false;
        });
        return; // Restored the return to prevent continuous background fetching
      } else {
        if (_isLoadingFeed && _feedItems.isNotEmpty) return;
        setState(() {
          _hasMoreFeed = true;
          _lastFeedDoc = null;
          _isLoadingFeed = true;
        });
      }
    } else {
      if (!_hasMoreFeed || _isLoadingMore || _isLoadingFeed) return;
      setState(() => _isLoadingMore = true);
    }

    final stopWatch = Stopwatch()..start();
    final currentUser = CurrentUserService.instance.currentUser;
    
    final result = await PostService.instance.getFeedPostsPaginated(
      currentUserId: currentUser?.id ?? '',
      currentUserModel: currentUser,
      startAfter: refresh ? null : _lastFeedDoc,
      limit: 25,
    );

    stopWatch.stop();
    PerformanceService.instance.recordFeedPageLoad(
      result.posts.length,
      stopWatch.elapsedMilliseconds,
      isRefresh: refresh,
    );

    if (mounted) {
      setState(() {
        if (refresh) {
          _feedItems = result.posts;
          _processAndAppendFeedItems(result.posts, isRefresh: true);
          FeedCacheService.instance.saveCache(result.posts, result.lastDoc);
        } else {
          _feedItems.addAll(result.posts);
          _processAndAppendFeedItems(result.posts, isRefresh: false);
          FeedCacheService.instance.appendCache(result.posts, result.lastDoc);
        }
        _lastFeedDoc = result.lastDoc;
        _hasMoreFeed = result.hasMore;
        _isLoadingFeed = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    CurrentUserService.instance.clear();
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
    GlobalPostState.deletedPostIds.removeListener(_onDeletedPostsChanged);
    _postScrollLockController.dispose();
    _postPageSwipeLockController.dispose();
    _navIndexNotifier.dispose();
    _showBarsNotifier.dispose();
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setCurrentNavIndex(int index) {
    if (_currentNavIndex == index) return;
    setState(() {
      _currentNavIndex = index;
      _scrollDelta = 0;
    });
    // Always show bars when switching tabs — only vertical scroll should hide them
    _showBarsNotifier.value = true;
    _navIndexNotifier.value = index;
  }

  void _animateToTab(int index) {
    if (index < 0 || index > 4 || _currentNavIndex == index) return;

    _setCurrentNavIndex(index);
    _pageController.jumpToPage(index);
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
        if (_scrollDelta > 50 && _showBarsNotifier.value) {
          _showBarsNotifier.value = false;
        }
      } else if (dy < 0) {
        // Scrolling up — show immediately
        _scrollDelta = 0;
        if (!_showBarsNotifier.value) {
          _showBarsNotifier.value = true;
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
    final sheetBg = isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F8F8);
    final labelColor = isDark ? Colors.white : const Color(0xFF111111);
    final subColor = isDark ? const Color(0xFF777777) : const Color(0xFF888888);
    final captionController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final screenHeight = MediaQuery.of(context).size.height;
        final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
        return Container(
          height: screenHeight * 0.68 + bottomPadding,
          padding: EdgeInsets.only(bottom: bottomPadding),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 30,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 22),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ValueListenableBuilder<UserModel?>(
                        valueListenable:
                            CurrentUserService.instance.userNotifier,
                        builder: (context, currentUser, _) {
                          return KnockPostAvatar(
                            url: currentUser?.avatarAsset,
                            radius: 21,
                            name: currentUser?.displayName,
                          );
                        },
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          controller: captionController,
                          maxLines: null,
                          minLines: 1,
                          textInputAction: TextInputAction.newline,
                          keyboardType: TextInputType.multiline,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: labelColor,
                            height: 1.5,
                          ),
                          decoration: InputDecoration(
                            hintText: "What's on your mind?",
                            hintStyle: TextStyle(
                              fontSize: 16,
                              color: subColor,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.only(
                              top: 8,
                              bottom: 8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: SizedBox(
                          width: 60,
                          height: 35,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6C63FF), Color(0xFF48CAE4)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                customBorder: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                onTap: () async {
                                  final text = captionController.text.trim();
                                  if (text.isEmpty) return;
                                  KnockHaptics.tap();
                                  Navigator.pop(ctx);
                                  if (!context.mounted) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FinalPostScreen(
                                        files: const [],
                                        initialCaption: text,
                                        isGlimpse: false,
                                      ),
                                    ),
                                  );
                                },
                                child: const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06),
                ),

                const SizedBox(height: 8),

                _createMenuItem(
                  icon: Icons.camera_rounded,
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
                    if (photo != null && context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ImageCropScreen(
                            files: [File(photo.path)],
                            initialCaption: captionController.text.trim(),
                            onDone: (croppedFiles, aspectRatio) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MediaEditorScreen(
                                    files: croppedFiles,
                                    initialCaption: captionController.text
                                        .trim(),
                                    aspectRatio: aspectRatio,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 7),
                _createMenuItem(
                  icon: Icons.photo_library_rounded,
                  label: "Post",
                  subtitle: "Choose photos or a video",
                  isDark: isDark,
                  onTap: () async {
                    KnockHaptics.tap();
                    Navigator.pop(ctx);
                    if (!context.mounted) return;
                    final result = await showModalBottomSheet<List<File>>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const FractionallySizedBox(
                        heightFactor: 0.95,
                        child: ClipRRect(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                          child: WavesGallerySheet(showCreativeTools: false),
                        ),
                      ),
                    );

                    if (result != null &&
                        result.isNotEmpty &&
                        context.mounted) {
                      final isVideo =
                          result.first.path.toLowerCase().endsWith('.mp4') ||
                          result.first.path.toLowerCase().endsWith('.mov') ||
                          result.first.path.toLowerCase().endsWith('.mkv');
                      if (isVideo) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VideoPostEditorScreen(
                              videoFile: result.first,
                              initialCaption: captionController.text.trim(),
                              isGlimpse: false,
                            ),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ImageCropScreen(
                              files: result,
                              initialCaption: captionController.text.trim(),
                              isGlimpse: false,
                              onDone: (croppedFiles, aspectRatio) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MediaEditorScreen(
                                      files: croppedFiles,
                                      initialCaption: captionController.text
                                          .trim(),
                                      aspectRatio: aspectRatio,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 7),
                _createMenuItem(
                  icon: Icons.auto_awesome_rounded,
                  label: "Glimpse",
                  subtitle: "Share moments with music",
                  isDark: isDark,
                  onTap: () async {
                    KnockHaptics.tap();
                    Navigator.pop(ctx);
                    if (!context.mounted) return;
                    final result = await showModalBottomSheet<List<File>>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const FractionallySizedBox(
                        heightFactor: 0.95,
                        child: ClipRRect(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                          child: WavesGallerySheet(),
                        ),
                      ),
                    );

                    if (result != null &&
                        result.isNotEmpty &&
                        context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WavesEditorScreen(
                            files: result,
                            initialCaption: captionController.text.trim(),
                            isGlimpse: true,
                          ),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 7),
                _createMenuItem(
                  icon: Icons.play_circle_outline_rounded,
                  label: "Waves",
                  subtitle: "Reels, shorts & lipsync videos",
                  isDark: isDark,
                  onTap: () async {
                    KnockHaptics.tap();
                    Navigator.pop(ctx);
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WavesCameraScreen(),
                      ),
                    );
                  },
                ),

                SizedBox(
                  height: MediaQuery.of(ctx).padding.bottom > 0 ? 12 : 24,
                ),
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
    List<Color> accentColors = const [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
    List<Color> lightAccentColors = const [
      Color(0xFFF0F0F0),
      Color(0xFFE0E0E0),
    ],
  }) {
    final titleColor = isDark ? Colors.white : const Color(0xFF111111);
    final subtitleColor = isDark
        ? const Color(0xFF606060)
        : const Color(0xFF888888);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        highlightColor: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark ? accentColors : lightAccentColors,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: isDark
                      ? Colors.grey.shade300
                      : const Color(0xFF444444),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.buttonLabel.copyWith(color: titleColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.metadata.copyWith(color: subtitleColor),
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
    final bgColor = isReelsTab
        ? Colors.black
        : (isDark ? Colors.black : Colors.white);
    final textColor = isReelsTab
        ? Colors.white
        : (isDark ? Colors.white : Colors.black);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: (isDark || isReelsTab)
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: (isDark || isReelsTab)
            ? Brightness.dark
            : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
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
            _pageController.jumpToPage(0);
          }
        },
        child: Scaffold(
          backgroundColor: bgColor,
          // extendBody makes the body render BEHIND the bottomNavigationBar
          // so when nav slides away, content is already there — no white gap!
          extendBody: true,

          // ── FAB (X/Twitter-style fade + scale) ──────────────────
          floatingActionButton: (_currentNavIndex == 0 || _currentNavIndex == 4)
              ? ValueListenableBuilder<bool>(
                  valueListenable: _showBarsNotifier,
                  builder: (context, showBars, _) {
                    return AnimatedOpacity(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOut,
                      opacity: showBars ? 1.0 : 0.0,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                        scale: showBars ? 1.0 : 0.0,
                        child: FloatingActionButton(
                          backgroundColor: const Color(0xFF1B1D1F),
                          onPressed: () {
                            KnockHaptics.tap();
                            _showCreateMenu(context, isDark, bgColor, textColor);
                          },
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    );
                  },
                )
              : null,

          // ── BODY ────────────────────────────────────────────────────
          body: SafeArea(
            top: false,
            bottom: false,
            child: PostPageSwipeLockScope(
              controller: _postPageSwipeLockController,
              child: ValueListenableBuilder<bool>(
                valueListenable: _postPageSwipeLockController,
                builder: (context, isPageSwipeLocked, _) {
                  return PageView(
                    controller: _pageController,
                    physics: isPageSwipeLocked
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    allowImplicitScrolling: true,
                    onPageChanged: _setCurrentNavIndex,
                    children: [
                      _KeepAlivePage(
                        child: NotificationListener<ScrollNotification>(
                          onNotification: _onScrollNotification,
                          child: PostScrollLockScope(
                            controller: _postScrollLockController,
                            child: ValueListenableBuilder<bool>(
                              valueListenable: _postScrollLockController,
                              builder: (context, isScrollLocked, _) {
                                return KnockPostRefreshIndicator(
                                  onRefresh: () async {
                                    KnockHaptics.tap();
                                    await _loadFeed(refresh: true, isManualRefresh: true);
                                  },
                                  child: NestedScrollView(
                                    physics: isScrollLocked
                                        ? const NeverScrollableScrollPhysics()
                                        : const AlwaysScrollableScrollPhysics(
                                            parent:
                                                ClampingScrollPhysics(),
                                          ),
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
                                            style: AppTypography.appTitle.copyWith(color: textColor),
                                          ),
                                          actions: [
                                            StreamBuilder<int>(
                                              stream: NotificationService
                                                  .instance
                                                  .streamUnreadCount(),
                                              builder: (context, snapshot) {
                                                final unreadCount =
                                                    snapshot.data ?? 0;
                                                return Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    IconButton(
                                                      icon: Icon(
                                                        Icons
                                                            .notifications_none,
                                                        color: textColor,
                                                      ),
                                                      onPressed: () {
                                                        KnockHaptics.tap();
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (_) =>
                                                                const NotificationsScreen(),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                    if (unreadCount > 0)
                                                      Positioned(
                                                        top: 12,
                                                        right: 12,
                                                        child: Container(
                                                          width: 10,
                                                          height: 10,
                                                          decoration:
                                                              BoxDecoration(
                                                                color: Colors
                                                                    .redAccent,
                                                                shape: BoxShape
                                                                    .circle,
                                                                border:
                                                                    Border.all(
                                                                      color:
                                                                          bgColor,
                                                                      width: 2,
                                                                    ),
                                                              ),
                                                        ),
                                                      ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ];
                                    },
                                    body: _isLoadingFeed
                                        ? const KnockPostLoadingIndicator()
                                        : PostInnerScrollLockRegistrar(
                                            child: CustomScrollView(
                                              cacheExtent: 3000,
                                              physics: isScrollLocked
                                                  ? const NeverScrollableScrollPhysics()
                                                  : null,
                                              slivers: [
                                                SliverPadding(
                                                  padding: const EdgeInsets.only(bottom: 90),
                                                  sliver: SliverList(
                                                    delegate: SliverChildBuilderDelegate(
                                                      (context, index) {
                                                        const glimpseStripIndex = 1;
                                                        const peopleStripIndex = 3;
                                                        final totalItems = _processedFeedItems.length + 2 + (_isLoadingMore ? 1 : 0);
                                                        final isLast = index == totalItems - 1;

                                                        if (_isLoadingMore && isLast) {
                                                          return const Padding(
                                                            padding: EdgeInsets.symmetric(vertical: 20),
                                                            child: Center(
                                                              child: CircularProgressIndicator(strokeWidth: 2),
                                                            ),
                                                          );
                                                        }

                                                        if (index == glimpseStripIndex) {
                                                          return Column(
                                                            children: [
                                                              const GlimpsStrip(),
                                                              Padding(
                                                                padding: const EdgeInsets.only(top: 6, bottom: 2),
                                                                child: Container(
                                                                  height: 2.5,
                                                                  margin: const EdgeInsets.symmetric(horizontal: 20),
                                                                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
                                                                ),
                                                              ),
                                                            ],
                                                          );
                                                        }
                                                        if (index == peopleStripIndex) {
                                                          return Column(
                                                            children: [
                                                              const PeopleSuggestionStrip(),
                                                              Padding(
                                                                padding: const EdgeInsets.only(top: 6, bottom: 2),
                                                                child: Container(
                                                                  height: 2.5,
                                                                  margin: const EdgeInsets.symmetric(horizontal: 20),
                                                                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
                                                                ),
                                                              ),
                                                            ],
                                                          );
                                                        }

                                                        int postIndex = index;
                                                        if (index > peopleStripIndex) {
                                                          postIndex -= 2;
                                                        } else if (index > glimpseStripIndex) {
                                                          postIndex -= 1;
                                                        }

                                                        if (postIndex >= _processedFeedItems.length) {
                                                          return const SizedBox.shrink();
                                                        }

                                                        final item = _processedFeedItems[postIndex];
                                                        final post = item.post;
                                                        final author = item.author;

                                                        Widget card;
                                                        if (post.type == PostType.text) {
                                                          card = ThoughtCard(
                                                            user: author,
                                                            text: post.text,
                                                            likes: post.likes,
                                                            views: post.views,
                                                            postId: post.id,
                                                            timestamp: post.timestampText,
                                                          );
                                                        } else if (post.type == PostType.waves) {
                                                          card = WavesFeedCard(
                                                            post: post,
                                                            user: author,
                                                            onTap: () {
                                                              final videoUrl = post.imagePaths.isNotEmpty ? post.imagePaths.first : null;
                                                              if (videoUrl != null) {
                                                                WavesFeedState.requestedVideoUrl.value = videoUrl;
                                                              }
                                                              _animateToTab(2);
                                                            },
                                                          );
                                                        } else {
                                                          card = PostCard(
                                                            key: ValueKey(post.id),
                                                            imagePaths: post.imagePaths,
                                                            optimizedImagePaths: post.optimizedImagePaths,
                                                            user: author,
                                                            caption: post.text,
                                                            likes: post.likes,
                                                            views: post.views,
                                                            postId: post.id,
                                                            timestamp: post.timestampText,
                                                            musicUrl: post.musicUrl,
                                                            musicTitle: post.musicTitle,
                                                            musicArtist: post.musicArtist,
                                                            musicCoverUrl: post.musicCoverUrl,
                                                            musicTrimStart: post.musicTrimStart,
                                                            musicStickerConfig: post.musicStickerConfig,
                                                            musicVolume: post.musicVolume,
                                                            originalAudioVolume: post.originalAudioVolume,
                                                            filterIndex: post.filterIndex,
                                                            textOverlays: post.textOverlays,
                                                            drawPaths: post.drawPaths,
                                                            isVideoPost: post.isVideoPost || post.type == PostType.waves,
                                                            videoHasSound: post.videoHasSound,
                                                            coverImagePath: post.coverImagePath,
                                                            mediaAspectRatio: post.mediaAspectRatio,
                                                            mediaIsBaked: post.mediaIsBaked,
                                                          );
                                                        }

                                                        return Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            card,
                                                            if (!isLast)
                                                              Padding(
                                                                padding: const EdgeInsets.only(top: 6, bottom: 2),
                                                                child: Container(
                                                                  height: 2.5,
                                                                  margin: const EdgeInsets.symmetric(horizontal: 20),
                                                                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
                                                                ),
                                                              ),
                                                          ],
                                                        );
                                                      },
                                                      childCount: _processedFeedItems.length + 2 + (_isLoadingMore ? 1 : 0),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),
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
                            child: WavesFeedScreen(
                              isVisible: currentIndex == 2,
                            ),
                          );
                        },
                      ),
                      const _KeepAlivePage(child: MessagesScreen()),
                      _KeepAlivePage(
                        child: NotificationListener<ScrollNotification>(
                          onNotification: _onScrollNotification,
                          child: ValueListenableBuilder<UserModel?>(
                            valueListenable:
                                CurrentUserService.instance.userNotifier,
                            builder: (context, liveUser, child) {
                              final user = liveUser;
                              if (user == null) {
                                return const KnockPostLoadingIndicator();
                              }
                              return StreamBuilder<List<PostModel>>(
                                stream: PostService.instance.getUserPosts(
                                  user.id,
                                ),
                                builder: (context, snapshot) {
                                  final currentPosts = snapshot.data ?? [];
                                  return ProfileScreen(
                                    user: user,
                                    posts: currentPosts,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // ── BOTTOM NAV BAR ──────────────────────────────────────────
          // ClipRect ensures the nav is clipped as it slides out of view
          bottomNavigationBar: ClipRect(
            child: ValueListenableBuilder<bool>(
              valueListenable: _showBarsNotifier,
              builder: (context, showBars, _) {
                return AnimatedSlide(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  offset: showBars ? Offset.zero : const Offset(0, 1),
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
                );
              },
            ),
          ),
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
