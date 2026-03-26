import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../utils/haptic_helper.dart';
import 'message_info_screen.dart';
import 'media_preview_screen.dart';

// ─────────────────────────────────────────────
// Data Model
// ─────────────────────────────────────────────

class _ChatMessage {
  final String id;
  final String text;
  final bool isMe;
  final String? replyToId;
  final Uint8List? imageBytes;
  final DateTime timestamp;
  bool seen;

  _ChatMessage({
    required this.id,
    required this.text,
    required this.isMe,
    this.replyToId,
    this.imageBytes,
    DateTime? timestamp,
    this.seen = false,
  }) : timestamp = timestamp ?? DateTime.now();

  _ChatMessage copyWith({String? text}) {
    return _ChatMessage(
      id: id,
      text: text ?? this.text,
      isMe: isMe,
      replyToId: replyToId,
      imageBytes: imageBytes,
      timestamp: timestamp,
      seen: seen,
    );
  }
}

// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  final String userName;
  final String userAvatar;
  final String userUsername;

  const ChatScreen({
    super.key,
    required this.userName,
    required this.userAvatar,
    required this.userUsername,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final AudioRecorder _audioRecorder = AudioRecorder();

  String? _replyingToId;
  String? _editingMessageId;
  bool _hasText = false;
  bool _isRecording = false;
  String? _recordingPath;

  // Search state
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  late List<_ChatMessage> _messages;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _messages = [
      _ChatMessage(id: '1', text: "Yes sure!", isMe: true, seen: true,
          timestamp: now.subtract(const Duration(minutes: 5))),
      _ChatMessage(id: '2', text: "Are we meeting tomorrow?", isMe: false,
          timestamp: now.subtract(const Duration(minutes: 12))),
      _ChatMessage(id: '3', text: "I'm good! You?", isMe: true, seen: true,
          timestamp: now.subtract(const Duration(minutes: 18))),
      _ChatMessage(id: '4', text: "Hi! How are you?", isMe: false,
          timestamp: now.subtract(const Duration(minutes: 24))),
    ];

    _messageController.addListener(() {
      final hasText = _messageController.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _searchController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  // ─── Helpers ────────────────────────────────

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  List<_ChatMessage> get _filteredMessages {
    if (_searchQuery.isEmpty) return _messages;
    return _messages.where((m) =>
        m.text.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  // ─── Message Actions ────────────────────────

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    KnockHaptics.impact();
    setState(() {
      if (_editingMessageId != null) {
        final index = _messages.indexWhere((m) => m.id == _editingMessageId);
        if (index != -1) _messages[index] = _messages[index].copyWith(text: text);
        _editingMessageId = null;
      } else {
        _messages.insert(0, _ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: text,
          isMe: true,
          replyToId: _replyingToId,
        ));
      }
      _messageController.clear();
      _replyingToId = null;
    });
    _scrollController.animateTo(0.0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _sendImageMessage(Uint8List bytes, String caption) {
    KnockHaptics.impact();
    setState(() {
      _messages.insert(0, _ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: caption,
        isMe: true,
        imageBytes: bytes,
      ));
    });
  }

  void _setReply(String messageId) {
    setState(() { _replyingToId = messageId; _editingMessageId = null; });
    _focusNode.requestFocus();
  }

  void _cancelReply() => setState(() => _replyingToId = null);

  void _startEditing(String messageId, String currentText) {
    setState(() { _editingMessageId = messageId; _replyingToId = null; });
    _messageController.text = currentText;
    _focusNode.requestFocus();
  }

  void _cancelEdit() {
    setState(() => _editingMessageId = null);
    _messageController.clear();
    _focusNode.unfocus();
  }

  // ─── Audio ──────────────────────────────────

  Future<void> _startRecording() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) return;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _audioRecorder.start(const RecordConfig(), path: path);
    setState(() { _isRecording = true; _recordingPath = path; });
    KnockHaptics.impact();
  }

  Future<void> _stopRecording() async {
    await _audioRecorder.stop();
    setState(() => _isRecording = false);
    KnockHaptics.selection();
    if (_recordingPath != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio recorded (ready to send with backend)')));
    }
  }

  // ─── Media ──────────────────────────────────

  Future<void> _openMediaPicker(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null || !mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => MediaPreviewScreen(
        file: File(pickedFile.path),
        onSend: _sendImageMessage,
      ),
    ));
  }

  // ─── Three-Dot Menu ─────────────────────────

  void _showMoreOptions() {
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white : Colors.black;
    final bgColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xff2A2A2A) : Colors.white;

    showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 60, 8, 0),
      color: bgColor,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        PopupMenuItem(
          value: 'profile',
          child: Row(children: [
            Icon(Icons.person_outline_rounded, size: 20, color: textColor),
            const SizedBox(width: 12),
            Text('Profile', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
          ]),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'search',
          child: Row(children: [
            Icon(Icons.search_rounded, size: 20, color: textColor),
            const SizedBox(width: 12),
            Text('Search', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
          ]),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'block',
          child: Row(children: [
            Icon(Icons.block_rounded, size: 20, color: Colors.red),
            SizedBox(width: 12),
            Text('Block', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
          ]),
        ),
        const PopupMenuItem(
          value: 'report',
          child: Row(children: [
            Icon(Icons.flag_outlined, size: 20, color: Colors.red),
            SizedBox(width: 12),
            Text('Report', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
          ]),
        ),
      ],
    ).then((value) {
      if (value == null || !mounted) return;
      KnockHaptics.selection();
      switch (value) {
        case 'profile':
          Navigator.push(context, MaterialPageRoute(
              builder: (_) => MessageInfoScreen(
                userName: widget.userName,
                userAvatar: widget.userAvatar,
                userUsername: widget.userUsername,
              )));
          break;
        case 'search':
          setState(() { _isSearching = true; });
          break;
        case 'block':
          _showBlockDialog();
          break;
        case 'report':
          _showReportDialog();
          break;
      }
    });
  }

  void _showBlockDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Block ${widget.userName}?'),
      content: const Text('They won\'t be able to message you anymore.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
          child: const Text('Block', style: TextStyle(color: Colors.red)),
        ),
      ],
    ));
  }

  void _showReportDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Report ${widget.userName}?'),
      content: const Text('Your report will be reviewed. Thank you for keeping Knockpost safe.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Report', style: TextStyle(color: Colors.red)),
        ),
      ],
    ));
  }

  // ─── Message Context Menu ────────────────────

  void _showMessageOptions(Offset position, _ChatMessage message) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff2A2A2A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      color: bgColor,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        PopupMenuItem(value: 'reply', child: Row(children: [
          Icon(Icons.reply_rounded, size: 20, color: textColor),
          const SizedBox(width: 12),
          Text('Reply', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
        ])),
        PopupMenuItem(value: 'copy', child: Row(children: [
          Icon(Icons.copy_rounded, size: 20, color: textColor),
          const SizedBox(width: 12),
          Text('Copy', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
        ])),
        if (message.isMe)
          PopupMenuItem(value: 'edit', child: Row(children: [
            Icon(Icons.edit_rounded, size: 20, color: textColor),
            const SizedBox(width: 12),
            Text('Edit', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
          ])),
        const PopupMenuItem(value: 'delete', child: Row(children: [
          Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
          SizedBox(width: 12),
          Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
        ])),
      ],
    );

    if (value == null || !mounted) return;
    KnockHaptics.selection();
    switch (value) {
      case 'reply': _setReply(message.id); break;
      case 'copy':
        Clipboard.setData(ClipboardData(text: message.text));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!')));
        break;
      case 'edit': _startEditing(message.id, message.text); break;
      case 'delete':
        KnockHaptics.heavy();
        setState(() {
          _messages.removeWhere((m) => m.id == message.id);
          if (_replyingToId == message.id) _cancelReply();
          if (_editingMessageId == message.id) _cancelEdit();
        });
        break;
    }
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtleColor = isDark ? Colors.grey.shade500 : Colors.grey.shade500;

    const myBubbleColor = Color(0xFF007AFF);
    final otherBubbleColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE9E9EB);

    // Fix: After returning from ProImageEditor (which forces dark SystemUiOverlayStyle),
    // AnnotatedRegion ensures the status bar + nav bar icons are correctly restored.
    final overlayStyle = isDark
        ? SystemUiOverlayStyle.light.copyWith(
            systemNavigationBarColor: Colors.black,
            systemNavigationBarIconBrightness: Brightness.light,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            systemNavigationBarColor: Colors.white,
            systemNavigationBarIconBrightness: Brightness.dark,
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: bgColor,
        appBar: _isSearching
            ? _buildSearchBar(isDark, textColor)
            : _buildAppBar(isDark, textColor),
        body: Column(
          children: [
            // ── Message List ──
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: _filteredMessages.length,
                itemBuilder: (context, index) {
                  final msg = _filteredMessages[index];
                  _ChatMessage? parentMsg;
                  if (msg.replyToId != null) {
                    try { parentMsg = _messages.firstWhere((m) => m.id == msg.replyToId); }
                    catch (_) {}
                  }
                  return _buildMessageRow(
                    msg, parentMsg,
                    isDark, myBubbleColor, otherBubbleColor,
                    textColor, subtleColor,
                  );
                },
              ),
            ),

            // ── Docks (only show when actively replying/editing) ──
            if (_replyingToId != null)
              _buildDock(isDark, subtleColor, Icons.reply, 'Replying to message...', _cancelReply),
            if (_editingMessageId != null)
              _buildDock(isDark, subtleColor, Icons.edit, 'Editing message', _cancelEdit),

            // ── Input ──
            _buildInputBar(isDark, textColor, subtleColor, myBubbleColor),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // AppBars
  // ─────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(bool isDark, Color textColor) {
    final bg = isDark ? Colors.black : Colors.white;
    final dividerColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    return AppBar(
      titleSpacing: 0,
      backgroundColor: bg,
      surfaceTintColor: bg,
      elevation: 0,
      shadowColor: Colors.transparent,
      iconTheme: IconThemeData(color: textColor),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: dividerColor),
      ),
      title: GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => MessageInfoScreen(
              userName: widget.userName,
              userAvatar: widget.userAvatar,
              userUsername: widget.userUsername,
            ))),
        child: Row(children: [
          CircleAvatar(radius: 18, backgroundImage: AssetImage(widget.userAvatar)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.userName, style: TextStyle(
              color: textColor, fontWeight: FontWeight.w700, fontSize: 16)),
            const Text("Active now", style: TextStyle(
              color: Colors.green, fontSize: 12, fontWeight: FontWeight.w500)),
          ]),
        ]),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.more_vert_rounded, color: textColor),
          onPressed: _showMoreOptions,
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSearchBar(bool isDark, Color textColor) {
    final bg = isDark ? Colors.black : Colors.white;
    return AppBar(
      backgroundColor: bg,
      surfaceTintColor: bg,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: textColor),
        onPressed: () => setState(() { _isSearching = false; _searchQuery = ''; _searchController.clear(); }),
      ),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          hintText: 'Search messages...',
          hintStyle: TextStyle(color: Colors.grey.shade500),
          border: InputBorder.none,
        ),
        onChanged: (val) => setState(() => _searchQuery = val),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Message Row (with avatars, timestamp, ticks)
  // ─────────────────────────────────────────────

  Widget _buildMessageRow(
    _ChatMessage msg,
    _ChatMessage? parentMsg,
    bool isDark,
    Color myBubbleColor,
    Color otherBubbleColor,
    Color textColor,
    Color subtleColor,
  ) {
    final isMe = msg.isMe;

    Widget bubble = _buildBubble(
      msg, parentMsg, isDark,
      myBubbleColor, otherBubbleColor,
      textColor, subtleColor,
    );

    // Avatar
    final avatar = CircleAvatar(
      radius: 14,
      backgroundImage: AssetImage(isMe ? "assets/test2.jpg" : "assets/test1.jpg"),
    );

    return _FastLongPressTile(
      onFastLongPress: (pos) {
        KnockHaptics.impact();
        FocusManager.instance.primaryFocus?.unfocus();
        _showMessageOptions(pos, msg);
      },
      onSwipeReply: () => _setReply(msg.id),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: isMe
              ? [
                  Flexible(child: bubble),
                  const SizedBox(width: 6),
                  avatar,
                ]
              : [
                  avatar,
                  const SizedBox(width: 6),
                  Flexible(child: bubble),
                ],
        ),
      ),
    );
  }

  Widget _buildBubble(
    _ChatMessage msg,
    _ChatMessage? parentMsg,
    bool isDark,
    Color myBubbleColor,
    Color otherBubbleColor,
    Color textColor,
    Color subtleColor,
  ) {
    final isMe = msg.isMe;

    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // Reply indicator
        if (parentMsg != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.subdirectory_arrow_right_rounded, size: 11, color: subtleColor),
                const SizedBox(width: 3),
                Text(
                  isMe ? 'You replied: "${_truncate(parentMsg.text)}"' : 'Replied: "${_truncate(parentMsg.text)}"',
                  style: TextStyle(fontSize: 11.5, color: subtleColor, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),

        // Bubble
        msg.imageBytes != null
            ? Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.memory(msg.imageBytes!,
                        width: MediaQuery.of(context).size.width * 0.62, fit: BoxFit.cover),
                  ),
                  if (msg.text.isNotEmpty)
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.62,
                      ),
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        msg.text,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                ],
              )
            : ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isMe ? myBubbleColor : otherBubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 20),
                    ),
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black),
                      fontSize: 15.5,
                    ),
                  ),
                ),
              ),

        // Timestamp + Tick
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_timeAgo(msg.timestamp),
                style: TextStyle(fontSize: 10.5, color: subtleColor)),
            if (isMe) ...[
              const SizedBox(width: 3),
              Icon(
                msg.seen ? Icons.done_all_rounded : Icons.done_rounded,
                size: 13,
                color: msg.seen ? const Color(0xFF007AFF) : subtleColor,
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _truncate(String text, {int max = 28}) =>
      text.length <= max ? text : '${text.substring(0, max)}...';

  // ─────────────────────────────────────────────
  // Dock (reply/edit)
  // ─────────────────────────────────────────────

  Widget _buildDock(bool isDark, Color subtleColor, IconData icon, String label, VoidCallback onCancel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
      child: Row(
        children: [
          Icon(icon, size: 15, color: subtleColor),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(fontSize: 12.5, color: subtleColor, fontStyle: FontStyle.italic))),
          GestureDetector(onTap: onCancel, child: Icon(Icons.close, size: 15, color: subtleColor)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Premium Input Bar
  // ─────────────────────────────────────────────

  Widget _buildInputBar(bool isDark, Color textColor, Color subtleColor, Color myBubbleColor) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final keyboardUp = MediaQuery.of(context).viewInsets.bottom > 0;

    final barBg = isDark ? const Color(0xFF141414) : Colors.white;
    final pillBg = isDark ? const Color(0xFF2A2A2E) : const Color(0xFFF0F0F5);
    final iconColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final divColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    return Container(
      decoration: BoxDecoration(
        color: barBg,
        border: Border(top: BorderSide(color: divColor, width: 0.8)),
      ),
      padding: EdgeInsets.fromLTRB(10, 8, 10, keyboardUp ? 8 : safeBottom + 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Pill: [+ | TextField | Mic | Gallery] ──
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 46, maxHeight: 130),
              decoration: BoxDecoration(
                color: pillBg,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // '+' attachment button INSIDE pill (left edge)
                  GestureDetector(
                    onTap: () { KnockHaptics.tap(); _showAttachmentSheet(); },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10, right: 2, bottom: 10, top: 10),
                      child: Icon(Icons.add_circle_outline_rounded,
                          color: isDark ? Colors.white : Colors.black, size: 28),
                    ),
                  ),

                  // Text Field
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      maxLines: null,
                      textInputAction: TextInputAction.newline,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15.5,
                        height: 1.35,
                      ),
                      decoration: InputDecoration(
                        hintText: _isRecording ? '🎙 Recording...' : 'Message...',
                        hintStyle: TextStyle(
                          color: _isRecording ? Colors.red.shade300 : iconColor,
                          fontSize: 15.5,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.fromLTRB(10, 13, 4, 13),
                      ),
                    ),
                  ),

                  // Mic (hold to record) — inside pill right side
                  GestureDetector(
                    onLongPressStart: (_) => _startRecording(),
                    onLongPressEnd: (_) => _stopRecording(),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10, top: 10),
                      child: Icon(
                        _isRecording ? Icons.stop_circle_outlined : Icons.mic_none_rounded,
                        color: _isRecording ? Colors.red : iconColor,
                        size: 26,
                      ),
                    ),
                  ),

                  // Gallery / Media picker — inside pill right side
                  GestureDetector(
                    onTap: () => _openMediaPicker(ImageSource.gallery),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8, right: 12, bottom: 10, top: 10),
                      child: Icon(Icons.photo_outlined,
                          color: iconColor, size: 26),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // ── Send Button (OUTSIDE pill, always visible, blue) ──
          GestureDetector(
            onTap: _hasText ? _sendMessage : null,
            child: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: myBubbleColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }


  // ─────────────────────────────────────────────
  // Attachment Sheet
  // ─────────────────────────────────────────────

  void _showAttachmentSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _AttachmentOption(icon: Icons.camera_alt_rounded, label: 'Camera', color: Colors.purple,
                    onTap: () { Navigator.pop(ctx); _openMediaPicker(ImageSource.camera); }),
                _AttachmentOption(icon: Icons.photo_library_rounded, label: 'Gallery', color: Colors.blue,
                    onTap: () { Navigator.pop(ctx); _openMediaPicker(ImageSource.gallery); }),
                _AttachmentOption(icon: Icons.videocam_rounded, label: 'Video', color: Colors.red,
                    onTap: () { Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Video picker coming soon'))); }),
                _AttachmentOption(icon: Icons.location_on_rounded, label: 'Location', color: Colors.green,
                    onTap: () { Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Location sharing coming soon'))); }),
              ]),
              const SizedBox(height: 8),
            ]),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Reusable Widgets
// ─────────────────────────────────────────────

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.icon, required this.label,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { KnockHaptics.selection(); onTap(); },
      child: Column(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// Fast Long-Press Gesture Detector
// ─────────────────────────────────────────────

class _FastLongPressTile extends StatefulWidget {
  final Widget child;
  final void Function(Offset) onFastLongPress;
  final VoidCallback onSwipeReply;

  const _FastLongPressTile({
    required this.child,
    required this.onFastLongPress,
    required this.onSwipeReply,
  });

  @override
  State<_FastLongPressTile> createState() => _FastLongPressTileState();
}

class _FastLongPressTileState extends State<_FastLongPressTile> {
  Timer? _timer;

  void _cancel() { _timer?.cancel(); _timer = null; }

  @override
  void dispose() { _cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) {
        _cancel();
        _timer = Timer(const Duration(milliseconds: 250),
            () => widget.onFastLongPress(d.globalPosition));
      },
      onTapUp: (_) => _cancel(),
      onTapCancel: () => _cancel(),
      onHorizontalDragEnd: (d) {
        _cancel();
        // Raised threshold to 600 to avoid accidental triggers while scrolling.
        if ((d.primaryVelocity ?? 0) > 600) widget.onSwipeReply();
      },
      child: widget.child,
    );
  }
}
