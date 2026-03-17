import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'new_message_screen.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final searchBgColor = isDark ? Colors.grey.shade900 : Colors.grey.shade100;

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
        actions: [
          const _NewMessageIcon(),
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
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  icon: Icon(Icons.search, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  hintText: "Search",
                  hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          /// MESSAGE LIST
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              children: [
                MessageTile(
                  name: "John Doe",
                  message: "Just finished work, what's up?",
                  time: "2m",
                  unreadCount: 2,
                ),

                MessageTile(
                  name: "Jane Doe",
                  message: "That sounds awesome! 😂",
                  time: "10m",
                  unreadCount: 1,
                ),

                MessageTile(
                  name: "Alex Smith",
                  message: "Are we still on for tomorrow?",
                  time: "30m",
                  read: true,
                ),

                MessageTile(
                  name: "Emily Brown",
                  message: "Sure, I'll send it over to you!",
                  time: "45m",
                  read: true,
                ),

                MessageTile(
                  name: "Daniel Lee",
                  message: "Can you call me when you're free?",
                  time: "1h",
                  read: true,
                ),

                MessageTile(
                  name: "Sarah Wilson",
                  message: "Haha that's so funny!",
                  time: "2h",
                  read: true,
                ),
              ],
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

  const MessageTile({
    super.key,
    required this.name,
    required this.message,
    required this.time,
    this.unreadCount = 0,
    this.read = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final highlightColor = const Color(0xFF0A7CFF); // Vibrant Blue

    return InkWell(
      onTap: () {
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
                  Text(
                    name,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: (!read && unreadCount > 0) ? FontWeight.bold : FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    message, 
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: (!read && unreadCount > 0) ? textColor : subtitleColor,
                      fontWeight: (!read && unreadCount > 0) ? FontWeight.w600 : FontWeight.normal,
                    ),
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
                    decoration: BoxDecoration(
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
