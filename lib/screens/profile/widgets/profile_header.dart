import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import 'creator_rank_badge.dart';
import 'knock_button.dart';

/// Substack-style profile header:
/// Left: Name + Username + Bio + Knock button
/// Right: Profile photo (CircleAvatar)
class ProfileHeader extends StatefulWidget {
  final UserModel user;
  final VoidCallback? onEditTap;
  final VoidCallback? onMessageTap;

  const ProfileHeader({
    super.key,
    required this.user,
    this.onEditTap,
    this.onMessageTap,
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

  bool get _canMessage =>
      _knockStatus == KnockStatus.knocked ||
      _knockStatus == KnockStatus.mutualKnocked;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white60 : Colors.black54;
    final user = widget.user;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── LEFT: Text info ───────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + rank badge (if creator)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        user.displayName,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          letterSpacing: -0.5,
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

                const SizedBox(height: 3),

                // Username
                Text(
                  '@${user.username}',
                  style: TextStyle(
                    fontSize: 13,
                    color: subColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const SizedBox(height: 10),

                // Bio
                if (user.bio.isNotEmpty)
                  Text(
                    user.bio,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: textColor.withValues(alpha: 0.85),
                      height: 1.45,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),

                const SizedBox(height: 14),

                // ── Buttons row ──────────────────────────────────────────────
                if (user.isOwnProfile)
                  // Edit Profile button for own profile
                  GestureDetector(
                    onTap: widget.onEditTap,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 9),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFF2F2F2),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                      child: Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      KnockButton(
                        initialStatus: _knockStatus,
                        isOwnProfile: false,
                        onStatusChanged: (s) {
                          setState(() => _knockStatus = s);
                        },
                      ),
                      // Message button (only after mutual knock)
                      if (_canMessage) ...[
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: widget.onMessageTap,
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xFFF2F2F2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.black12,
                              ),
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 18,
                              color: textColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // ── RIGHT: Profile photo ──────────────────────────────────────────
          Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: user.accountType == AccountType.creator
                        ? CreatorRankBadge.rankColor(user.rank).withValues(alpha: 0.6)
                        : (isDark ? Colors.white24 : Colors.black12),
                    width: user.accountType == AccountType.creator ? 2.5 : 1.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor:
                      isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8),
                  backgroundImage: user.avatarAsset != null
                      ? AssetImage(user.avatarAsset!)
                      : null,
                  child: user.avatarAsset == null
                      ? Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        )
                      : null,
                ),
              ),
              // Privacy badge
              if (!user.isOwnProfile)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        user.privacyType == PrivacyType.private
                            ? Icons.lock_outline_rounded
                            : Icons.public_rounded,
                        size: 11,
                        color: subColor,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        user.privacyType == PrivacyType.private
                            ? 'Private'
                            : 'Open',
                        style: TextStyle(fontSize: 10.5, color: subColor),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
