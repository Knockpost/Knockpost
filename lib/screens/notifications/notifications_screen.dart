import 'package:flutter/material.dart';
import 'dart:io';
import '../../models/notification_model.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../services/notification_service.dart';
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
      body: StreamBuilder<List<NotificationModel>>(
        stream: NotificationService.instance.streamNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
            );
          }

          final allNotifs = snapshot.data ?? [];
          
          if (allNotifs.isEmpty) {
            return const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(
                child: Text(
                  'No notifications yet',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }

          // Split into "This week" (< 7 days) and "Earlier" (>= 7 days)
          final thisWeek = allNotifs
              .where((n) => DateTime.now().difference(n.timestamp).inDays < 7)
              .toList();

          final earlier = allNotifs
              .where((n) => DateTime.now().difference(n.timestamp).inDays >= 7)
              .toList();

          return ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              if (thisWeek.isNotEmpty) ...[
                _SectionHeader(label: 'This Week', isDark: isDark),
                ...thisWeek.map((n) => _NotifTileFuture(notif: n, isDark: isDark)),
              ],
              if (earlier.isNotEmpty) ...[
                _SectionHeader(label: 'Earlier', isDark: isDark),
                ...earlier.map((n) => _NotifTileFuture(notif: n, isDark: isDark)),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
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

// ─── Wrapper to Fetch User Data ───────────────────────────────────────────────

class _NotifTileFuture extends StatelessWidget {
  final NotificationModel notif;
  final bool isDark;

  const _NotifTileFuture({required this.notif, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: DatabaseService.instance.getUserProfile(notif.triggerUserId, useCache: true),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink(); // Hide while loading

        final data = snapshot.data!;
        final user = UserModel(
          id: notif.triggerUserId,
          displayName: data['displayName'] ?? data['username'] ?? 'User',
          username: data['username'] ?? '',
          avatarAsset: data['profileImageUrl'],
        );

        return _NotifTile(notif: notif, user: user, isDark: isDark);
      },
    );
  }
}


// ─── Notification Tile ────────────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  final NotificationModel notif;
  final UserModel user;
  final bool isDark;

  const _NotifTile({required this.notif, required this.user, required this.isDark});

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60)  return '${d.inMinutes}m';
    if (d.inHours   < 24)  return '${d.inHours}h';
    if (d.inDays    < 7)   return '${d.inDays}d';
    return '${(d.inDays / 7).floor()}w';
  }

  Widget _body(Color textColor, Color subColor) {
    final name    = user.displayName;
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
        if (notif.commentSnippet != null && notif.commentSnippet!.isNotEmpty) ...[
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

  Widget _right() {
    if (notif.type == NotificationType.knock) {
      return _KnockBackButton(isDark: isDark, user: user);
    }

    if (notif.postThumbnailUrl != null && notif.postThumbnailUrl!.isNotEmpty) {
      ImageProvider imgProvider;
      if (notif.postThumbnailUrl!.startsWith('http')) {
        imgProvider = NetworkImage(notif.postThumbnailUrl!);
      } else if (notif.postThumbnailUrl!.startsWith('assets/')) {
        imgProvider = AssetImage(notif.postThumbnailUrl!);
      } else {
        imgProvider = FileImage(File(notif.postThumbnailUrl!));
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image(
          image: imgProvider,
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
        
        // Mark as read
        if (!notif.isRead) {
          NotificationService.instance.markAsRead(notif.id);
        }
        
        if (notif.type == NotificationType.knock) {
          // Go to user profile
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtherProfileScreen(
                user: user,
                // Using empty posts for now since we don't fetch full user posts in notif
                posts: const [], 
              ),
            ),
          );
        } else {
          // Go to single post view (we need a post model)
          final isComment = notif.type == NotificationType.comment;
          
          final dummyPost = PostModel(
            id: notif.postId ?? 'post_${notif.id}',
            authorId: 'me', // Doesn't matter for this view
            type: PostType.media,
            duration: PostDuration.h24,
            imagePaths: notif.postThumbnailUrl != null ? [notif.postThumbnailUrl!] : [],
            text: isComment ? notif.commentSnippet ?? '' : '',
            createdAt: notif.timestamp.subtract(const Duration(hours: 4)), 
            likes: 0,
            views: 0,
          );
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SinglePostScreen(
                post: dummyPost,
                author: demoSumanPatra, // We should fetch my user data here ideally, but using demo is fine for UI
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
            child: _Avatar(url: user.avatarAsset ?? '', isDark: isDark),
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

class _Avatar extends StatelessWidget {
  final String url;
  final bool isDark;
  const _Avatar({required this.url, required this.isDark});

  @override
  Widget build(BuildContext context) {
    ImageProvider? img;
    if (url.isNotEmpty) {
      if (url.startsWith('http')) {
        img = NetworkImage(url);
      } else if (url.startsWith('assets/')) {
        img = AssetImage(url);
      } else {
        img = FileImage(File(url));
      }
    }
    return CircleAvatar(
      radius: 25,
      backgroundColor:
          isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
      backgroundImage: img,
      child: img == null
          ? Icon(Icons.person, size: 24, color: Colors.grey.shade500)
          : null,
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
