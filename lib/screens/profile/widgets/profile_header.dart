import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import 'creator_rank_badge.dart';
import 'knock_button.dart';

/// Substack-style profile header:
/// Cover image at top, avatar overlapping bottom right.
/// Name, Username, Bio, Action buttons on left.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cover Image & Avatar Stack ─────────────────────────────────────
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Cover Image Background
            Container(
              height: 180 + topPadding,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF222222) : const Color(0xFFE5E5E5),
                image: user.coverImageAsset != null
                    ? DecorationImage(
                        image: AssetImage(user.coverImageAsset!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  // Soft bottom haze to blend cover with content.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            bg.withValues(alpha: isDark ? 0.18 : 0.68),
                            bg,
                          ],
                          stops: const [0.45, 0.85, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Top Buttons (Back / Settings)
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
                      icon: Icons.settings_outlined,
                      onTap: widget.onSettingsTap,
                    )
                  else
                    const SizedBox(width: 40),
                ],
              ),
            ),

            // Overlapping Avatar (Bottom Right)
            Positioned(
              bottom: -40,
              right: 16,
              child: Container(
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
                  radius: 46,
                  backgroundColor:
                      isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
                  backgroundImage: user.avatarAsset != null
                      ? AssetImage(user.avatarAsset!)
                      : null,
                  child: user.avatarAsset == null
                      ? Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),

        // ── Info Section (Below Cover) ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          // ensure space for avatar overlapping
          constraints: const BoxConstraints(minHeight: 50),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Display Name
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

              // KnockPost user id
              Text(
                'KnockPost ID • @${user.username}',
                style: TextStyle(
                  fontSize: 13,
                  color: subColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
              if (user.accountType == AccountType.creator) ...[
                const SizedBox(height: 8),
                CreatorRankBadge(rank: user.rank, large: true),
              ],
              const SizedBox(height: 12),

              // Bio
              if (user.bio.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 60), // keep away from avatar
                  child: Text(
                    user.bio,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: textColor.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              // Subscribers/Friends Count + Privacy Badge
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
                              image: AssetImage(user.avatarAsset!),
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
                  if (user.isOwnProfile) ...[
                    const SizedBox(width: 6),
                    Text(
                      '• See Friends',
                      style: TextStyle(
                        fontSize: 13,
                        color: subColor,
                        decoration: TextDecoration.underline,
                        decorationThickness: 0.5,
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Privacy Badge
                  if (!user.isOwnProfile)
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

              const SizedBox(height: 20),

              // ── Buttons ────────────────────────────────────────────────────
              if (user.isOwnProfile)
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {}, // Share action logic
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6116), // KnockPost Orange / Substack Orange
                            borderRadius: BorderRadius.circular(24),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Share',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
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
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF262626) : const Color(0xFFF2F2F2),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Edit',
                            style: TextStyle(
                              fontSize: 14.5,
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
      ],
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
