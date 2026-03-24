import 'dart:io';

import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white60 : Colors.black54;
    final topPadding = MediaQuery.of(context).padding.top;
    final user = widget.user;
    final coverHeight = 180.0 + topPadding;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: coverHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF222222) : const Color(0xFFE5E5E5),
                image: user.coverImageAsset != null
                    ? DecorationImage(
                        image: user.coverImageAsset!.startsWith('assets/')
                            ? AssetImage(user.coverImageAsset!) as ImageProvider
                            : FileImage(File(user.coverImageAsset!)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: DecoratedBox(
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
              ),
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
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: widget.onBackTap ?? () => Navigator.pop(context),
                    )
                  else
                    const SizedBox(width: 40),
                  if (widget.showSettingsButton)
                    _BlurMenuButton(
                      icon: Icons.more_vert_rounded,
                      onTap: widget.onSettingsTap,
                    )
                  else
                    const SizedBox(width: 40),
                ],
              ),
            ),
            Positioned(
              bottom: -40,
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
              if (user.isOwnProfile)
                Padding(
                  padding: const EdgeInsets.only(right: 110),
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
                )
              else ...[
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
              const SizedBox(height: 10),
              if (user.bio.isNotEmpty)
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.75,
                  child: Padding(
                    padding: EdgeInsets.only(right: user.isOwnProfile ? 0 : 60),
                  child: Text(
                    user.bio,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: textColor.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              if (user.isOwnProfile)
                _buildOwnFriendsRow(textColor, isDark)
              else
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? const Color(0xFF222222) : const Color(0xFFF0F0F0),
                        image: user.avatarAsset != null
                            ? DecorationImage(
                                image: user.avatarAsset!.startsWith('assets/')
                                    ? AssetImage(user.avatarAsset!) as ImageProvider
                                    : FileImage(File(user.avatarAsset!)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: user.avatarAsset == null
                          ? Icon(Icons.person, size: 16, color: subColor)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_formatCount(user.friendsCount)} friends',
                      style: TextStyle(
                        fontSize: 14,
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          user.privacyType == PrivacyType.private
                              ? Icons.lock_outline_rounded
                              : Icons.public_rounded,
                          size: 13,
                          color: subColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          user.privacyType == PrivacyType.private
                              ? 'Private'
                              : 'Open',
                          style: TextStyle(fontSize: 12, color: subColor),
                        ),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 12),
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
                            color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE5E5E5),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.black12,
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
                            color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE5E5E5),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.black12,
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
                      flex: _canMessage ? 5 : 1,
                      child: KnockButton(
                        initialStatus: _knockStatus,
                        privacyType: user.privacyType,
                        isOwnProfile: false,
                        onStatusChanged: (s) {
                          setState(() => _knockStatus = s);
                          widget.onKnockStatusChanged?.call(s);
                        },
                      ),
                    ),
                    if (_canMessage) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 4,
                        child: GestureDetector(
                          onTap: widget.onMessageTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF262626)
                                  : const Color(0xFFF2F2F2),
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.black12,
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Message',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
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
        backgroundColor:
            isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
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

  String _formatCount(int count) {
    if (count >= 1000) {
      final short = (count / 1000).toStringAsFixed(1);
      return short.endsWith('.0') ? '${short.split('.').first}K' : '${short}K';
    }
    return count.toString();
  }
}

class _BlurMenuButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _BlurMenuButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}
