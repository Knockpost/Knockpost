import 'package:flutter/material.dart';
import '../../models/notification_model.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../profile/other_profile_screen.dart';
import '../single_post_screen.dart';
import '../../utils/haptic_helper.dart';
import '../../utils/global_knock_state.dart';
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<NotificationModel> _all = dummyNotifications;

  // Split into "This week" (< 7 days) and "Earlier" (>= 7 days)
  List<NotificationModel> get _thisWeek => _all
      .where((n) => DateTime.now().difference(n.timestamp).inDays < 7)
      .toList();

  List<NotificationModel> get _earlier => _all
      .where((n) => DateTime.now().difference(n.timestamp).inDays >= 7)
      .toList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? Colors.black : Colors.white;
    final text   = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: text),
        title: Text(
          'Notifications',
          style: TextStyle(
            color: text,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          if (_thisWeek.isNotEmpty) ...[
            _SectionHeader(label: 'This Week', isDark: isDark),
            ..._thisWeek.map((n) => _NotifTile(notif: n, isDark: isDark)),
          ],
          if (_earlier.isNotEmpty) ...[
            _SectionHeader(label: 'Earlier', isDark: isDark),
            ..._earlier.map((n) => _NotifTile(notif: n, isDark: isDark)),
          ],
          if (_all.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(
                child: Text(
                  'No notifications yet',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final bool isDark;

  const _SectionHeader({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}

// ─── Notification Tile ────────────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  final NotificationModel notif;
  final bool isDark;

  const _NotifTile({required this.notif, required this.isDark});

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60)  return '${d.inMinutes}m';
    if (d.inHours   < 24)  return '${d.inHours}h';
    if (d.inDays    < 7)   return '${d.inDays}d';
    return '${(d.inDays / 7).floor()}w';
  }

  // Icon badge shown on top-right of avatar



  // Rich text in the middle
  Widget _body(Color textColor, Color subColor) {
    final name    = notif.triggerUser.displayName;
    final timeStr = _timeAgo(notif.timestamp);

    String action;
    switch (notif.type) {
      case NotificationType.like:
        action = ' liked your post.';
        break;
      case NotificationType.comment:
        action = ' commented on your post.';
        break;
      case NotificationType.knock:
        action = ' sent you a knock.';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: TextStyle(color: textColor, fontSize: 14.5, height: 1.4),
            children: [
              TextSpan(
                text: name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: action),
              TextSpan(
                text: ' $timeStr',
                style: TextStyle(color: subColor, fontSize: 13),
              ),
            ],
          ),
        ),
        if (notif.commentSnippet != null) ...[
          const SizedBox(height: 3),
          Text(
            notif.commentSnippet!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: subColor, fontSize: 13.5),
          ),
        ],
      ],
    );
  }

  // Right side: thumbnail or "Knock Back" button
  Widget _right() {
    if (notif.type == NotificationType.knock) {
      return _KnockBackButton(isDark: isDark, user: notif.triggerUser);
    }

    if (notif.postThumbnail != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          notif.postThumbnail!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor  = isDark ? Colors.white54 : Colors.black45;
    final unreadBg  = !notif.isRead
        ? (isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFE8F4FD))
        : Colors.transparent;

    return InkWell(
      onTap: () {
        KnockHaptics.selection();
        
        if (notif.type == NotificationType.knock) {
          // Go to user profile
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtherProfileScreen(
                user: notif.triggerUser,
                posts: getDemoPostsForUser(notif.triggerUser.id),
              ),
            ),
          );
        } else {
          // Go to single post view
          final isComment = notif.type == NotificationType.comment;
          
          // Generate a realistic dummy post for the tapped notification
          final dummyPost = PostModel(
            id: 'post_${notif.id}',
            authorId: 'me',
            type: PostType.media,
            duration: PostDuration.h24,
            imagePaths: [notif.postThumbnail ?? 'assets/test1.jpg'],
            text: isComment ? 'Always an amazing perspective. 🌆' : 'Captured at the perfect moment ✨',
            createdAt: notif.timestamp.subtract(const Duration(hours: 4)), // post is older than notif
            likes: 215,
            views: 1200,
          );
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SinglePostScreen(
                post: dummyPost,
                author: demoSumanPatra, // As if it was my post
                autoOpenComments: isComment,
              ),
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: unreadBg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Avatar ────────────────────────────────────────────────────────
          SizedBox(
            width: 50,
            height: 50,
            child: CircleAvatar(
              radius: 25,
              backgroundImage:
                  AssetImage(notif.triggerUser.avatarAsset ?? 'assets/test1.jpg'),
            ),
          ),
          const SizedBox(width: 14),

          // ── Text body ───────────────────────────────────────────────────
          Expanded(child: _body(textColor, subColor)),

          const SizedBox(width: 12),

          // ── Right action ────────────────────────────────────────────────
          _right(),
        ],
      ),
    ),
    );
  }
}

class _KnockBackButton extends StatelessWidget {
  final bool isDark;
  final UserModel user;

  const _KnockBackButton({required this.isDark, required this.user});

  @override
  Widget build(BuildContext context) {
    final notifier = GlobalKnockState.getNotifier(user.id, user.knockStatus);

    return ValueListenableBuilder<KnockStatus>(
      valueListenable: notifier,
      builder: (context, status, _) {
        final isKnockedBack = status == KnockStatus.mutualKnocked || 
                              status == KnockStatus.knocked || 
                              status == KnockStatus.pending;

        if (isKnockedBack) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.black26,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              'Knocked',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          );
        }

        return GestureDetector(
          onTap: () {
            KnockHaptics.selection();
            notifier.value = user.isEffectivelyOpen
                ? KnockStatus.knocked
                : KnockStatus.pending;
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? Colors.white : Colors.black,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              'Knock Back',
              style: TextStyle(
                color: isDark ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        );
      },
    );
  }
}
