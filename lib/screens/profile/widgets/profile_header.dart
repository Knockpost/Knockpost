import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/user_model.dart';
import 'creator_rank_badge.dart';
import 'knock_button.dart';

/// Substack-inspired profile header:
/// cover at top, soft fade, strong identity block, and context-aware actions.
class ProfileHeader extends StatefulWidget {
  final UserModel user;
  final VoidCallback? onEditTap;
  final VoidCallback? onMessageTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onBackTap;
  final ValueChanged<KnockStatus>? onKnockStatusChanged;
  final bool showBackButton;
  final bool showSettingsButton;

  const ProfileHeader({
    super.key,
    required this.user,
    this.onEditTap,
    this.onMessageTap,
    this.onSettingsTap,
    this.onBackTap,
    this.onKnockStatusChanged,
    this.showBackButton = false,
    this.showSettingsButton = false,
  });

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  late KnockStatus _knockStatus;

  @override
  void initState() {
    super.initState();
    _knockStatus = widget.user.knockStatus;
  }

  @override
  void didUpdateWidget(covariant ProfileHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.knockStatus != widget.user.knockStatus) {
      _knockStatus = widget.user.knockStatus;
    }
  }

  bool get _canMessage =>
      _knockStatus == KnockStatus.knocked ||
      _knockStatus == KnockStatus.mutualKnocked;

  bool get _showMessageButton =>
      _knockStatus == KnockStatus.pending ||
      _knockStatus == KnockStatus.knocked ||
      _knockStatus == KnockStatus.mutualKnocked;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white60 : Colors.black54;
    final topPadding = MediaQuery.of(context).padding.top;
    final user = widget.user;
    final hasCover =
        user.coverImageAsset != null && user.coverImageAsset!.isNotEmpty;
    // Shrink the cover height to bring the profile info up, leaving a nice gap for the top buttons
    final coverHeight = hasCover ? 180.0 + topPadding : topPadding + 76.0;

    final SystemUiOverlayStyle overlayStyle =
        (hasCover
                ? SystemUiOverlayStyle.light
                : (isDark
                      ? SystemUiOverlayStyle.light
                      : SystemUiOverlayStyle.dark))
            .copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: bg,
              systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: coverHeight,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: hasCover
                          ? (isDark
                                ? const Color(0xFF222222)
                                : const Color(0xFFE5E5E5))
                          : bg,
                      image: hasCover
                          ? DecorationImage(
                              image: user.coverImageAsset!.startsWith('assets/')
                                  ? AssetImage(user.coverImageAsset!)
                                        as ImageProvider
                                  : FileImage(File(user.coverImageAsset!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: hasCover
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  bg.withValues(alpha: isDark ? 0.20 : 0.72),
                                  bg,
                                ],
                                stops: const [0.42, 0.86, 1.0],
                              ),
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    top: topPadding + 8,
                    left: 8,
                    right: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (widget.showBackButton)
                          _BlurMenuButton(
                            icon: Icons.arrow_back_rounded,
                            iconSize: 22,
                            onTap:
                                widget.onBackTap ??
                                () => Navigator.pop(context),
                            hasCover: hasCover,
                            isDark: isDark,
                          )
                        else
                          const SizedBox(width: 40),
                        if (widget.showSettingsButton)
                          _BlurMenuButton(
                            icon: Icons.more_vert_rounded,
                            onTap: widget.onSettingsTap,
                            hasCover: hasCover,
                            isDark: isDark,
                          )
                        else
                          const SizedBox(width: 40),
                      ],
                    ),
                  ),
                ],
              ),
              Transform.translate(
                offset: const Offset(0, -18),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  constraints: const BoxConstraints(minHeight: 50),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 106),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                                letterSpacing: -0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '@${user.username}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: subColor,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (user.accountType ==
                                    AccountType.creator) ...[
                                  const SizedBox(width: 8),
                                  CreatorRankBadge(
                                    rank: user.rank,
                                    large: true,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 11),
                      if (user.bio != null && user.bio!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 106),
                          child: Text(
                            user.bio!,
                            style: TextStyle(
                              fontSize: 14.5,
                              color: textColor.withValues(alpha: 0.9),
                              height: 1.4,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      if (user.isOwnProfile)
                        _buildOwnFriendsRow(textColor, isDark)
                      else if (user.mutualFriendsWhoKnocked.isNotEmpty)
                        _buildFriendsKnockedRow(user, textColor, isDark),
                      if (user.isOwnProfile ||
                          user.mutualFriendsWhoKnocked.isNotEmpty)
                        const SizedBox(height: 13),
                      if (user.isOwnProfile)
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {},
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF2C2C2C)
                                        : const Color(0xFFE5E5E5),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white12
                                          : Colors.black12,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Share',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: widget.onEditTap,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF2C2C2C)
                                        : const Color(0xFFE5E5E5),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white12
                                          : Colors.black12,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Edit',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: KnockButton(
                                userId: user.id,
                                initialStatus: user.knockStatus,
                                privacyType: user.privacyType,
                                accountType: user.accountType,
                                isOwnProfile: false,
                                onStatusChanged: (s) {
                                  setState(() => _knockStatus = s);
                                  widget.onKnockStatusChanged?.call(s);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _showMessageButton
                                  ? GestureDetector(
                                      onTap: _canMessage
                                          ? widget.onMessageTap
                                          : null,
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF2C2C2C)
                                              : const Color(0xFFE5E5E5),
                                          border: Border.all(
                                            color: isDark
                                                ? Colors.white12
                                                : Colors.black12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          'Message',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: _canMessage
                                                ? textColor
                                                : textColor.withValues(alpha: 0.45),
                                          ),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Avatar on TOP of everything — last child = highest z-order for hit testing
          Positioned(
            top: hasCover ? coverHeight - 58 : coverHeight - 24,
            right: 16,
            child: _ZoomableAvatar(
              user: user,
              isDark: isDark,
              bg: bg,
              radius: 46,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsKnockedRow(UserModel user, Color textColor, bool isDark) {
    final avatars = user.mutualFriendsWhoKnocked;
    // Show up to 3 stacked avatars
    final shown = avatars.length > 3 ? avatars.sublist(0, 3) : avatars;
    final stackWidth = 16.0 * (shown.length - 1) + 26;

    return Row(
      children: [
        SizedBox(
          width: stackWidth,
          height: 26,
          child: Stack(
            children: [
              for (int i = 0; i < shown.length; i++)
                _friendPreviewAvatar(shown[i], i * 16.0, isDark),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Some friends knocked',
          style: TextStyle(
            fontSize: 14.5,
            color: textColor,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }

  Widget _buildOwnFriendsRow(Color textColor, bool isDark) {
    return Row(
      children: [
        SizedBox(
          width: 58,
          height: 26,
          child: Stack(
            children: [
              _friendPreviewAvatar('assets/test2.jpg', 0, isDark),
              _friendPreviewAvatar('assets/test3.jpg', 16, isDark),
              _friendPreviewAvatar('assets/test4.jpg', 32, isDark),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'See Friends',
          style: TextStyle(
            fontSize: 14.5,
            color: textColor,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }

  Widget _friendPreviewAvatar(String asset, double left, bool isDark) {
    return Positioned(
      left: left,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? const Color(0xFF111111) : Colors.white,
            width: 1.6,
          ),
          image: DecorationImage(
            image: asset.startsWith('assets/')
                ? AssetImage(asset) as ImageProvider
                : FileImage(File(asset)),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class _ZoomableAvatar extends StatefulWidget {
  final UserModel user;
  final bool isDark;
  final Color bg;
  final double radius;

  const _ZoomableAvatar({
    required this.user,
    required this.isDark,
    required this.bg,
    required this.radius,
  });

  @override
  State<_ZoomableAvatar> createState() => _ZoomableAvatarState();
}

class _ZoomableAvatarState extends State<_ZoomableAvatar>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlayEntry;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  final GlobalKey _avatarKey = GlobalKey();
  Offset? _avatarCenter;
  Size? _avatarSize;
  bool _isClosing = false;
  Timer? _pressTimer;
  double _userScale = 1.0;
  Offset _userOffset = Offset.zero;
  double _baseScale = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 2.72).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );
    _controller.addListener(() {
      _overlayEntry?.markNeedsBuild();
    });
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    _removeOverlayImmediate();
    _controller.dispose();
    super.dispose();
  }

  /// Called on long press — opens the popup and it STAYS open.
  void _showZoom() {
    if (_overlayEntry != null) return;

    final renderBox =
        _avatarKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    HapticFeedback.mediumImpact();

    _avatarSize = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    _avatarCenter = Offset(
      offset.dx + _avatarSize!.width / 2,
      offset.dy + _avatarSize!.height / 2,
    );

    _isClosing = false;
    _userScale = 1.0;
    _userOffset = Offset.zero;
    _baseScale = 1.0;
    _overlayEntry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_overlayEntry!);
    _controller.forward(from: 0.0);
    setState(() {});
  }

  /// Tap anywhere on the overlay to dismiss.
  void _dismissZoom() {
    if (_overlayEntry == null || _isClosing) return;
    _isClosing = true;
    HapticFeedback.lightImpact();
    _controller.reverse().then((_) {
      _removeOverlayImmediate();
    });
  }

  void _removeOverlayImmediate() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isClosing = false;
    if (mounted) setState(() {});
  }

  Widget _buildOverlay(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenCenter = screenSize.center(Offset.zero);
    final scale = _scaleAnimation.value;
    final fade = _fadeAnimation.value;
    // Use correct divisor so progress reaches 1.0 at max animation scale
    final progress = ((scale - 1.0) / 1.72).clamp(0.0, 1.0);

    final dx =
        _avatarCenter!.dx + (screenCenter.dx - _avatarCenter!.dx) * progress;
    final dy =
        _avatarCenter!.dy + (screenCenter.dy - _avatarCenter!.dy) * progress;

    final totalScale = scale * _userScale;

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: _dismissZoom,
        onScaleStart: (details) {
          _baseScale = _userScale;
        },
        onScaleUpdate: (details) {
          _userScale = (_baseScale * details.scale).clamp(0.8, 2.0);
          if (details.pointerCount >= 2) {
            _userOffset += details.focalPointDelta;
          }
          _overlayEntry?.markNeedsBuild();
        },
        onScaleEnd: (_) {
          // Always snap back to original size/position on release
          _userScale = 1.0;
          _userOffset = Offset.zero;
          _overlayEntry?.markNeedsBuild();
        },
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // Frosted glass blur background
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: fade * 8.0,
                  sigmaY: fade * 8.0,
                ),
                child: Container(
                  color: (widget.isDark ? Colors.black : Colors.white)
                      .withValues(alpha: fade * 0.05),
                ),
              ),
            ),
            // Zoomed avatar centered on screen
            Positioned(
              left: dx - _avatarSize!.width / 2 + _userOffset.dx,
              top: dy - _avatarSize!.height / 2 + _userOffset.dy,
              width: _avatarSize!.width,
              height: _avatarSize!.height,
              child: Transform.scale(
                scale: totalScale,
                child: _buildAvatarContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarContent() {
    final user = widget.user;
    final isCreator = user.accountType == AccountType.creator;
    final borderWidth = isCreator ? 3.0 : 4.0;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.bg,
        border: Border.all(
          color: widget.bg,
          width: borderWidth,
        ),
      ),
      child: CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.isDark
            ? const Color(0xFF2A2A2A)
            : const Color(0xFFEEEEEE),
        backgroundImage: user.avatarAsset != null
            ? (user.avatarAsset!.startsWith('assets/')
                  ? AssetImage(user.avatarAsset!) as ImageProvider
                  : FileImage(File(user.avatarAsset!)))
            : null,
        child: user.avatarAsset == null
            ? Text(
                user.displayName.isNotEmpty
                    ? user.displayName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: widget.radius * 0.74,
                  fontWeight: FontWeight.w700,
                  color: widget.isDark ? Colors.white70 : Colors.black54,
                ),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      key: _avatarKey,
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        _pressTimer?.cancel();
        _pressTimer = Timer(const Duration(milliseconds: 250), () {
          _showZoom();
        });
      },
      onPointerUp: (_) {
        _pressTimer?.cancel();
      },
      onPointerCancel: (_) {
        _pressTimer?.cancel();
      },
      child: Opacity(
        opacity: _overlayEntry != null ? 0.0 : 1.0,
        child: _buildAvatarContent(),
      ),
    );
  }
}

class _BlurMenuButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool hasCover;
  final bool isDark;
  final double iconSize;

  const _BlurMenuButton({
    required this.icon,
    this.onTap,
    this.hasCover = true,
    this.isDark = true,
    this.iconSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: iconSize,
          color: hasCover
              ? Colors.white
              : (isDark ? Colors.white : Colors.black87),
          shadows: hasCover
              ? [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}
