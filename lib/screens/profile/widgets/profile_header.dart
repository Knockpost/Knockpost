import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/user_model.dart';
import '../../../models/post_model.dart';
import '../../../utils/haptic_helper.dart';
import '../../../widgets/knockpost_avatar.dart';
import '../../../utils/image_helper.dart';
import '../../../services/connection_service.dart';
import '../../../services/database_service.dart';
import '../../../services/image_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/current_user_service.dart';
import '../../discover/discover_people_screen.dart';
import '../connections_screen.dart';
import '../other_profile_screen.dart';
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
  /// Real users who knocked this profile (fetched from Firestore).
  final List<UserModel> knockerUsers;

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
    this.knockerUsers = const [],
  });

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  late KnockStatus _knockStatus;
  bool _socialLinksExpanded = false;

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
      _knockStatus == KnockStatus.knocked ||
      _knockStatus == KnockStatus.mutualKnocked;

  Future<void> _launchURL(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _launchSocialLink(String key, String value) {
    switch (key) {
      case 'instagram':
        _launchURL('https://instagram.com/$value');
        break;
      case 'youtube':
        _launchURL(value.startsWith('http') ? value : 'https://youtube.com/@$value');
        break;
      case 'linkedin':
        _launchURL(value.startsWith('http') ? value : 'https://linkedin.com/in/$value');
        break;
      case 'x':
        _launchURL('https://x.com/$value');
        break;
      default:
        _launchURL(value);
    }
  }



  String _socialDisplayUrl(String key, String value) {
    switch (key) {
      case 'instagram': return 'instagram.com/$value';
      case 'youtube': return 'youtube.com/@$value';
      case 'linkedin': return 'linkedin.com/in/$value';
      case 'x': return 'x.com/$value';
      default: return value;
    }
  }



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
    
    final currentUser = CurrentUserService.instance.currentUser;
    final validKnockers = widget.knockerUsers.where((k) => k.id != currentUser?.id).toList();

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
                                  ? AssetImage(user.coverImageAsset!) as ImageProvider
                                  : user.coverImageAsset!.startsWith('http')
                                      ? CachedNetworkImageProvider(
                                          user.coverImageAsset!,
                                          cacheManager: KnockpostImageCacheManager.instance,
                                        ) as ImageProvider
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
                      if (user.socialLinks.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // First link row (always visible) + "and X others"
                                GestureDetector(
                                  onTap: () {
                                    KnockHaptics.selection();
                                    if (user.socialLinks.length == 1) {
                                      final entry = user.socialLinks.entries.first;
                                      _launchSocialLink(entry.key, entry.value);
                                    } else {
                                      setState(() => _socialLinksExpanded = !_socialLinksExpanded);
                                    }
                                  },
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text.rich(
                                          TextSpan(
                                            children: [
                                              TextSpan(
                                                text: _socialDisplayUrl(
                                                  user.socialLinks.keys.first,
                                                  user.socialLinks.values.first,
                                                ),
                                              ),
                                              if (user.socialLinks.length > 1 && !_socialLinksExpanded)
                                                TextSpan(
                                                  text: '   and ${user.socialLinks.length - 1} other${user.socialLinks.length - 1 > 1 ? 's' : ''}',
                                                ),
                                            ],
                                          ),
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            color: isDark ? const Color(0xFFE0F1FF) : const Color(0xFF00376B),
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: -0.2,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (_socialLinksExpanded)
                                        Icon(
                                          Icons.keyboard_arrow_up_rounded,
                                          size: 20,
                                          color: isDark ? const Color(0xFFE0F1FF) : const Color(0xFF00376B),
                                        ),
                                    ],
                                  ),
                                ),
                                // Expanded links (remaining links)
                                if (_socialLinksExpanded)
                                  ...user.socialLinks.entries.skip(1).map((entry) {
                                    return GestureDetector(
                                      onTap: () {
                                        KnockHaptics.selection();
                                        _launchSocialLink(entry.key, entry.value);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 3),
                                        child: Text(
                                          _socialDisplayUrl(entry.key, entry.value),
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            color: isDark ? const Color(0xFFE0F1FF) : const Color(0xFF00376B),
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: -0.2,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      if (user.isOwnProfile)
                        _buildOwnFriendsRow(context, textColor, isDark)
                      else if (validKnockers.isNotEmpty)
                        _buildFriendsKnockedRow(validKnockers, textColor, isDark),
                      if (user.isOwnProfile ||
                          validKnockers.isNotEmpty)
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

  Widget _buildFriendsKnockedRow(List<UserModel> knockers, Color textColor, bool isDark) {
    // Show up to 3 stacked avatars
    final shown = knockers.length > 3 ? knockers.sublist(0, 3) : knockers;
    final stackWidth = 16.0 * (shown.length - 1) + 26;

    return GestureDetector(
      onTap: () {
        KnockHaptics.selection();
        _showFriendsKnockedSheet(context, knockers, isDark);
      },
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          SizedBox(
            width: stackWidth,
            height: 26,
            child: Stack(
              children: [
                for (int i = 0; i < shown.length; i++)
                  Positioned(
                    left: i * 16.0,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? Colors.black : Colors.white,
                          width: 1.5,
                        ),
                      ),
                      child: KnockPostAvatar(
                        url: shown[i].avatarAsset,
                        optimizedUrl: shown[i].optimizedAvatarUrl,
                        radius: 11,
                        name: shown[i].displayName,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              knockers.length == 1
                  ? '${knockers.first.displayName} knocked'
                  : '${knockers.first.displayName} and ${knockers.length - 1} other${knockers.length > 2 ? 's' : ''} knocked',
              style: TextStyle(
                fontSize: 13.5,
                color: textColor.withValues(alpha: 0.7),
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showFriendsKnockedSheet(BuildContext context, List<UserModel> knockers, bool isDark) {
    final bg = isDark ? const Color(0xFF171717) : Colors.white;
    final divColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEAEAEA);
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.55 + MediaQuery.of(context).viewPadding.bottom,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            border: Border(top: BorderSide(color: divColor)),
          ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      Text(
                        'People who knocked',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${knockers.length}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: subColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Divider(height: 1, color: divColor),
                Flexible(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shrinkWrap: true,
                    itemCount: knockers.length,
                    itemBuilder: (ctx, index) {
                      final friend = knockers[index];
                      return InkWell(
                        onTap: () {
                          KnockHaptics.tap();
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OtherProfileScreen(
                                user: friend,
                                posts: const [],
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          child: Row(
                            children: [
                              // Avatar
                              KnockPostAvatar(
                                url: friend.avatarAsset,
                                optimizedUrl: friend.optimizedAvatarUrl,
                                radius: 23,
                                name: friend.displayName,
                              ),
                              const SizedBox(width: 12),
                              // Name + username
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            friend.displayName,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: textColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (friend.accountType == AccountType.creator) ...[
                                          const SizedBox(width: 5),
                                          CreatorRankBadge(rank: friend.rank, mini: true),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      '@${friend.username}',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: subColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Arrow indicator
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: isDark ? Colors.white24 : Colors.black26,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
        );
      },
    );
  }

  Widget _buildOwnFriendsRow(BuildContext context, Color textColor, bool isDark) {
    return GestureDetector(
      onTap: () {
        KnockHaptics.impact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ConnectionsScreen()),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: StreamBuilder<List<String>>(
        stream: ConnectionService.instance.streamMutualConnectionUids(),
        builder: (context, snapshot) {
          final uids = snapshot.data ?? [];
          final displayUids = uids.take(3).toList();
          
          return Row(
            children: [
              if (displayUids.isNotEmpty) ...[
                SizedBox(
                  width: 26.0 + (displayUids.length - 1) * 16.0,
                  height: 26,
                  child: FutureBuilder<List<Map<String, dynamic>?>>(
                    future: Future.wait(displayUids.map((uid) =>
                        DatabaseService.instance.getUserProfile(uid, useCache: true))),
                    builder: (context, userSnapshot) {
                      final usersData = userSnapshot.data ?? [];
                      return Stack(
                        children: List.generate(usersData.length, (i) {
                          final userData = usersData[i];
                          final avatar = userData?['profileImageUrl'] as String?;
                          return _friendPreviewAvatar(avatar, i * 16.0, isDark);
                        }),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                'Connections',
                style: TextStyle(
                  fontSize: 14.5,
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _friendPreviewAvatar(String? asset, double left, bool isDark) {
    return Positioned(
      left: left,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.grey[300],
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? const Color(0xFF111111) : Colors.white,
            width: 1.6,
          ),
          image: asset != null && asset.isNotEmpty
              ? DecorationImage(
                  image: ImageHelper.resolveAvatar(asset)!,
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: asset == null || asset.isEmpty
            ? Icon(Icons.person, size: 14, color: isDark ? Colors.white54 : Colors.black54)
            : null,
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

class _ZoomableAvatarState extends State<_ZoomableAvatar> {
  final GlobalKey _avatarKey = GlobalKey();
  Timer? _pressTimer;

  @override
  void dispose() {
    _pressTimer?.cancel();
    super.dispose();
  }

  void _showZoom() {
    final renderBox = _avatarKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    HapticFeedback.mediumImpact();

    final avatarSize = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final avatarCenter = Offset(
      offset.dx + avatarSize.width / 2,
      offset.dy + avatarSize.height / 2,
    );

    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.transparent,
      fullscreenDialog: true,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _ZoomOverlay(
          avatarCenter: avatarCenter,
          avatarSize: avatarSize,
          user: widget.user,
          isDark: widget.isDark,
          bg: widget.bg,
          radius: widget.radius,
        );
      },
    ));
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
      child: KnockPostAvatar(
        url: user.avatarAsset,
        optimizedUrl: user.optimizedAvatarUrl,
        radius: widget.radius,
        name: user.displayName,
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
      onPointerUp: (_) => _pressTimer?.cancel(),
      onPointerCancel: (_) => _pressTimer?.cancel(),
      child: _buildAvatarContent(),
    );
  }
}

class _ZoomOverlay extends StatefulWidget {
  final Offset avatarCenter;
  final Size avatarSize;
  final UserModel user;
  final bool isDark;
  final Color bg;
  final double radius;

  const _ZoomOverlay({
    required this.avatarCenter,
    required this.avatarSize,
    required this.user,
    required this.isDark,
    required this.bg,
    required this.radius,
  });

  @override
  State<_ZoomOverlay> createState() => _ZoomOverlayState();
}

class _ZoomOverlayState extends State<_ZoomOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  double _userScale = 1.0;
  double _baseScale = 1.0;
  bool _isClosing = false;

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
    _controller.forward();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismissZoom() {
    if (_isClosing) return;
    _isClosing = true;
    HapticFeedback.lightImpact();
    _controller.reverse().then((_) {
      if (mounted) Navigator.of(context).pop();
    });
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
      child: KnockPostAvatar(
        url: user.avatarAsset,
        optimizedUrl: user.optimizedAvatarUrl,
        radius: widget.radius,
        name: user.displayName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenCenter = screenSize.center(Offset.zero);
    final scale = _scaleAnimation.value;
    final fade = _fadeAnimation.value;
    final progress = ((scale - 1.0) / 1.72).clamp(0.0, 1.0);

    final dx = widget.avatarCenter.dx + (screenCenter.dx - widget.avatarCenter.dx) * progress;
    final dy = widget.avatarCenter.dy + (screenCenter.dy - widget.avatarCenter.dy) * progress;
    final totalScale = scale * _userScale;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _dismissZoom();
        }
      },
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          onTap: _dismissZoom,
          onScaleStart: (details) {
            _baseScale = _userScale;
          },
          onScaleUpdate: (details) {
            setState(() {
              _userScale = (_baseScale * details.scale).clamp(0.85, 1.5);
            });
          },
          onScaleEnd: (_) {
            setState(() {
              _userScale = 1.0;
            });
          },
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: fade * 8.0, sigmaY: fade * 8.0),
                  child: Container(
                    color: (widget.isDark ? Colors.black : Colors.white).withValues(alpha: fade * 0.05),
                  ),
                ),
              ),
              Positioned(
                left: dx - widget.avatarSize.width / 2,
                top: dy - widget.avatarSize.height / 2,
                width: widget.avatarSize.width,
                height: widget.avatarSize.height,
                child: Transform.scale(
                  scale: totalScale,
                  child: _buildAvatarContent(),
                ),
              ),
            ],
          ),
        ),
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

