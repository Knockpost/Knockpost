import 'dart:io';

import 'package:flutter/material.dart';
import '../../models/chat_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/database_service.dart';
import '../../services/connection_service.dart';
import '../../utils/haptic_helper.dart';
import '../../widgets/knockpost_refresh.dart';
import 'chat_screen.dart';
import 'new_message_screen.dart';
import '../../widgets/knockpost_avatar.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final q = _searchController.text.trim();
      if (q != _searchQuery) setState(() => _searchQuery = q);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final searchBgColor = isDark ? Colors.grey.shade900 : Colors.grey.shade100;
    final hintColor = isDark ? Colors.grey.shade500 : Colors.grey.shade400;
    final iconColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final myUid = AuthService.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        surfaceTintColor: bgColor,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          "Messages",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: const [_NewMessageIcon()],
      ),
      body: Column(
        children: [
          // ── Search Bar ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: searchBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  icon: Icon(Icons.search, color: iconColor),
                  hintText: "Search",
                  hintStyle: TextStyle(color: hintColor),
                  border: InputBorder.none,
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            FocusScope.of(context).unfocus();
                          },
                          child: Icon(Icons.close_rounded,
                              color: iconColor, size: 20),
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),

          // ── Message List ──
          Expanded(
            child: StreamBuilder<List<ChatRoom>>(
              stream: ChatService.instance.streamUserChats(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const KnockpostLoadingIndicator();
                }

                final rooms = snapshot.data ?? [];

                // Filter by search query
                final filtered = _searchQuery.isEmpty
                    ? rooms
                    : rooms; // We filter after fetching user names below

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 48, color: hintColor),
                        const SizedBox(height: 12),
                        Text(
                          "No conversations yet",
                          style: TextStyle(color: hintColor, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Knock someone and start chatting!",
                          style: TextStyle(
                              color: hintColor.withValues(alpha: 0.7),
                              fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return KnockpostRefreshIndicator(
                  onRefresh: () async {
                    await Future.delayed(const Duration(milliseconds: 400));
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final room = filtered[index];
                      final otherUid = room.otherUid(myUid);
                      return _ChatRoomTile(
                        room: room,
                        otherUid: otherUid,
                        myUid: myUid,
                        isDark: isDark,
                        searchQuery: _searchQuery,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Per-room tile (fetches user profile lazily)
// ─────────────────────────────────────────────

class _ChatRoomTile extends StatelessWidget {
  final ChatRoom room;
  final String otherUid;
  final String myUid;
  final bool isDark;
  final String searchQuery;

  const _ChatRoomTile({
    required this.room,
    required this.otherUid,
    required this.myUid,
    required this.isDark,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: DatabaseService.instance.getUserProfile(otherUid, useCache: true),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink(); // Hide while loading
        }
        
        final data = snap.data;
        if (data == null) {
          return const SizedBox.shrink(); // Hide if user is deleted or missing
        }

        final name = (data['displayName'] as String?) ??
            (data['username'] as String?) ??
            'Unknown User';
        final username = (data['username'] as String?) ?? '';
        final avatarUrl = (data['profileImageUrl'] as String?) ?? '';
        final unread = room.unreadFor(myUid);

        // Filter by search
        if (searchQuery.isNotEmpty) {
          final q = searchQuery.toLowerCase();
          if (!name.toLowerCase().contains(q) &&
              !username.toLowerCase().contains(q) &&
              !room.lastMessage.toLowerCase().contains(q)) {
            return const SizedBox.shrink();
          }
        }

        final textColor = isDark ? Colors.white : Colors.black;
        final subtitleColor =
            isDark ? Colors.grey.shade400 : Colors.grey.shade600;
        final isUnread = unread > 0;

        return InkWell(
          enableFeedback: false,
          onTap: () {
            KnockHaptics.selection();
            final user = UserModel(
              id: otherUid,
              displayName: name,
              username: username,
              avatarAsset: avatarUrl.isNotEmpty ? avatarUrl : null,
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  otherUser: user,
                ),
              ),
            );
          },
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                KnockpostAvatar(url: avatarUrl, radius: 26, name: name),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: isUnread
                              ? FontWeight.bold
                              : FontWeight.w600,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        room.lastMessage,
                        style: TextStyle(
                          color: isUnread ? textColor : subtitleColor,
                          fontWeight: isUnread
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _timeLabel(room.lastMessageTime),
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 12,
                        fontWeight:
                            isUnread ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (isUnread)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0A7CFF),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _timeLabel(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }
}

// ─────────────────────────────────────────────
// Avatar helper
// ─────────────────────────────────────────────

// _Avatar removed — using KnockpostAvatar directly


// ─────────────────────────────────────────────
// New Message Icon
// ─────────────────────────────────────────────

class _NewMessageIcon extends StatefulWidget {
  const _NewMessageIcon();

  @override
  State<_NewMessageIcon> createState() => _NewMessageIconState();
}

class _NewMessageIconState extends State<_NewMessageIcon> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        KnockHaptics.tap();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NewMessageScreen()),
        );
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Icon(
          _isPressed ? Icons.maps_ugc : Icons.maps_ugc_outlined,
          color: textColor,
          size: 26,
        ),
      ),
    );
  }
}
