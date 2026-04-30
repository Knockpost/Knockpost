import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/global_knock_state.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../screens/profile/other_profile_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/widgets/creator_rank_badge.dart';
import '../utils/haptic_helper.dart';
import '../utils/image_helper.dart';
import '../services/post_service.dart';
import '../screens/waves/widgets/more_options_sheet.dart';

class PostHeader extends StatefulWidget {
  final UserModel user;
  final String? postId;
  final bool disableProfileNavigation;
  final String? timestamp;
  final String postTypeName;

  const PostHeader({
    super.key,
    required this.user,
    this.postId,
    this.disableProfileNavigation = false,
    this.timestamp,
    this.postTypeName = "Post",
  });

  @override
  State<PostHeader> createState() => _PostHeaderState();
}

class _PostHeaderState extends State<PostHeader> {
  late ValueNotifier<KnockStatus> _globalNotifier;
  late KnockStatus _status;
  bool _showBlackFlash = false;

  @override
  void initState() {
    super.initState();
    _globalNotifier = GlobalKnockState.getNotifier(widget.user.id, widget.user.knockStatus);
    _status = _globalNotifier.value;
    _globalNotifier.addListener(_onGlobalStatusChanged);
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
  }

  @override
  void dispose() {
    _globalNotifier.removeListener(_onGlobalStatusChanged);
    super.dispose();
  }

  void _toggleKnock() {
    KnockHaptics.tap();
    
    final isEffectivelyOpen = widget.user.accountType == AccountType.creator || 
                              widget.user.privacyType == PrivacyType.open;

    KnockStatus nextStatus = _status;
    
    switch (_status) {
      case KnockStatus.none:
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
    
    // Broadcast status globally
    _globalNotifier.value = nextStatus;

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Determine button colors
    Color bgColor;
    Color textColor;
    String label;

    switch (_status) {
      case KnockStatus.none:
        label = "Knock";
        break;
      case KnockStatus.theyKnockedYou:
        label = "Knock back";
        break;
      case KnockStatus.pending:
        label = "Pending";
        break;
      case KnockStatus.knocked:
      case KnockStatus.mutualKnocked:
        label = "Knocked";
        break;
    }

    if (_showBlackFlash) {
      bgColor = isDark ? Colors.white : Colors.black;
      textColor = isDark ? Colors.black : Colors.white;
    } else {
      bgColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xfff2f2f2);
      textColor = isDark ? Colors.white : Colors.black;
    }

    final user = widget.user;
    final bool isCreator = user.accountType == AccountType.creator;

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _openProfile,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: ImageHelper.resolveAvatar(user.avatarAsset),
                  child: user.avatarAsset == null
                      ? Icon(Icons.person, size: 18, color: Colors.grey.shade600)
                      : null,
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
                                fontWeight: FontWeight.w600,
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
                      if (widget.timestamp != null && user.isOwnProfile)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            widget.timestamp!,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? Colors.white54 : Colors.black54,
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

        // ── Knock / Knocked button ──
        if (!user.isOwnProfile) ...[
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
                  fontWeight: FontWeight.w600,
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
