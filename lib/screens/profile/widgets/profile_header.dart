import 'dart:io';

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
            .copyWith(statusBarColor: Colors.transparent);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Column(
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
                        onTap: widget.onBackTap ?? () => Navigator.pop(context),
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
              Positioned(
                bottom: hasCover ? -42 : -76,
                right: 16,
                child: _buildAvatar(
                  user: user,
                  isDark: isDark,
                  bg: bg,
                  radius: 46,
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
                            if (user.accountType == AccountType.creator) ...[
                              const SizedBox(width: 8),
                              CreatorRankBadge(rank: user.rank, large: true),
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
                  const SizedBox(height: 9),
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
                              padding: const EdgeInsets.symmetric(vertical: 8),
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
                              padding: const EdgeInsets.symmetric(vertical: 8),
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
                            initialStatus: _knockStatus,
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

  Widget _buildAvatar({
    required UserModel user,
    required bool isDark,
    required Color bg,
    required double radius,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(
          color: user.accountType == AccountType.creator
              ? CreatorRankBadge.rankColor(user.rank).withValues(alpha: 0.6)
              : bg,
          width: user.accountType == AccountType.creator ? 3.0 : 4.0,
        ),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: isDark
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
                  fontSize: radius * 0.74,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              )
            : null,
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
