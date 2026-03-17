import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'message_info_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String? replyingMessage;

  void showAttachmentMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBgColor = isDark ? const Color(0xff2A2A2A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    showDialog(
      context: context,
      barrierColor: Colors.transparent, // Invisible barrier so it feels like a popup on standard UI
      builder: (context) => Align(
        alignment: Alignment.bottomRight,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 200,
            margin: const EdgeInsets.only(right: 16, bottom: 84), // Placed right above the text input
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: sheetBgColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPopupOption(context, Icons.camera_alt_outlined, "Camera", textColor, () async {
                  Navigator.pop(context);
                  final ImagePicker picker = ImagePicker();
                  await picker.pickImage(source: ImageSource.camera);
                }),
                _buildPopupOption(context, Icons.photo_outlined, "Gallery", textColor, () async {
                  Navigator.pop(context);
                  final ImagePicker picker = ImagePicker();
                  await picker.pickImage(source: ImageSource.gallery);
                }),
                _buildPopupOption(context, Icons.headset_mic_outlined, "Audio", textColor, () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Audio recorder opened')));
                }),
                _buildPopupOption(context, Icons.location_on_outlined, "Location", textColor, () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location picker opened')));
                }),
                _buildPopupOption(context, Icons.insert_drive_file_outlined, "Document", textColor, () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document picker opened')));
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopupOption(BuildContext context, IconData icon, String label, Color textColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: textColor, size: 24),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF202020);
    final inputBgColor = isDark ? Colors.grey.shade900 : const Color(0xfff1f2f6);
    final buttonColor = const Color(0xFF0A7CFF); // Vibrant Blue
    final buttonIconColor = Colors.white;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: bgColor,

      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),

        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MessageInfoScreen(),
              ),
            );
          },

          child: Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundImage: AssetImage("assets/test1.jpg"),
              ),

              const SizedBox(width: 10),

              Text(
                "Emma Brown",
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),

        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: textColor),
            color: isDark ? const Color(0xff2A2A2A) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // More rounded
            surfaceTintColor: Colors.transparent,
            offset: const Offset(0, 40),
            onSelected: (value) {
              // Action logic goes here
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'Search',
                child: Row(
                  children: [
                    Icon(Icons.search, color: textColor, size: 22),
                    const SizedBox(width: 12),
                    Text('Search in chat', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'Clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: textColor, size: 22),
                    const SizedBox(width: 12),
                    Text('Clear chat', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'Restrict',
                child: Row(
                  children: [
                    Icon(Icons.block, color: textColor, size: 22),
                    const SizedBox(width: 12),
                    Text('Restrict', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'Report',
                child: Row(
                  children: [
                    Icon(Icons.report_outlined, color: Colors.red, size: 22),
                    SizedBox(width: 12),
                    Text('Report', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          /// CHAT MESSAGES
          Expanded(
            child: ListView(
              reverse: true,
              padding: const EdgeInsets.all(16),
              children: [
                MessageBubble(
                  text: "Yes sure!",
                  isMe: true,
                  onReply: () => setState(() => replyingMessage = "Yes sure!"),
                ),
                MessageBubble(
                  text: "Are we meeting tomorrow?",
                  isMe: false,
                  onReply: () => setState(() => replyingMessage = "Are we meeting tomorrow?"),
                ),
                MessageBubble(
                  text: "I'm good! You?",
                  isMe: true,
                  onReply: () => setState(() => replyingMessage = "I'm good! You?"),
                ),
                MessageBubble(
                  text: "Hi! How are you?",
                  isMe: false,
                  onReply: () => setState(() => replyingMessage = "Hi! How are you?"),
                ),
              ],
            ),
          ),

          /// MESSAGE INPUT
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: bgColor,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                   // Unique Pill-shaped container for EVERYTHING
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xff1C1C1E) : const Color(0xfff1f2f6),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                          width: 0.5,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          /// REPLYING PREVIEW BOX (WhatsApp Style)
                          if (replyingMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6, left: 6, right: 6, top: 2),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  color: isDark ? const Color(0xff2A2A2A) : Colors.white,
                                  child: IntrinsicHeight(
                                    child: Row(
                                      children: [
                                        // Left Colored Bar (WhatsApp style)
                                        Container(width: 4, color: buttonColor),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "Emma Brown", // Matched with header for visual consistency
                                                  style: TextStyle(
                                                    color: buttonColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  replyingMessage!,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        // Close icon
                                        InkWell(
                                          onTap: () => setState(() => replyingMessage = null),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Icon(Icons.close, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, size: 18),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          /// INPUT ROW
                          Row(
                            children: [
                          /// KNOCKPOST UNIQUE '+' BUTTON
                          GestureDetector(
                            onTap: () => showAttachmentMenu(context),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey.shade800 : Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  if (!isDark)
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                ],
                              ),
                              child: Icon(Icons.add, color: textColor, size: 22),
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          /// TEXT FIELD
                          Expanded(
                            child: TextField(
                              style: TextStyle(color: textColor, fontSize: 15),
                              decoration: InputDecoration(
                                hintText: "Message...",
                                hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          
                          /// ACTION ICONS
                          GestureDetector(
                            onTap: () async {
                              final ImagePicker picker = ImagePicker();
                              await picker.pickImage(source: ImageSource.camera);
                            },
                            child: Icon(Icons.camera_alt_outlined, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, size: 22),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone activated')));
                            },
                            child: Icon(Icons.mic_none, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, size: 22),
                          ),
                          const SizedBox(width: 12),
                          
                              /// SEND BUTTON
                              Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0A7CFF), // Vibrant Blue Send Button
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatefulWidget {
  final String text;
  final bool isMe;
  final VoidCallback onReply;

  const MessageBubble({
    super.key, 
    required this.text, 
    required this.isMe, 
    required this.onReply,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragExtent = 0;
  final double _replyThreshold = 50.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragExtent += details.primaryDelta!;
      if (_dragExtent < 0) _dragExtent = 0; // Only swipe right
      if (_dragExtent > _replyThreshold * 1.5) { // Cap max drag
        _dragExtent = _replyThreshold * 1.5;
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragExtent >= _replyThreshold) {
      widget.onReply();
    }
    _controller.forward(from: 0.0).then((_) {
      setState(() {
        _dragExtent = 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Changing "isMe" (sent messages) to be grey as requested
    final myBubbleColor = isDark ? Colors.grey.shade800 : const Color(0xFFE5E5EA); // Standard chat grey
    final myTextColor = isDark ? Colors.white : Colors.black;
    
    // Changing "other" (received messages) to be vibrant blue
    final otherBubbleColor = const Color(0xFF0A7CFF); // Vibrant Blue
    final otherTextColor = Colors.white;

    // Calculate current translation based on drag and animation
    double dx = _dragExtent * (1.0 - _controller.value);

    return Stack(
      children: [
        // The Reply Icon background that reveals when dragged
        Positioned(
          left: 16,
          top: 0,
          bottom: 0,
          child: Opacity(
            opacity: (_dragExtent / _replyThreshold).clamp(0.0, 1.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.reply, color: isDark ? Colors.white : Colors.black54, size: 20),
                ),
              ],
            ),
          ),
        ),
        
        // The Swipeable Message Bubble
        GestureDetector(
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          onLongPress: () {
            _showMessageOptionsBottomSheet(context, widget.isMe, widget.onReply);
          },
          child: Transform.translate(
            offset: Offset(dx, 0),
            child: Align(
              alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: widget.isMe ? myBubbleColor : otherBubbleColor,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  widget.text,
                  style: TextStyle(
                    color: widget.isMe ? myTextColor : otherTextColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showMessageOptionsBottomSheet(BuildContext context, bool isMe, VoidCallback onReply) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.reply, color: textColor),
                title: Text('Reply', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  onReply();
                },
              ),
              ListTile(
                leading: Icon(Icons.forward, color: textColor),
                title: Text('Forward', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.copy, color: textColor),
                title: Text('Copy', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message copied')));
                },
              ),
              if (isMe)
                ListTile(
                  leading: Icon(Icons.edit, color: textColor),
                  title: Text('Edit', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

