import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/global_knock_state.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../screens/profile/other_profile_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/widgets/creator_rank_badge.dart';
import '../utils/haptic_helper.dart';
import '../services/post_service.dart';
import '../services/connection_service.dart';
import 'knockpost_avatar.dart';
import 'music_pill.dart';
import '../screens/waves/widgets/more_options_sheet.dart';

class PostHeader extends StatefulWidget {
  final UserModel user;
  final String? postId;
  final bool disableProfileNavigation;
  final String? timestamp;
  final String postTypeName;
  final String? musicTitle;
  final String? musicArtist;

  const PostHeader({
    super.key,
    required this.user,
    this.postId,
    this.disableProfileNavigation = false,
    this.timestamp,
    this.postTypeName = "Post",
    this.musicTitle,
    this.musicArtist,
  });

  @override
  State<PostHeader> createState() => _PostHeaderState();
}

class _PostHeaderState extends State<PostHeader> {
  late ValueNotifier<KnockStatus> _globalNotifier;
  late KnockStatus _status;
  bool _showBlackFlash = false;
  bool _isLoading = false;

  /// Music pill alternation state
  static final _random = Random();
  bool _showMusicPill = false;
  Timer? _alternateTimer;

  bool get _hasMusic =>
      widget.musicTitle != null && widget.musicTitle!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _globalNotifier = GlobalKnockState.getNotifier(widget.user.id, widget.user.knockStatus);
    _status = _globalNotifier.value;
    _globalNotifier.addListener(_onGlobalStatusChanged);
    _startAlternation();
  }

  void _onGlobalStatusChanged() {
    if (mounted && _status != _globalNotifier.value) {
      setState(() => _status = _globalNotifier.value);
    }
  }

  @override
  void didUpdateWidget(covariant PostHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      _globalNotifier.removeListener(_onGlobalStatusChanged);
      _globalNotifier = GlobalKnockState.getNotifier(widget.user.id, widget.user.knockStatus);
      _status = _globalNotifier.value;
      _globalNotifier.addListener(_onGlobalStatusChanged);
    }
    // Restart alternation if music state changed
    final oldHasMusic = oldWidget.musicTitle != null && oldWidget.musicTitle!.isNotEmpty;
    final newHasMusic = _hasMusic;
    if (oldHasMusic != newHasMusic) {
      _stopAlternation();
      _showMusicPill = false;
      _startAlternation();
    }
  }

  @override
  void dispose() {
    _stopAlternation();
    _globalNotifier.removeListener(_onGlobalStatusChanged);
    super.dispose();
  }

  void _startAlternation() {
    if (!_hasMusic || widget.timestamp == null) return;
    // Stagger start with a random delay (0–3s) so consecutive posts
    // with music don't animate in perfect sync.
    final initialDelay = Duration(
      milliseconds: _random.nextInt(3000),
    );
    _alternateTimer = Timer(initialDelay, () {
      if (mounted) _scheduleNextToggle();
    });
  }

  void _scheduleNextToggle() {
    if (!mounted || !_hasMusic || widget.timestamp == null) return;
    
    // Timestamp stays for 4s, Music Pill stays for 6s
    final duration = _showMusicPill 
        ? const Duration(seconds: 6) 
        : const Duration(seconds: 4);
        
    _alternateTimer = Timer(duration, () {
      if (mounted) {
        setState(() => _showMusicPill = !_showMusicPill);
        _scheduleNextToggle();
      }
    });
  }

  void _stopAlternation() {
    _alternateTimer?.cancel();
    _alternateTimer = null;
  }

  void _toggleKnock() async {
    if (_isLoading) return;
    KnockHaptics.tap();
    
    final isEffectivelyOpen = widget.user.accountType == AccountType.creator || 
                              widget.user.privacyType == PrivacyType.open;

    setState(() => _isLoading = true);

    try {
      switch (_status) {
        case KnockStatus.none:
        case KnockStatus.theyKnockedYouPending:
          _showBlackFlash = true;
          setState(() {});
          await ConnectionService.instance.sendKnock(
            toUid: widget.user.id,
            isOpenProfile: isEffectivelyOpen,
          );
          break;
        case KnockStatus.theyKnockedYou:
          _showBlackFlash = true;
          setState(() {});
          await ConnectionService.instance.acceptKnock(widget.user.id);
          break;
        case KnockStatus.pending:
        case KnockStatus.knocked:
        case KnockStatus.mutualKnocked:
          await ConnectionService.instance.removeKnock(widget.user.id);
          break;
      }
    } catch (e) {
      debugPrint('PostHeader._toggleKnock error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (_showBlackFlash) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _showBlackFlash = false);
      });
    }
  }

  void _showMoreOptions() {
    KnockHaptics.impact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return MoreOptionsSheet(
          userId: widget.user.id,
          username: widget.user.username,
          user: widget.user,
          postId: widget.postId,
          isReel: false,
          isOwner: widget.user.isOwnProfile,
          postTypeName: widget.postTypeName,
        );
      },
    );
  }

  void _openProfile() {
    if (widget.disableProfileNavigation) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          Widget buildScreen(List<PostModel> currentPosts) {
            if (widget.user.isOwnProfile) {
              return ProfileScreen(
                user: widget.user,
                posts: currentPosts,
              );
            } else {
              return OtherProfileScreen(
                user: widget.user.copyWith(knockStatus: _status),
                posts: currentPosts,
                onKnockStatusChanged: (newStatus) {
                  if (mounted) {
                    setState(() => _status = newStatus);
                  }
                },
              );
            }
          }

          return StreamBuilder<List<PostModel>>(
            stream: PostService.instance.getUserPosts(widget.user.id),
            builder: (context, snapshot) {
              // Show whatever we have so far (or empty list if loading)
              return buildScreen(snapshot.data ?? []);
            },
          );
        },
      ),
    );
  }

  // Whether to show the Knock button.
  // Hide for already-connected states (like Instagram hides "Following" from feed).
  bool get _shouldShowKnockButton {
    if (widget.user.isOwnProfile) return false;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = widget.user;
    final bool isCreator = user.accountType == AccountType.creator;
    final bool showButton = _shouldShowKnockButton;

    // Button styling — only computed when needed
    Color bgColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xfff2f2f2);
    Color textColor = isDark ? Colors.white : Colors.black;
    String label = '';

    if (showButton) {
      switch (_status) {
        case KnockStatus.none:
        case KnockStatus.theyKnockedYouPending:
          label = 'Knock';
          break;
        case KnockStatus.theyKnockedYou:
          label = 'Knock back';
          break;
        default:
          break;
      }

      if (_showBlackFlash) {
        bgColor = isDark ? Colors.white : Colors.black;
        textColor = isDark ? Colors.black : Colors.white;
      }
    }

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _openProfile,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                KnockPostAvatar(
                  url: user.avatarAsset,
                  radius: 18,
                  name: user.displayName,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              user.username,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15.5,
                              ),
                            ),
                          ),
                          if (isCreator) ...[
                            const SizedBox(width: 5),
                            CreatorRankBadge(rank: user.rank, mini: true),
                          ],
                        ],
                      ),
                      if (widget.timestamp != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: RepaintBoundary(
                            child: SizedBox(
                              height: 19, // Fixed height prevents layout jumps
                              child: ClipRect(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 350),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  layoutBuilder: (currentChild, previousChildren) {
                                    return Stack(
                                      alignment: Alignment.centerLeft,
                                      children: <Widget>[
                                        ...previousChildren,
                                        if (currentChild != null) currentChild,
                                      ],
                                    );
                                  },
                                  transitionBuilder: (child, animation) {
                                    final isMusicPill = child.key == const ValueKey('music_pill');
                                    final isEntering = isMusicPill == _showMusicPill;
                                    
                                    // Entering child comes from bottom (1.0), exiting child goes to top (-1.0)
                                    final slideTween = Tween<Offset>(
                                      begin: Offset(0, isEntering ? 1.0 : -1.0),
                                      end: Offset.zero,
                                    );
                                    
                                    return SlideTransition(
                                      position: slideTween.animate(animation),
                                      child: FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: _showMusicPill && _hasMusic
                                      ? MusicPill(
                                          key: const ValueKey('music_pill'),
                                          title: widget.musicTitle!,
                                          artist: widget.musicArtist,
                                        )
                                      : Text(
                                          widget.timestamp!,
                                          key: const ValueKey('timestamp'),
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: isDark ? Colors.white54 : Colors.black54,
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
              ],
            ),
          ),
        ),

        // ── Knock button — only shown for non-connected users ──
        if (showButton) ...[
          GestureDetector(
            onTap: _toggleKnock,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
                child: Text(label),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],

        // ── Three-dot menu ──
        GestureDetector(
          onTap: _showMoreOptions,
          child: const Icon(Icons.more_horiz),
        ),
      ],
    );
  }
}
