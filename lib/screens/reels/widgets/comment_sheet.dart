import 'package:flutter/material.dart';

class CommentSheet extends StatefulWidget {
  const CommentSheet({super.key});

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<Map<String, String>> _comments = [];

  final List<Map<String, String>> _demoComments = [
    {
      "username": "creative_dev",
      "text": "This is amazing! 🔥",
      "time": "2m",
    },
    {
      "username": "flutter_fan",
      "text": "Love the vibes on this one 💯",
      "time": "5m",
    },
    {
      "username": "tech_enthusiast",
      "text": "KnockPost is going to be huge!",
      "time": "12m",
    },
  ];

  @override
  void initState() {
    super.initState();
    _comments.addAll(_demoComments);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _postComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _comments.insert(0, {
        "username": "you",
        "text": text,
        "time": "now",
      });
    });

    _commentController.clear();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),

          /// Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          const SizedBox(height: 12),

          /// Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 40),
                Text(
                  "Comments",
                  style: TextStyle(
                    color: Colors.grey.shade100,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.grey.shade400,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Divider(color: Colors.grey.shade800, height: 1),

          /// Comments List
          Expanded(
            child: _comments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mode_comment_outlined,
                          color: Colors.grey.shade700,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "No comments yet",
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Be the first to comment",
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _comments.length,
                    itemBuilder: (context, index) {
                      final comment = _comments[index];
                      final isOwn = comment["username"] == "you";
                      return _CommentTile(
                        username: comment["username"]!,
                        text: comment["text"]!,
                        time: comment["time"]!,
                        isOwn: isOwn,
                      );
                    },
                  ),
          ),

          /// Input Field
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 8,
              top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 10,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              border: Border(
                top: BorderSide(color: Colors.grey.shade800, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                /// Avatar
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue.shade700,
                  child: const Text(
                    "Y",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                /// Text Field
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _focusNode,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: "Add a comment...",
                      hintStyle: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF2A2A2A),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _postComment(),
                  ),
                ),

                const SizedBox(width: 6),

                /// Post Button
                GestureDetector(
                  onTap: _postComment,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual comment tile
class _CommentTile extends StatelessWidget {
  final String username;
  final String text;
  final String time;
  final bool isOwn;

  const _CommentTile({
    required this.username,
    required this.text,
    required this.time,
    required this.isOwn,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Avatar
          CircleAvatar(
            radius: 16,
            backgroundColor: isOwn
                ? Colors.blue.shade700
                : Colors.primaries[username.length % Colors.primaries.length]
                    .shade700,
            child: Text(
              username[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),

          const SizedBox(width: 12),

          /// Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isOwn ? "You" : "@$username",
                      style: TextStyle(
                        color: isOwn
                            ? Colors.blue.shade300
                            : Colors.grey.shade300,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      time,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: TextStyle(
                    color: Colors.grey.shade200,
                    fontSize: 13.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),

          /// Like comment
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(
              Icons.favorite_border,
              color: Colors.grey.shade700,
              size: 14,
            ),
          ),
        ],
      ),
    );
  }
}
