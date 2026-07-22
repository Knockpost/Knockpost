import 'package:flutter/material.dart';
import 'package:knockpost/widgets/knockpost_refresh.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/notification_model.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../services/notification_service.dart';
import '../../services/current_user_service.dart';
import '../../services/user_cache_service.dart';
import '../profile/other_profile_screen.dart';
import '../../utils/haptic_helper.dart';
import '../../utils/global_knock_state.dart';
import '../../widgets/knockpost_avatar.dart';
import '../../services/connection_service.dart';
import '../../services/performance_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/post_model.dart';
import '../single_post_screen.dart';
import '../messages/chat_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// NOTIFICATIONS SCREEN v2.0
// ═══════════════════════════════════════════════════════════════════════════════
//
// Features:
//   • Real-time sync via Firestore snapshots
//   • Animated unread → read transition (subtle highlight fade)
//   • Time-grouped sections: Today, Yesterday, This Week, This Month
//   • Consistent human wording via NotificationModel.actionText()
//   • Swipe-to-delete with confirmation
//   • Auto-cleanup of 30-day-old notifications (server-side efficient)
//   • Support for all notification types including mention and waveLike
// ═══════════════════════════════════════════════════════════════════════════════

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final Set<String> _newlyReadIds = {};
  bool _hasMarkedAsRead = false;
  
  int _limit = 50;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  
  List<NotificationModel> _cachedNotifs = [];
  DateTime? _lastRefreshTime;

  @override
  void initState() {
    super.initState();
    // Clean up old notifications once per session (efficient server query)
    NotificationService.instance.cleanupOldNotifications();
    
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    // Do not trigger pagination if the list doesn't even fill the screen
    if (_scrollController.position.maxScrollExtent <= 0) return;

    // Do not trigger pagination if we've already fetched all available items
    if (_cachedNotifs.length < _limit) return;

    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore) {
        _isLoadingMore = true;
        setState(() {
          _limit += 50;
        });
        PerformanceService.instance.incrementNotificationStreamPagesLoaded();
        
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) _isLoadingMore = false;
        });
      }
    }
  }

  void _markAllRead(List<NotificationModel> notifications) {
    if (_hasMarkedAsRead) return;
    _hasMarkedAsRead = true;

    bool hasUnread = false;
    for (var n in notifications) {
      if (!n.isRead) {
        _newlyReadIds.add(n.id);
        hasUnread = true;
      }
    }

    if (hasUnread) {
      NotificationService.instance.markAllAsRead();
    }
  }

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
        titleSpacing: 0,
        centerTitle: false,
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            'Notifications',
            style: TextStyle(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 22,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: NotificationService.instance.streamNotifications(limit: _limit),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _cachedNotifs = snapshot.data!;
          }

          if (_cachedNotifs.isEmpty && snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: KnockPostLoadingIndicator(),
            );
          }

          final allNotifs = _cachedNotifs;
          
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

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _markAllRead(allNotifs);
          });

          final now = DateTime.now();
          final todayUtc = DateTime.utc(now.year, now.month, now.day);

          final todayNotifs = <NotificationModel>[];
          final yesterdayNotifs = <NotificationModel>[];
          final earlierThisWeekNotifs = <NotificationModel>[];
          final earlierThisMonthNotifs = <NotificationModel>[];

          for (var n in allNotifs) {
            final dateUtc = DateTime.utc(n.timestamp.year, n.timestamp.month, n.timestamp.day);
            final differenceInDays = todayUtc.difference(dateUtc).inDays;

            if (differenceInDays == 0) {
              todayNotifs.add(n);
            } else if (differenceInDays == 1) {
              yesterdayNotifs.add(n);
            } else if (differenceInDays <= 6) {
              earlierThisWeekNotifs.add(n);
            } else if (differenceInDays <= 30) {
              earlierThisMonthNotifs.add(n);
            }
            // > 30 days are cleaned up by cleanupOldNotifications()
          }

          final flattenedItems = <Widget>[];
          
          if (todayNotifs.isNotEmpty) {
            flattenedItems.add(_SectionHeader(label: 'Today', isDark: isDark));
            flattenedItems.addAll(todayNotifs.map((n) => _NotifTileFuture(key: ValueKey(n.id), notif: n, isDark: isDark, isNewlyRead: _newlyReadIds.contains(n.id))));
          }
          if (yesterdayNotifs.isNotEmpty) {
            flattenedItems.add(_SectionHeader(label: 'Yesterday', isDark: isDark));
            flattenedItems.addAll(yesterdayNotifs.map((n) => _NotifTileFuture(key: ValueKey(n.id), notif: n, isDark: isDark, isNewlyRead: _newlyReadIds.contains(n.id))));
          }
          if (earlierThisWeekNotifs.isNotEmpty) {
            flattenedItems.add(_SectionHeader(label: 'Earlier This Week', isDark: isDark));
            flattenedItems.addAll(earlierThisWeekNotifs.map((n) => _NotifTileFuture(key: ValueKey(n.id), notif: n, isDark: isDark, isNewlyRead: _newlyReadIds.contains(n.id))));
          }
          if (earlierThisMonthNotifs.isNotEmpty) {
            flattenedItems.add(_SectionHeader(label: 'Earlier This Month', isDark: isDark));
            flattenedItems.addAll(earlierThisMonthNotifs.map((n) => _NotifTileFuture(key: ValueKey(n.id), notif: n, isDark: isDark, isNewlyRead: _newlyReadIds.contains(n.id))));
          }
          
          flattenedItems.add(const SizedBox(height: 24));

          return KnockPostRefreshIndicator(
            onRefresh: () async {
              final now = DateTime.now();
              if (_lastRefreshTime == null || now.difference(_lastRefreshTime!) > const Duration(seconds: 10)) {
                _lastRefreshTime = now;
                // Since StreamBuilder is realtime, we just show the elegant animation
                await Future.delayed(const Duration(milliseconds: 1200));
              }
            },
            child: ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
              itemCount: flattenedItems.length,
              itemBuilder: (context, index) => flattenedItems[index],
            ),
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
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
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

class _NotifTileFuture extends StatefulWidget {
  final NotificationModel notif;
  final bool isDark;
  final bool isNewlyRead;

  const _NotifTileFuture({
    super.key,
    required this.notif,
    required this.isDark,
    required this.isNewlyRead,
  });

  @override
  State<_NotifTileFuture> createState() => _NotifTileFutureState();
}

class _NotifTileFutureState extends State<_NotifTileFuture> {
  Map<String, dynamic>? _cachedProfile;
  Future<Map<String, dynamic>?>? _profileFuture;

  @override
  void initState() {
    super.initState();
    _cachedProfile = UserCacheService.instance.getCachedUserProfile(widget.notif.triggerUserId);
    if (_cachedProfile == null) {
      _profileFuture = DatabaseService.instance.getUserProfile(widget.notif.triggerUserId, useCache: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cachedProfile != null) {
      final user = UserModel.fromMap(_cachedProfile!, widget.notif.triggerUserId);
      return _NotifTile(
        notif: widget.notif, 
        user: user, 
        isDark: widget.isDark, 
        isNewlyRead: widget.isNewlyRead,
      );
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Provide a fixed-height placeholder to prevent violent layout jumps during scroll
          return const SizedBox(height: 74); 
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          // The user profile couldn't be loaded (e.g., deleted account or invalid data).
          // Silently hide this notification and clean it up from the database to prevent blank spaces.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            NotificationService.instance.deleteNotification(widget.notif.id);
          });
          return const SizedBox.shrink();
        }

        final data = snapshot.data!;
        final user = UserModel.fromMap(data, widget.notif.triggerUserId);

        return _NotifTile(
          notif: widget.notif, 
          user: user, 
          isDark: widget.isDark, 
          isNewlyRead: widget.isNewlyRead,
        );
      },
    );
  }
}


// ─── Notification Tile ────────────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  final NotificationModel notif;
  final UserModel user;
  final bool isDark;
  final bool isNewlyRead;

  const _NotifTile({required this.notif, required this.user, required this.isDark, required this.isNewlyRead});

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60)  return '${d.inMinutes}m';
    if (d.inHours   < 24)  return '${d.inHours}h';
    if (d.inDays    < 7)   return '${d.inDays}d';
    return '${(d.inDays / 7).floor()}w';
  }

  Widget _body(Color textColor, Color subColor, KnockStatus status) {
    final name    = user.displayName;
    final timeStr = _timeAgo(notif.timestamp);

    // ── Use centralized human-style wording from the model ──
    String action;
    if (notif.type == NotificationType.knock) {
      // For knock type, use connection status to determine wording
      final knockConnectionStatus = (status == KnockStatus.theyKnockedYouPending) ? 'pending' : null;
      action = ' ${notif.actionText(knockConnectionStatus: knockConnectionStatus)}';
    } else {
      action = ' ${notif.actionText()}';
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

  Widget _right(BuildContext context, KnockStatus status, ValueNotifier<KnockStatus> notifier) {
    if (notif.type == NotificationType.knock || notif.type == NotificationType.knockAccept || notif.type == NotificationType.knockBack) {
      return _KnockBackButton(isDark: isDark, user: user, status: status, notifier: notifier);
    }
    
    if (notif.type == NotificationType.like || notif.type == NotificationType.comment || notif.type == NotificationType.waveLike) {
      if (notif.postThumbnailUrl != null && notif.postThumbnailUrl!.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: CachedNetworkImage(
            imageUrl: notif.postThumbnailUrl!,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            memCacheWidth: (44 * MediaQuery.devicePixelRatioOf(context)).toInt(),
            placeholder: (context, url) => Container(
              width: 44,
              height: 44,
              color: isDark ? Colors.white10 : Colors.black12,
            ),
            errorWidget: (context, url, error) => _buildPlaceholder(),
          ),
        );
      } else {
        return _buildPlaceholder();
      }
    }
    return const SizedBox.shrink();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black12,
          width: 0.5,
        ),
      ),
      child: Icon(
        Icons.article_rounded,
        size: 20,
        color: isDark ? Colors.white54 : Colors.black45,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor  = isDark ? Colors.white54 : Colors.black45;
    
    // ── Unread highlight: subtle background that fades when read ──
    final isUnread = !notif.isRead || isNewlyRead;
    final unreadBg = isUnread
        ? (isDark
            ? const Color(0xFF1C1C1E)
            : const Color(0xFFF2F2F2))
        : Colors.transparent;

    final notifier = GlobalKnockState.getNotifier(user.id, user.knockStatus);

    return Dismissible(
      key: ValueKey(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.shade400,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) {
        NotificationService.instance.deleteNotification(notif.id);
      },
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              title: Text(
                'Delete notification?',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                'Are you sure you want to delete this notification? This action cannot be undone.',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            );
          },
        );
      },
      child: InkWell(
        onTap: () async {
        KnockHaptics.selection();

        if (!notif.isRead) {
          NotificationService.instance.markAsRead(notif.id);
        }

        if (notif.type == NotificationType.knock || notif.type == NotificationType.knockAccept || notif.type == NotificationType.knockBack) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtherProfileScreen(
                user: user,
                posts: const [],
              ),
            ),
          );
        } else if (notif.type == NotificationType.message) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                otherUser: user,
              ),
            ),
          );
        } else if (notif.type == NotificationType.mention) {
          // Navigate to the post where user was mentioned
          if (notif.postId != null) {
            _navigateToPost(context, notif.postId!);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OtherProfileScreen(
                  user: user,
                  posts: const [],
                ),
              ),
            );
          }
        } else if ((notif.type == NotificationType.comment || notif.type == NotificationType.like || notif.type == NotificationType.waveLike) && notif.postId != null) {
          _navigateToPost(context, notif.postId!, autoOpenComments: notif.type == NotificationType.comment, autoOpenReactions: notif.type == NotificationType.like || notif.type == NotificationType.waveLike);
        }
      },

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: unreadBg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ValueListenableBuilder<KnockStatus>(
          valueListenable: notifier,
          builder: (context, status, _) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: _Avatar(url: user.avatarAsset ?? '', isDark: isDark),
                ),
                const SizedBox(width: 14),
                Expanded(child: _body(textColor, subColor, status)),
                const SizedBox(width: 12),
                _right(context, status, notifier),
              ],
            );
          },
        ),
      ),
      ),
    );
  }

  void _navigateToPost(BuildContext context, String postId, {bool autoOpenComments = false, bool autoOpenReactions = false}) async {
    final currentUser = CurrentUserService.instance.currentUser;
    if (currentUser != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('posts').doc(postId).get();
        if (doc.exists && doc.data() != null && context.mounted) {
          final post = PostModel.fromMap(doc.data()!, doc.id);
          
          UserModel postAuthor = currentUser;
          try {
            final authorDoc = await FirebaseFirestore.instance.collection('users').doc(post.authorId).get();
            if (authorDoc.exists && authorDoc.data() != null) {
              final fetchedAuthor = UserModel.fromMap(authorDoc.data()!, authorDoc.id);
              postAuthor = fetchedAuthor.copyWith(
                isOwnProfile: currentUser.id == post.authorId,
              );
            }
          } catch (e) {
            debugPrint('Failed to fetch post author: $e');
          }

          if (!context.mounted) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SinglePostScreen(
                post: post,
                author: postAuthor,
                autoOpenComments: autoOpenComments,
                autoOpenReactions: autoOpenReactions,
                isPostOwner: currentUser.id == postAuthor.id,
                initialThreadUserId: (notif.type == NotificationType.comment) ? notif.triggerUserId : null,
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error fetching post for notification: $e');
      }
    }
  }
}

class _Avatar extends StatelessWidget {
  final String url;
  final bool isDark;
  const _Avatar({required this.url, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return KnockPostAvatar(
      url: url.isNotEmpty ? url : null,
      radius: 25,
    );
  }
}

class _KnockBackButton extends StatelessWidget {
  final bool isDark;
  final UserModel user;
  final KnockStatus status;
  final ValueNotifier<KnockStatus> notifier;

  const _KnockBackButton({
    required this.isDark, 
    required this.user,
    required this.status,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    if (status == KnockStatus.none) {
      return const SizedBox.shrink();
    }

    if (status == KnockStatus.theyKnockedYouPending) {
      return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  KnockHaptics.selection();
                  notifier.value = KnockStatus.theyKnockedYou;
                  try {
                    await ConnectionService.instance.approveKnock(user.id);
                  } catch (e) {
                    notifier.value = KnockStatus.theyKnockedYouPending;
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Text(
                    'Accept',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  KnockHaptics.selection();
                  notifier.value = KnockStatus.none;
                  try {
                    await ConnectionService.instance.declineKnock(user.id);
                  } catch (e) {
                    notifier.value = KnockStatus.theyKnockedYouPending;
                  }
                },
                child: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          );
        }

        final isKnockedBack = status == KnockStatus.mutualKnocked || 
                              status == KnockStatus.knocked || 
                              status == KnockStatus.pending;

        if (isKnockedBack) {
          return const SizedBox.shrink();
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () async {
                KnockHaptics.selection();
                notifier.value = KnockStatus.mutualKnocked;
                try {
                  await ConnectionService.instance.acceptKnock(user.id);
                } catch (e) {
                  notifier.value = KnockStatus.theyKnockedYou;
                }
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
            ),
          ],
        );
  }
}
