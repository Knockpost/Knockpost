import 'package:flutter/material.dart';
import '../../utils/haptic_helper.dart';
import 'chat_screen.dart';
import 'new_message_screen.dart';

class _ConversationData {
  final String name;
  final String message;
  final String time;
  final int unreadCount;
  final bool read;

  const _ConversationData({
    required this.name,
    required this.message,
    required this.time,
    this.unreadCount = 0,
    this.read = false,
  });
}

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const List<_ConversationData> _conversations = [
    _ConversationData(
      name: "John Doe",
      message: "Just finished work, what's up?",
      time: "2m",
      unreadCount: 2,
    ),
    _ConversationData(
      name: "Jane Doe",
      message: "That sounds awesome! 😂",
      time: "10m",
      unreadCount: 1,
    ),
    _ConversationData(
      name: "Alex Smith",
      message: "Are we still on for tomorrow?",
      time: "30m",
      read: true,
    ),
    _ConversationData(
      name: "Emily Brown",
      message: "Sure, I'll send it over to you!",
      time: "45m",
      read: true,
    ),
    _ConversationData(
      name: "Daniel Lee",
      message: "Can you call me when you're free?",
      time: "1h",
      read: true,
    ),
    _ConversationData(
      name: "Sarah Wilson",
      message: "Haha that's so funny!",
      time: "2h",
      read: true,
    ),
  ];

  List<_ConversationData> get _filteredConversations {
    if (_searchQuery.isEmpty) return _conversations;
    final query = _searchQuery.toLowerCase();
    return _conversations.where((c) {
      return c.name.toLowerCase().contains(query) ||
          c.message.toLowerCase().contains(query);
    }).toList();
  }

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
    final filtered = _filteredConversations;

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
        actions: const [
          _NewMessageIcon(),
        ],
      ),

      body: Column(
        children: [
          /// SEARCH BAR
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

          const SizedBox(height: 10),

          /// MESSAGE LIST
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded,
                            size: 48, color: hintColor),
                        const SizedBox(height: 12),
                        Text(
                          "No results for \"$_searchQuery\"",
                          style: TextStyle(
                            color: hintColor,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final c = filtered[index];
                      return MessageTile(
                        name: c.name,
                        message: c.message,
                        time: c.time,
                        unreadCount: c.unreadCount,
                        read: c.read,
                        searchQuery: _searchQuery,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}


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
          MaterialPageRoute(
            builder: (context) => const NewMessageScreen(),
          ),
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

class MessageTile extends StatelessWidget {
  final String name;
  final String message;
  final String time;
  final int unreadCount;
  final bool read;
  final String searchQuery;

  const MessageTile({
    super.key,
    required this.name,
    required this.message,
    required this.time,
    this.unreadCount = 0,
    this.read = false,
    this.searchQuery = '',
  });

  /// Build a RichText with the matching substring highlighted.
  Widget _highlightText(
    String text, {
    required Color color,
    required FontWeight fontWeight,
    double fontSize = 14,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: overflow,
      style: TextStyle(color: color, fontWeight: fontWeight, fontSize: fontSize),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    const highlightColor = Color(0xFF0A7CFF); // Vibrant Blue

    return InkWell(
      enableFeedback: false,
      onTap: () {
        KnockHaptics.selection();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ChatScreen()),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 26,
              backgroundImage: AssetImage("assets/test1.jpg"),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _highlightText(
                    name,
                    color: textColor,
                    fontWeight: (!read && unreadCount > 0) ? FontWeight.bold : FontWeight.w600,
                    fontSize: 16,
                  ),

                  const SizedBox(height: 4),

                  _highlightText(
                    message,
                    color: (!read && unreadCount > 0) ? textColor : subtitleColor,
                    fontWeight: (!read && unreadCount > 0) ? FontWeight.w600 : FontWeight.normal,
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
                  time,
                  style: TextStyle(
                    color: subtitleColor, 
                    fontSize: 12,
                    fontWeight: (!read && unreadCount > 0) ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 6),
                if (unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: highlightColor,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unreadCount.toString(),
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
  }
}

