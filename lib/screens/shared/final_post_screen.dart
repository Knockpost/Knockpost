import 'dart:io';
import 'package:knockpost/widgets/knockpost_refresh.dart';

import 'package:flutter/material.dart';

import '../../models/post_model.dart';
import '../../utils/haptic_helper.dart';
import '../../services/post_service.dart';
import '../../services/current_user_service.dart';
import '../../services/glimps_feed_manager.dart';
import '../../services/performance_service.dart';
import '../../models/user_model.dart';
import '../../utils/image_helper.dart';
import '../../widgets/knockpost_avatar.dart';
import '../profile/profile_screen.dart';
import 'music_picker_screen.dart';
import 'post_settings_sheet.dart';
import 'friend_picker_screen.dart';

class FinalPostScreen extends StatefulWidget {
  final List<File> files;
  final String? initialCaption;
  final bool isGlimpse;
  final bool isWaves;
  final PostDuration selectedDuration;
  final PostAudience selectedAudience;
  final MusicTrack? initialMusic;
  final int? initialTrimSeconds;
  final Map<String, dynamic>? initialMusicStickerConfig;
  final double? initialMusicVolume;
  final double? initialOriginalAudioVolume;
  final double? mediaAspectRatio;
  final bool mediaIsBaked;
  final bool isVideoPost;
  final bool videoHasSound;
  final File? coverImageFile;

  final int? initialFilterIndex;
  final List<Map<String, dynamic>>? initialTextOverlays;
  final List<Map<String, dynamic>>? initialDrawPaths;
  final Map<String, dynamic>? initialMediaTransform;

  const FinalPostScreen({
    super.key,
    required this.files,
    this.initialCaption,
    this.isGlimpse = false,
    this.isWaves = false,
    this.selectedDuration = PostDuration.h24,
    this.selectedAudience = PostAudience.myFriends,
    this.initialMusic,
    this.initialTrimSeconds,
    this.initialMusicStickerConfig,
    this.initialMusicVolume,
    this.initialOriginalAudioVolume,
    this.mediaAspectRatio,
    this.mediaIsBaked = false,
    this.isVideoPost = false,
    this.videoHasSound = false,
    this.coverImageFile,
    this.initialFilterIndex,
    this.initialTextOverlays,
    this.initialDrawPaths,
    this.initialMediaTransform,
  });

  @override
  State<FinalPostScreen> createState() => _FinalPostScreenState();
}

class _FinalPostScreenState extends State<FinalPostScreen>
    with TickerProviderStateMixin {
  late TextEditingController _captionController;
  late PostDuration _selectedDuration;
  late PostAudience _selectedAudience;
  List<String> _selectedFriendsExcept = [];
  List<String> _selectedOnlyShareWith = [];

  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(
      text: widget.initialCaption ?? "",
    );
    _selectedDuration = widget.selectedDuration;
    _selectedAudience = widget.selectedAudience;
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  // ─── POST CONTENT ──────────────────────────────────────────
  Future<void> _postContent() async {
    if (_isPosting) return;

    final currentUser = CurrentUserService.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to post.')),
      );
      return;
    }

    setState(() => _isPosting = true);
    KnockHaptics.tap();

    final type = widget.isWaves
        ? PostType.waves
        : (widget.isGlimpse
            ? PostType.glimps
            : (widget.files.isEmpty ? PostType.text : PostType.media));

    final newPost = PostModel(
      id: 'p_${DateTime.now().millisecondsSinceEpoch}_${currentUser.id}',
      authorId: currentUser.id,
      type: type,
      duration: _selectedDuration,
      imagePaths: widget.isGlimpse ? widget.files.map((e) => e.path).toList() : [],
      mediaAspectRatio: widget.mediaAspectRatio,
      mediaIsBaked: widget.mediaIsBaked,
      isVideoPost: widget.isVideoPost,
      videoHasSound: widget.videoHasSound,
      coverImagePath: widget.isGlimpse ? widget.coverImageFile?.path : null,
      text: _captionController.text.trim(),
      musicUrl: widget.initialMusic?.previewUrl,
      musicTitle: widget.initialMusic?.title,
      musicArtist: widget.initialMusic?.artist,
      musicCoverUrl: widget.initialMusic?.coverUrl,
      musicStickerConfig: widget.initialMusicStickerConfig,
      musicTrimStart: widget.initialTrimSeconds ?? 0,
      musicVolume: widget.initialMusicVolume,
      originalAudioVolume: widget.initialOriginalAudioVolume,
      filterIndex: widget.initialFilterIndex,
      textOverlays: widget.initialTextOverlays,
      drawPaths: widget.initialDrawPaths,
      mediaTransform: widget.initialMediaTransform,
      createdAt: DateTime.now(),
      likes: 0,
      views: 0,
      isLikedByMe: false,
    );

    if (widget.isGlimpse) {
      GlimpsFeedManager.instance.addGlimpseOptimistically(newPost, currentUser);
      PerformanceService.instance.incrementGlimpsUploadStarted();
      final startTime = DateTime.now();
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      PostService.instance.createPost(
        post: newPost,
        mediaFiles: widget.files,
        coverFile: widget.coverImageFile,
      ).then((_) {
        final durationMs = DateTime.now().difference(startTime).inMilliseconds;
        PerformanceService.instance.logGlimpsUploadCompleted(durationMs);
      }).catchError((e) {
        PerformanceService.instance.incrementGlimpsUploadFailed();
        GlimpsFeedManager.instance.removeGlimpse(newPost.id);
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Failed to upload Glimpse: $e')),
        );
      });

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      return;
    }

    // Show a loading dialog for non-Glimpse posts
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: KnockpostLoadingIndicator()),
    );

    try {
      await PostService.instance.createPost(
        post: newPost,
        mediaFiles: widget.files,
        coverFile: widget.coverImageFile,
      );

      if (mounted) {
        Navigator.pop(context); // Pop loading dialog
        Navigator.of(context).popUntil((route) => route.isFirst); // Pop back to home screen
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPosting = false);
        Navigator.pop(context); // Pop loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create post: $e')),
        );
      }
    }
  }

  // ─── DURATION HELPERS ──────────────────────────────────────
  int get _durationIndex {
    switch (_selectedDuration) {
      case PostDuration.h24:
        return 0;
      case PostDuration.h36:
        return 1;
      case PostDuration.lifetime:
        return 2;
    }
  }

  String _getDurationSubtitle() {
    switch (_selectedDuration) {
      case PostDuration.h24:
        return 'Disappears after one day';
      case PostDuration.h36:
        return 'Extended temporary visibility';
      case PostDuration.lifetime:
        return 'Stays on your profile permanently';
    }
  }

  // ─── MEDIA PREVIEW THUMB ───────────────────────────────────
  Widget _buildComposerPreviewThumb(bool isDark) {
    if (widget.isVideoPost) {
      final previewFile = widget.coverImageFile;
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Container(
              width: 84,
              height: 112,
              color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF2F2F2),
              child: previewFile != null
                  ? Image.file(previewFile, fit: BoxFit.cover)
                  : const Center(
                      child: Icon(Icons.videocam_rounded, color: Colors.white),
                    ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.videoHasSound
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.isGlimpse) {
      return Container(
        width: 80,
        height: 120,
        color: Colors.grey.shade800,
        child: const Center(child: Icon(Icons.videocam, color: Colors.white)),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        widget.files.first,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
      ),
    );
  }

  // ─── DURATION TOGGLE (sliding pill) ────────────────────────
  Widget _buildDurationToggle(bool isDark) {
    final labels = ['24h', '36h', 'Lifetime'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final segmentWidth = (constraints.maxWidth - 8) / 3;

        return Container(
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1A1A1A)
                : const Color(0xFFF3F3F3),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            children: [
              // ── Sliding active pill ──
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                left: _durationIndex * segmentWidth,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF333333)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                ),
              ),
              // ── Tap targets ──
              Row(
                children: List.generate(3, (i) {
                  final isActive = _durationIndex == i;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        KnockHaptics.tap();
                        setState(() {
                          switch (i) {
                            case 0:
                              _selectedDuration = PostDuration.h24;
                              break;
                            case 1:
                              _selectedDuration = PostDuration.h36;
                              break;
                            case 2:
                              _selectedDuration = PostDuration.lifetime;
                              break;
                          }
                        });
                      },
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight:
                                isActive ? FontWeight.w700 : FontWeight.w500,
                            letterSpacing: 0.3,
                            color: isActive
                                ? (isDark ? Colors.white : Colors.black)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.35)
                                    : Colors.black.withValues(alpha: 0.35)),
                          ),
                          child: Text(labels[i]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── AUDIENCE OPTION ───────────────────────────────────────
  Widget _buildAudienceOption(PostAudience aud, bool isDark) {
    final isSelected = _selectedAudience == aud;

    // Softer palette
    final selectedBg = isDark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFF0F0F0);
    final unselectedBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.025);

    return GestureDetector(
      onTap: () async {
        KnockHaptics.tap();
        if (aud == PostAudience.myFriendsExcept) {
          final result = await showFriendPickerScreen(
            context,
            title: aud.label,
            subtitle: aud.subtitle,
            accentColor: isDark ? Colors.white : Colors.black,
            initiallySelected: _selectedFriendsExcept,
            useExcludeMode: true,
          );
          if (result != null) {
            setState(() {
              _selectedAudience = aud;
              _selectedFriendsExcept = result;
            });
          }
        } else if (aud == PostAudience.onlyShareWith) {
          final result = await showFriendPickerScreen(
            context,
            title: aud.label,
            subtitle: aud.subtitle,
            accentColor: isDark ? Colors.white : Colors.black,
            initiallySelected: _selectedOnlyShareWith,
          );
          if (result != null) {
            setState(() {
              _selectedAudience = aud;
              _selectedOnlyShareWith = result;
            });
          }
        } else {
          setState(() => _selectedAudience = aud);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : unselectedBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.08))
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Icon(
              aud.icon,
              size: 20,
              color: isSelected
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.35)),
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    aud.label,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    aud.subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.4)
                          : Colors.black.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            // Radio indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black)
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.15)),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check_rounded,
                      size: 12,
                      color: isDark ? Colors.black : Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Section Header ────────────────────────────────────────
  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: isDark
            ? Colors.white.withValues(alpha: 0.35)
            : Colors.black.withValues(alpha: 0.4),
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        surfaceTintColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 19,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Post Settings",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 17,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Scrollable content ──
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Composer row ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              final currentUser = CurrentUserService.instance.currentUser;
                              if (currentUser != null) {
                                KnockHaptics.tap();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) {
                                      Widget buildScreen(List<PostModel> currentPosts) {
                                        return ProfileScreen(
                                          user: currentUser,
                                          posts: currentPosts,
                                        );
                                      }

                                      return StreamBuilder<List<PostModel>>(
                                        stream: PostService.instance.getUserPosts(currentUser.id),
                                        builder: (context, snapshot) {
                                          return buildScreen(snapshot.data ?? []);
                                        },
                                      );
                                    },
                                  ),
                                );
                              }
                            },
                            child: KnockpostAvatar(
                              url: CurrentUserService.instance.currentUser?.avatarAsset,
                              radius: 18,
                              name: CurrentUserService.instance.currentUser?.displayName,
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (widget.files.isNotEmpty) ...[
                            _buildComposerPreviewThumb(isDark),
                            const SizedBox(width: 14),
                          ],
                          Expanded(
                            child: TextField(
                              controller: _captionController,
                              maxLines: widget.files.isNotEmpty ? 4 : null,
                              minLines: widget.files.isNotEmpty ? 1 : 3,
                              style: TextStyle(
                                fontSize: 15.5,
                                height: 1.45,
                                fontWeight: FontWeight.w400,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              decoration: InputDecoration(
                                hintText: "Write a caption...",
                                hintStyle: TextStyle(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.25)
                                      : Colors.black.withValues(alpha: 0.3),
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w400,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.only(top: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Thin separator ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        height: 0.5,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ─── SECTION 1: Duration ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('DURATION', isDark),
                          const SizedBox(height: 14),
                          _buildDurationToggle(isDark),
                          const SizedBox(height: 10),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _getDurationSubtitle(),
                                key: ValueKey(_selectedDuration),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.3)
                                      : Colors.black.withValues(alpha: 0.35),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ─── SECTION 2: Audience ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('AUDIENCE', isDark),
                          const SizedBox(height: 14),
                          ...PostAudience.values.map(
                            (aud) => _buildAudienceOption(aud, isDark),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── SEND BUTTON (pinned at bottom) ──
            Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
              decoration: BoxDecoration(
                color: scaffoldBg,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    gradient: _isPosting
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFF48CAE4)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                    color: _isPosting
                        ? (isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.1))
                        : null,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isPosting ? null : _postContent,
                      borderRadius: BorderRadius.circular(14),
                      child: Center(
                        child: _isPosting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: KnockpostLoadingIndicator(),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.send_rounded,
                                    size: 17,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Send',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
