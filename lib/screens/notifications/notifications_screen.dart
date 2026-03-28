import 'package:flutter/material.dart';
import '../../models/notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<NotificationModel> _notifications = dummyNotifications;

  @override
  void initState() {
    super.initState();
    // 3 Tabs: All, Mentions, Authors (Substack style)
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          "Notifications",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: textColor,
          labelColor: textColor,
          unselectedLabelColor: secondaryTextColor,
          dividerColor: Colors.transparent,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          tabs: const [
            Tab(text: "All Activity"),
            Tab(text: "Mentions"),
            Tab(text: "Creators"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // "All Activity" Tab
          _buildNotificationList(_notifications, isDark),
          
          // "Mentions" Tab
          _buildNotificationList(
            _notifications.where((n) => n.type == NotificationType.mention).toList(),
            isDark,
            emptyMessage: "No recent mentions",
          ),
          
          // "Creators" Tab (Substack updates)
          _buildNotificationList(
            _notifications.where((n) => n.type == NotificationType.newPost).toList(),
            isDark,
            emptyMessage: "No new posts from creators you've knocked",
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList(List<NotificationModel> list, bool isDark, {String emptyMessage = "No notifications yet"}) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
        ),
      );
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        return NotificationTile(
          notification: list[index],
          isDark: isDark,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Notification Tile Widget
// ─────────────────────────────────────────────

class NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final bool isDark;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.isDark,
  });

  String _getTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return "${diff.inMinutes}m";
    if (diff.inHours < 24) return "${diff.inHours}h";
    return "${diff.inDays}d";
  }

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryColor = isDark ? Colors.white54 : Colors.black54;

    // A subtle unread indicator background
    final bgColor = !notification.isRead
        ? (isDark ? Colors.white.withOpacity(0.05) : Colors.blue.withOpacity(0.05))
        : Colors.transparent;

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Universal: User Avatar
          CircleAvatar(
            radius: 22,
            backgroundImage: AssetImage(notification.triggerUser.avatarAsset ?? "assets/test1.jpg"),
          ),
          const SizedBox(width: 14),
          
          // Dynamic Middle Content
          Expanded(
            child: _buildMiddleContent(textColor, secondaryColor),
          ),
          
          const SizedBox(width: 12),
          
          // Dynamic Right Action/Thumbnail
          _buildRightContent(isDark),
        ],
      ),
    );
  }

  Widget _buildMiddleContent(Color textColor, Color secondaryColor) {
    final name = notification.triggerUser.displayName;
    final timeStr = _getTimeAgo(notification.timestamp);
    
    switch (notification.type) {
      case NotificationType.like:
        return RichText(
          text: TextSpan(
            style: TextStyle(color: textColor, fontSize: 15, height: 1.4),
            children: [
              TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.bold)),
              const TextSpan(text: " liked your knock. "),
              TextSpan(text: timeStr, style: TextStyle(color: secondaryColor, fontSize: 13)),
            ],
          ),
        );
      case NotificationType.comment:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(color: textColor, fontSize: 15, height: 1.4),
                children: [
                  TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: " commented on your knock. "),
                  TextSpan(text: timeStr, style: TextStyle(color: secondaryColor, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              notification.contentSnippet ?? "",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: secondaryColor, fontSize: 14),
            )
          ],
        );
      case NotificationType.follow:
        return RichText(
          text: TextSpan(
            style: TextStyle(color: textColor, fontSize: 15, height: 1.4),
            children: [
              TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.bold)),
              const TextSpan(text: " knocked on your profile. "),
              TextSpan(text: timeStr, style: TextStyle(color: secondaryColor, fontSize: 13)),
            ],
          ),
        );
      case NotificationType.mention:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(color: textColor, fontSize: 15, height: 1.4),
                children: [
                  TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: " mentioned you on a knock. "),
                  TextSpan(text: timeStr, style: TextStyle(color: secondaryColor, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              notification.contentSnippet ?? "",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: secondaryColor, fontSize: 14),
            )
          ],
        );
      case NotificationType.newPost:
      // Substack style presentation
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  name,
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  " shared a new thought • $timeStr",
                  style: TextStyle(color: secondaryColor, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              notification.postTitle ?? "New Thought",
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
            if (notification.contentSnippet != null) ...[
              const SizedBox(height: 4),
              Text(
                notification.contentSnippet!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: secondaryColor,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ]
          ],
        );
    }
  }

  Widget _buildRightContent(bool isDark) {
    if (notification.type == NotificationType.like || notification.type == NotificationType.comment) {
      if (notification.postThumbnail != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset(
            notification.postThumbnail!,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
          ),
        );
      }
    }
    
    if (notification.type == NotificationType.follow) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white : Colors.black,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          "Knock Back",
          style: TextStyle(
            color: isDark ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      );
    }

    if (notification.type == NotificationType.newPost) {
      return Container(
        margin: const EdgeInsets.only(top: 24),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: isDark ? Colors.white24 : Colors.black26),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          "Read",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    return const SizedBox.shrink(); // Empty space for mentions
  }
}
