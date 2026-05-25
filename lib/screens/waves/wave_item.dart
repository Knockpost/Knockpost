import 'package:flutter/material.dart';
import 'package:knockpost/widgets/knockpost_refresh.dart';
import 'package:video_player/video_player.dart';
import '../../widgets/comment_sheet.dart';
import 'widgets/share_sheet.dart';
import 'widgets/more_options_sheet.dart';
import '../profile/other_profile_screen.dart';
import '../profile/profile_screen.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../utils/haptic_helper.dart';
import '../../utils/image_helper.dart';
import '../../services/current_user_service.dart';
import '../../services/like_service.dart';
import '../../services/post_service.dart';
import '../../services/waves_controller_manager.dart';
import '../../utils/global_knock_state.dart';
import '../../widgets/knockpost_avatar.dart';
import 'package:extended_image/extended_image.dart';
import 'dart:async';

class WaveItem extends StatefulWidget {
  final String videoUrl;
  final String username;
  final String caption;
  final bool isActive;
  final double bottomPadding;
  // Real data (optional — falls back to string-only mode if null)
  final PostModel? post;
  final UserModel? author;

  const WaveItem({
    super.key,
    required this.videoUrl,
    required this.username,
    required this.caption,
    required this.isActive,
    this.bottomPadding = 0,
    this.post,
    this.author,
  });

  @override
  State<WaveItem> createState() => _WaveItemState();
}

class _WaveItemState extends State<WaveItem> with TickerProviderStateMixin {
  static final Set<String> _viewedWaves = {};
  VideoPlayerController? _controller;
  bool _isControllerInitialized = false;

  bool isPlaying = true;
  bool showHeart = false;
  bool _doubleTapped = false;
  bool _showBlackFlash = false;
  
  late ValueNotifier<KnockStatus>? _globalNotifier;
  KnockStatus _status = KnockStatus.none;

  /// Like animation
  late AnimationController _heartAnimController;
  late Animation<double> _heartScaleAnim;
  late Animation<double> _heartOpacityAnim;

  /// Play/pause icon animation
  late AnimationController _playPauseAnimController;
  late Animation<double> _playPauseOpacity;
  
  Timer? _viewTimer;

  @override
  void initState() {
    super.initState();

    if (widget.author != null) {
      _globalNotifier = GlobalKnockState.getNotifier(widget.author!.id, widget.author!.knockStatus);
      _status = _globalNotifier!.value;
      _globalNotifier!.addListener(_onGlobalStatusChanged);
    } else {
      _globalNotifier = null;
    }

    /// Heart animation setup
    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _heartScaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _heartAnimController,
      curve: Curves.easeOut,
    ));

    _heartOpacityAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(CurvedAnimation(
      parent: _heartAnimController,
      curve: Curves.easeOut,
    ));

    /// Play/pause fade
    _playPauseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _playPauseOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _playPauseAnimController,
        curve: Curves.easeInOut,
      ),
    );

    /// Video
    _initVideoController();
  }

  void _onGlobalStatusChanged() {
    if (mounted && _globalNotifier != null && _status != _globalNotifier!.value) {
      setState(() => _status = _globalNotifier!.value);
    }
  }

  Future<void> _initVideoController() async {
    try {
      final controller = await WavesControllerManager.instance.getController(widget.videoUrl);
      if (!mounted) return;
      
      setState(() {
        _controller = controller;
        _isControllerInitialized = controller.value.isInitialized;
      });

      // Listen for initialization changes (in case it wasn't ready)
      if (!_isControllerInitialized) {
        controller.addListener(_controllerListener);
      }

      if (widget.isActive) {
        controller.play();
        _trackView();
      } else {
        controller.pause();
      }
    } catch (e) {
      debugPrint("Video initialization error: $e");
    }
  }

  void _controllerListener() {
    if (_controller?.value.isInitialized == true && mounted && !_isControllerInitialized) {
      setState(() {
        _isControllerInitialized = true;
      });
      _controller?.removeListener(_controllerListener);
    }
  }

  void _trackView() {
    if (widget.post != null && widget.author != null && !widget.post!.id.startsWith('demo_')) {
      if (!_viewedWaves.contains(widget.post!.id)) {
        _viewTimer ??= Timer(const Duration(seconds: 2), () {
          if (mounted && widget.isActive) {
            _viewedWaves.add(widget.post!.id);
            PostService.instance.incrementViewCount(widget.post!.id, widget.author!.id);
          }
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant WaveItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.author?.id != oldWidget.author?.id) {
      if (oldWidget.author != null && _globalNotifier != null) {
        _globalNotifier!.removeListener(_onGlobalStatusChanged);
      }
      if (widget.author != null) {
        _globalNotifier = GlobalKnockState.getNotifier(widget.author!.id, widget.author!.knockStatus);
        _status = _globalNotifier!.value;
        _globalNotifier!.addListener(_onGlobalStatusChanged);
      } else {
        _globalNotifier = null;
        _status = KnockStatus.none;
      }
    }

    if (_controller == null || !_isControllerInitialized) return;

    if (widget.isActive) {
      _controller!.play();
      isPlaying = true;
      _playPauseAnimController.reverse();
      _trackView();
    } else {
      _viewTimer?.cancel();
      _viewTimer = null;
      _controller!.pause();
      isPlaying = false;
    }
  }

  void _openAuthorProfile() {
    KnockHaptics.tap();
    final author = widget.author;
    if (author == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          if (author.isOwnProfile) {
            return StreamBuilder<List<PostModel>>(
              stream: PostService.instance.getUserPosts(author.id),
              builder: (context, snap) =>
                  ProfileScreen(user: author, posts: snap.data ?? []),
            );
          } else {
            return StreamBuilder<List<PostModel>>(
              stream: PostService.instance.getUserPosts(author.id),
              builder: (context, snap) =>
                  OtherProfileScreen(user: author, posts: snap.data ?? []),
            );
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    if (_globalNotifier != null) {
      _globalNotifier!.removeListener(_onGlobalStatusChanged);
    }
    _viewTimer?.cancel();
    _controller?.removeListener(_controllerListener);
    // DO NOT dispose _controller here because WavesControllerManager owns it.
    _heartAnimController.dispose();
    _playPauseAnimController.dispose();
    super.dispose();
  }

  void togglePlay() {
    if (_controller == null || !_isControllerInitialized) return;

    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        isPlaying = false;
        _playPauseAnimController.forward();
      } else {
        _controller!.play();
        isPlaying = true;
        _playPauseAnimController.reverse();
      }
    });
  }

  void _toggleKnock() {
    if (widget.author == null) return;
    KnockHaptics.tap();

    final isEffectivelyOpen = widget.author!.accountType == AccountType.creator || 
                              widget.author!.privacyType == PrivacyType.open;

    KnockStatus nextStatus = _status;
    
    switch (_status) {
      case KnockStatus.none:
      case KnockStatus.theyKnockedYouPending:
        nextStatus = isEffectivelyOpen ? KnockStatus.knocked : KnockStatus.pending;
        _showBlackFlash = true;
        break;
      case KnockStatus.theyKnockedYou:
        nextStatus = KnockStatus.mutualKnocked;
        _showBlackFlash = true;
        break;
      case KnockStatus.pending:
      case KnockStatus.knocked:
      case KnockStatus.mutualKnocked:
        nextStatus = KnockStatus.none;
        break;
    }

    setState(() {
      _status = nextStatus;
    });
    
    if (_globalNotifier != null) {
      _globalNotifier!.value = nextStatus;
    }

    if (_showBlackFlash) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _showBlackFlash = false);
      });
    }
  }

  bool get _shouldShowKnockButton {
    if (widget.author == null || widget.author!.isOwnProfile) return false;
    if (_showBlackFlash) return true; // Keep visible while flashing
    switch (_status) {
      case KnockStatus.knocked:
      case KnockStatus.mutualKnocked:
      case KnockStatus.pending:
        return false;
      case KnockStatus.none:
      case KnockStatus.theyKnockedYou:
      case KnockStatus.theyKnockedYouPending:
        return true;
    }
  }

  void handleDoubleTap() {
    KnockHaptics.impact();
    setState(() {
      _doubleTapped = true;
      showHeart = true;
    });

    _heartAnimController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() => showHeart = false);
      }
    });
  }

  void _onDoubleTapHandled() {
    setState(() => _doubleTapped = false);
  }

  @override
  Widget build(BuildContext context) {
    Color knockBgColor;
    Color knockTextColor;

    if (_showBlackFlash) {
      knockBgColor = Colors.black;
      knockTextColor = Colors.white;
    } else {
      knockBgColor = const Color(0xfff2f2f2);
      knockTextColor = Colors.black;
    }

    String knockLabel = 'Knock';
    if (_showBlackFlash) {
      knockLabel = _status == KnockStatus.pending ? 'Pending' : 'Knocked';
    } else if (_status == KnockStatus.theyKnockedYou) {
      knockLabel = 'Knock back';
    }

    return GestureDetector(
      onTap: togglePlay,
      onDoubleTap: handleDoubleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          /// 🎥 VIDEO
          _isControllerInitialized && _controller != null
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                )
              : Container(
                  color: Colors.black,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (widget.post?.coverImagePath != null)
                        ExtendedImage.network(
                          widget.post!.coverImagePath!,
                          fit: BoxFit.cover,
                          loadStateChanged: (state) {
                            if (state.extendedImageLoadState == LoadState.failed) {
                              return const SizedBox.shrink();
                            }
                            return null;
                          },
                        ),
                      Container(
                        color: Colors.black.withValues(alpha: 0.3),
                        child: const Center(
                          child: KnockpostLoadingIndicator(),
                        ),
                      ),
                    ],
                  ),
                ),

          /// 🌑 GRADIENT OVERLAY (multi-stop for premium feel)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.6),
                  Colors.black.withValues(alpha: 0.85),
                ],
                stops: const [0.0, 0.15, 0.5, 0.85, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          /// ❤️ DOUBLE TAP HEART (pro animation)
          if (showHeart)
            Center(
              child: AnimatedBuilder(
                animation: _heartAnimController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _heartOpacityAnim.value,
                    child: Transform.scale(
                      scale: _heartScaleAnim.value,
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: 110,
                      ),
                    ),
                  );
                },
              ),
            ),

          /// ❤️ RIGHT ACTIONS
          Positioned(
            right: 12,
            bottom: 12 + widget.bottomPadding,
            child: Column(
              children: [
                /// ❤️ EMOJI REACTION (Replaces simple Like)
                WaveReactionButton(
                  doubleTapped: _doubleTapped,
                  onDoubleTapHandled: _onDoubleTapHandled,
                  postId: widget.post?.id,
                  postAuthorId: widget.author?.id,
                ),

                const SizedBox(height: 20),

                /// 💬 COMMENT (Private Reply exactly like Post)
                _AnimatedActionButton(
                  onTap: () {
                    if (widget.post == null || widget.author == null) return;
                    CommentSheet.show(
                      context,
                      postId: widget.post!.id,
                      postAuthor: widget.author!,
                      isPostOwner: widget.author!.isOwnProfile,
                    );
                  },
                  customIconWidget: const CustomPaint(
                    size: Size(26, 26),
                    painter: _ReplyIconPainter(color: Colors.white),
                  ),
                  label: null,
                ),

                const SizedBox(height: 20),

                /// 📤 SHARE (Exactly like Post)
                _AnimatedActionButton(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => ShareSheet(
                        url: 'https://knockpost.app/post/${widget.post?.id ?? 'demo'}',
                        username: widget.username,
                        caption: widget.caption,
                        contentType: 'post',
                      ),
                    );
                  },
                  icon: Icons.share_outlined,
                  color: Colors.white,
                  label: null, // Removed label to match Post UI
                ),

                const SizedBox(height: 20),

                /// ⋮ MORE OPTIONS
                _AnimatedActionButton(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => MoreOptionsSheet(
                        userId: widget.author?.id ?? widget.username,
                        username: widget.author?.username ?? widget.username,
                        user: widget.author,
                        postId: widget.post?.id,
                        isOwner: widget.author?.isOwnProfile ?? false,
                        isReel: true,
                        postTypeName: "Wave",
                      ),
                    );
                  },
                  icon: Icons.more_horiz_rounded,
                  label: null,
                  color: Colors.white,
                ),
              ],
            ),
          ),

          /// 👤 BOTTOM INFO
          Positioned(
            left: 14,
            bottom: 12 + widget.bottomPadding,
            right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Username Row
                GestureDetector(
                  onTap: _openAuthorProfile,
                  onDoubleTap: () {}, // Prevent 300ms delay
                  child: Row(
                    children: [
                      /// Avatar with gradient ring
                      Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.white70,
                              Colors.white38,
                            ],
                          ),
                        ),
                        child: KnockpostAvatar(
                          url: widget.author?.avatarAsset,
                          radius: 16,
                          name: widget.author?.displayName,
                        ),
                      ),

                      const SizedBox(width: 10),

                      /// Username
                      Text(
                        "@${widget.author?.username ?? widget.username}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 0.2,
                        ),
                      ),

                      const SizedBox(width: 8),

                      /// Knock Button (only for other users)
                      if (_shouldShowKnockButton)
                      GestureDetector(
                        onTap: _toggleKnock,
                        onDoubleTap: () {}, // Prevent 300ms delay
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: knockBgColor,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: knockTextColor,
                            ),
                            child: Text(knockLabel),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                /// Caption
                Text(
                  widget.caption,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 10),

                /// 🎵 Music bar
                Row(
                  children: [
                    const Icon(
                      Icons.music_note_rounded,
                      color: Colors.white70,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.post?.musicTitle != null
                            ? '${widget.post!.musicTitle}${widget.post!.musicArtist != null ? " • ${widget.post!.musicArtist}" : ""}'
                            : "Original Audio — @${widget.author?.username ?? widget.username}",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),



          /// ⏸ PLAY ICON (animated fade in/out)
          FadeTransition(
            opacity: _playPauseOpacity,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),
          ),

          /// 📏 VIDEO PROGRESS BAR
          if (_isControllerInitialized && _controller != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                height: 4, // Make progress bar clearly visible
                child: VideoProgressIndicator(
                  _controller!,
                  allowScrubbing: true,
                  padding: EdgeInsets.zero,
                  colors: VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white.withValues(alpha: 0.3),
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Animated Action Button with bounce effect
class _AnimatedActionButton extends StatefulWidget {
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? customIconWidget;
  final String? label;
  final Color? color;

  const _AnimatedActionButton({
    required this.onTap,
    this.icon,
    this.customIconWidget,
    this.label,
    this.color,
  });

  @override
  State<_AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<_AnimatedActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.75), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.75, end: 1.15), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _bounceController.reset();
        _bounceController.forward();
        widget.onTap();
      },
      onDoubleTap: () {}, // Prevent 300ms delay
      child: AnimatedBuilder(
        animation: _bounceAnim,
        builder: (context, child) {
          return Column(
            mainAxisSize: MainAxisSize.min, // Ensures tight vertical fit
            children: [
              Transform.scale(
                scale: _bounceAnim.value,
                child: widget.customIconWidget ??
                    Icon(
                      widget.icon,
                      color: widget.color,
                      size: 30,
                    ),
              ),
              if (widget.label != null) ...[
                const SizedBox(height: 6),
                Text(
                  widget.label!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}



class WaveReactionButton extends StatefulWidget {
  final bool doubleTapped;
  final VoidCallback? onDoubleTapHandled;
  final String? postId;
  final String? postAuthorId;

  const WaveReactionButton({
    super.key,
    this.doubleTapped = false,
    this.onDoubleTapHandled,
    this.postId,
    this.postAuthorId,
  });

  @override
  State<WaveReactionButton> createState() => _WaveReactionButtonState();
}

class _WaveReactionButtonState extends State<WaveReactionButton>
    with TickerProviderStateMixin {
  String? _selectedEmoji;
  StreamSubscription<String?>? _likeSub;

  // ── Popup state ──
  bool _showPopup = false;
  int _hoveredIndex = -1;
  final List<String> _reactions = ['👍', '❤', '🥰', '😂', '😮', '😢', '🔥'];
  final List<GlobalKey> _emojiKeys =
      List.generate(7, (_) => GlobalKey());

  // ── Animations ──
  late AnimationController _popupController;
  late Animation<double> _popupScale;

  late AnimationController _heartController;
  late Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();

    _popupController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _popupScale = CurvedAnimation(
      parent: _popupController,
      curve: Curves.elasticOut,
    );

    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.6), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.6, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(
      parent: _heartController,
      curve: Curves.easeInOut,
    ));

    // Sync existing reaction from Firestore
    final currentUser = CurrentUserService.instance.currentUser;
    if (currentUser != null && widget.postId != null) {
      _likeSub = LikeService.instance
          .userReaction(widget.postId!, currentUser.id)
          .listen((reaction) {
        if (mounted) setState(() => _selectedEmoji = reaction);
      });
    }
  }

  @override
  void didUpdateWidget(covariant WaveReactionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.doubleTapped && !oldWidget.doubleTapped) {
      if (_selectedEmoji == null) {
        _selectWithAnimation('❤');
        _saveReaction(isLiking: true, emoji: '❤');
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onDoubleTapHandled?.call();
      });
    }
  }

  @override
  void dispose() {
    _likeSub?.cancel();
    _popupController.dispose();
    _heartController.dispose();
    super.dispose();
  }

  void _onTapReaction() {
    KnockHaptics.tap();
    final isLiking = _selectedEmoji == null;
    if (isLiking) {
      _selectWithAnimation('❤');
    } else {
      setState(() => _selectedEmoji = null);
    }
    _saveReaction(isLiking: isLiking, emoji: isLiking ? '❤' : null);
  }

  void _selectWithAnimation(String emoji) {
    KnockHaptics.impact();
    setState(() => _selectedEmoji = emoji);
    _heartController.forward(from: 0);
  }

  void _saveReaction({required bool isLiking, String? emoji}) {
    final currentUser = CurrentUserService.instance.currentUser;
    if (currentUser == null || widget.postId == null) return;
    LikeService.instance.toggleLike(
      postId: widget.postId!,
      userId: currentUser.id,
      postAuthorId: widget.postAuthorId ?? '',
      isLiking: isLiking,
      reactionType: emoji ?? '❤',
    );
  }

  Widget _buildEmojiWidget(int index, double size) {
    final emoji = _reactions[index];
    if (emoji == '❤') {
      return Icon(Icons.favorite, color: const Color(0xFFED4956), size: size + 4);
    }
    return Text(emoji, style: TextStyle(fontSize: size));
  }

  Widget _buildSelectedWidget(String emoji, double size) {
    if (emoji == '❤') {
      return Icon(Icons.favorite, color: const Color(0xFFED4956), size: size + 4);
    }
    return Text(emoji, style: TextStyle(fontSize: size));
  }

  void _onLongPressStart(LongPressStartDetails details) {
    KnockHaptics.vibrate();
    setState(() {
      _showPopup = true;
      _hoveredIndex = -1;
    });
    _popupController.forward(from: 0);
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    for (int i = 0; i < _reactions.length; i++) {
      final key = _emojiKeys[i];
      final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) continue;
      final pos = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      final fingerPos = details.globalPosition;

      if (fingerPos.dx >= pos.dx &&
          fingerPos.dx <= pos.dx + size.width &&
          fingerPos.dy >= pos.dy - 40 &&
          fingerPos.dy <= pos.dy + size.height + 40) {
        if (_hoveredIndex != i) {
          KnockHaptics.vibrate();
          setState(() => _hoveredIndex = i);
        }
        return;
      }
    }
    if (_hoveredIndex != -1) {
      setState(() => _hoveredIndex = -1);
    }
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (_hoveredIndex >= 0 && _hoveredIndex < _reactions.length) {
      final emoji = _reactions[_hoveredIndex];
      _selectWithAnimation(emoji);
      _saveReaction(isLiking: true, emoji: emoji);
    }
    setState(() {
      _showPopup = false;
      _hoveredIndex = -1;
    });
    _popupController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onTap: _onTapReaction,
          onDoubleTap: _onTapReaction, // Prevent 300ms delay & trigger reaction directly
          onLongPressStart: _onLongPressStart,
          onLongPressMoveUpdate: _onLongPressMoveUpdate,
          onLongPressEnd: _onLongPressEnd,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 38,
                child: Center(
                  child: _selectedEmoji != null
                      ? ScaleTransition(
                          scale: _heartScale,
                          child: _buildSelectedWidget(_selectedEmoji!, 30),
                        )
                      : const Icon(
                          Icons.favorite_border,
                          color: Colors.white,
                          size: 32,
                        ),
                ),
              ),
              const SizedBox(height: 2),
            ],
          ),
        ),

        if (_showPopup)
          Positioned(
            right: 50,
            bottom: 0,
            child: ScaleTransition(
              scale: _popupScale,
              alignment: Alignment.bottomRight,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_reactions.length, (_) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 5),
                          child: SizedBox(width: 30, height: 30),
                        );
                      }),
                    ),
                  ),

                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_reactions.length, (index) {
                          final isHovered = _hoveredIndex == index;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: SizedBox(
                              width: 30,
                              height: 30,
                              child: OverflowBox(
                                key: _emojiKeys[index],
                                maxWidth: 56,
                                maxHeight: 76,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOut,
                                  transform: isHovered
                                      ? (Matrix4.identity()
                                        ..setTranslationRaw(0.0, -18.0, 0.0))
                                      : Matrix4.identity(),
                                  transformAlignment: Alignment.center,
                                  child: AnimatedScale(
                                    scale: isHovered ? 1.6 : 1.0,
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                    child: _buildEmojiWidget(index, 28),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modern curved reply arrow icon — premium minimal design
// EXACT geometrical implementation based on specified constraints.
// ─────────────────────────────────────────────────────────────────────────────
class _ReplyIconPainter extends CustomPainter {
  final Color color;

  const _ReplyIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 // Slightly thicker for waves video overlay
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    final path = Path();

    // 1. ARROWHEAD (45° chevron)
    // Tip at x=15%, y=25%
    final tipX = w * 0.15;
    final tipY = h * 0.25;
    final chevronDx = w * 0.11;
    final chevronDy = h * 0.11;

    path.moveTo(tipX + chevronDx, tipY - chevronDy);
    path.lineTo(tipX, tipY);
    path.lineTo(tipX + chevronDx, tipY + chevronDy);

    // 2. TOP HORIZONTAL LINE
    path.moveTo(tipX, tipY);
    
    // 3. RIGHT ARC (perfect semicircle)
    final arcCenterX = w * 0.65;
    final arcCenterY = h * 0.545;
    final arcRadius = h * 0.295;

    path.lineTo(arcCenterX, tipY); // tipY is exactly arcCenterY - arcRadius

    path.arcToPoint(
      Offset(arcCenterX, arcCenterY + arcRadius), // Ends at exact bottom of the circle
      radius: Radius.circular(arcRadius),
      clockwise: true,
    );

    // 4. BOTTOM TAIL
    // Very short, perfectly horizontal. Ends at x=37%
    final tailEndX = w * 0.37;
    path.lineTo(tailEndX, arcCenterY + arcRadius);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ReplyIconPainter oldDelegate) =>
      color != oldDelegate.color;
}


