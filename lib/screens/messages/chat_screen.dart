import 'dart:async';
import 'package:knockpost/widgets/knockpost_refresh.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/chat_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/database_service.dart';
import '../../services/current_user_service.dart';
import '../../services/image_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/storage_service.dart';
import '../../services/connectivity_service.dart';
import '../../utils/haptic_helper.dart';
import 'widgets/full_screen_image_viewer.dart';
import '../../widgets/system_nav_bar_fill.dart';
import 'message_info_screen.dart';
import '../../widgets/knockpost_avatar.dart';
import 'media_preview_screen.dart';
import 'widgets/post_message_preview.dart';
import 'widgets/audio_message_bubble.dart';

// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  final UserModel otherUser;

  const ChatScreen({
    super.key,
    required this.otherUser,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _LocalImageMessage {
  final String id;
  final Uint8List bytes;
  final String caption;
  _LocalImageMessage({required this.id, required this.bytes, required this.caption});
}

class _ChatListItem {
  final _LocalImageMessage? localImage;
  final ChatMessage? firestore;
  final DateTime? dateSeparator;
  _ChatListItem._({this.localImage, this.firestore, this.dateSeparator});
  factory _ChatListItem.localImage(_LocalImageMessage m) => _ChatListItem._(localImage: m);
  factory _ChatListItem.firestore(ChatMessage m) => _ChatListItem._(firestore: m);
  factory _ChatListItem.dateSeparator(DateTime d) => _ChatListItem._(dateSeparator: d);
  bool get isLocalImage => localImage != null;
  bool get isDateSeparator => dateSeparator != null;
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
  bool _isAttachmentDrawerOpen = false;

  // Search state
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Real-time messages from Firestore
  static final RegExp _postUrlRegex = RegExp(r'https:\/\/knockpost\.app\/post\/([a-zA-Z0-9_-]+)');
  List<ChatMessage> _firestoreMessages = [];
  Map<String, ChatMessage> _messageMap = {};
  List<ChatMessage> _filteredMessages = [];
  List<_ChatListItem> _allItems = [];
  StreamSubscription<List<ChatMessage>>? _messageSub;
  Timer? _loadingTimeout;
  bool _isLoadingMessages = true;

  bool _isOffline = false;
  StreamSubscription<bool>? _connectivitySub;
  late final Stream<DocumentSnapshot> _otherUserStream;

  // Local-only list for optimistic image sends (not yet uploaded)
  final List<_LocalImageMessage> _localImages = [];

  late final String _chatId;
  late final String _myUid;

  @override
  void initState() {
    super.initState();
    _myUid = AuthService.instance.currentUser?.uid ?? '';
    _chatId = ChatService.instance.getChatId(_myUid, widget.otherUser.id);

    _messageController.addListener(() {
      final hasText = _messageController.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });

    // Auto-scroll to bottom when keyboard opens (matches comment section behavior)
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 250), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }
    });

    _otherUserStream = FirebaseFirestore.instance.collection('users').doc(widget.otherUser.id).snapshots();

    _connectivitySub = ConnectivityService.instance.onConnectivityChanged.listen((isOnline) {
      if (mounted) setState(() => _isOffline = !isOnline);
    });
    _isOffline = !ConnectivityService.instance.isOnline;

    // Safety timeout: if the stream never emits within 8s, force loading off.
    // This guards against Firestore cold-start delays, empty chats, or network issues.
    _loadingTimeout = Timer(const Duration(seconds: 8), () {
      if (mounted && _isLoadingMessages) {
        setState(() => _isLoadingMessages = false);
      }
    });

    _messageSub = ChatService.instance.streamMessages(_chatId).listen((messages) {
      if (!mounted) return;
      _loadingTimeout?.cancel();
      setState(() {
        _firestoreMessages = messages;
        _messageMap = { for (var m in messages) m.id: m };
        _applySearch();
        _isLoadingMessages = false;
      });
      final unseenIds = messages
          .where((m) => m.senderId != _myUid && !m.seen)
          .map((m) => m.id)
          .toList();
      ChatService.instance.markChatAsRead(_chatId, unseenMessageIds: unseenIds);
    }, onError: (e) {
      if (!mounted) return;
      _loadingTimeout?.cancel();
      setState(() => _isLoadingMessages = false);
    });
  }

  void _applySearch() {
    final filtered = _searchQuery.isEmpty 
        ? _firestoreMessages 
        : _firestoreMessages.where((m) => m.text.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    
    setState(() {
      _filteredMessages = filtered;
      _updateAllItems();
    });
  }

  void _updateAllItems() {
    final filtered = _filteredMessages;
    final newItems = <_ChatListItem>[];
    
    for (var img in _localImages) {
      newItems.add(_ChatListItem.localImage(img));
    }
    
    for (int i = 0; i < filtered.length; i++) {
      final msg = filtered[i];
      newItems.add(_ChatListItem.firestore(msg));
      
      bool addSeparator = false;
      if (i == filtered.length - 1) {
        addSeparator = true;
      } else {
        final nextMsg = filtered[i + 1];
        if (msg.timestamp.year != nextMsg.timestamp.year ||
            msg.timestamp.month != nextMsg.timestamp.month ||
            msg.timestamp.day != nextMsg.timestamp.day) {
          addSeparator = true;
        }
      }
      
      if (addSeparator) {
        newItems.add(_ChatListItem.dateSeparator(msg.timestamp));
      }
    }
    
    _allItems = newItems;
  }

  @override
  void dispose() {
    _loadingTimeout?.cancel();
    _messageSub?.cancel();
    ChatService.instance.disposeChatStreams(_chatId);
    _connectivitySub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _searchController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  // ─── Helpers ────────────────────────────────


  String _formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return "Offline";
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 1) return "Active just now";
    if (diff.inMinutes < 60) return "Active ${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "Active ${diff.inHours}h ago";
    if (diff.inDays == 1) return "Active yesterday";
    return "Active ${diff.inDays}d ago";
  }

  Widget _buildAvatar(String? url, {required double radius, String? name}) {
    return KnockpostAvatar(
      url: url,
      radius: radius,
      name: name,
    );
  }

  // ─── Message Actions ────────────────────────

  bool _isSending = false;

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;
    _isSending = true;

    KnockHaptics.impact();
    final replyId = _replyingToId;
    setState(() {
      _replyingToId = null;
      _editingMessageId = null;
    });
    _messageController.clear();
    
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0.0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    
    // Optimistic UI
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMsg = ChatMessage(
       id: tempId,
       senderId: _myUid,
       text: text,
       timestamp: DateTime.now(),
       replyToId: replyId,
       status: MessageStatus.sending,
    );
    
    setState(() {
       _firestoreMessages.insert(0, optimisticMsg);
       _messageMap[optimisticMsg.id] = optimisticMsg;
       _applySearch();
    });

    try {
      await ChatService.instance.sendMessageWithRetry(
        otherUid: widget.otherUser.id,
        text: text,
        replyToId: replyId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
        );
      }
    } finally {
      if (mounted) _isSending = false;
    }
  }

  void _sendImageMessage(Uint8List bytes, String caption) async {
    KnockHaptics.impact();
    final localId = DateTime.now().millisecondsSinceEpoch.toString();
    final localMsg = _LocalImageMessage(
            id: localId,
            bytes: bytes,
            caption: caption,
          );
    setState(() {
      _localImages.insert(0, localMsg);
      _updateAllItems();
    });

    try {
      final url = await StorageService.instance.uploadChatImage(
        chatId: _chatId,
        messageId: localId,
        bytes: bytes,
      );

      if (url != null) {
        await ChatService.instance.sendMessageWithRetry(
          otherUid: widget.otherUser.id,
          text: caption,
          imageUrl: url,
        );
      } else {
        throw Exception("Upload returned null");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send image')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _localImages.removeWhere((m) => m.id == localId);
          _updateAllItems();
        });
      }
    }
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
    setState(() => _isRecording = true);
    KnockHaptics.impact();
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);
    KnockHaptics.selection();
    if (path != null) {
      _sendAudioMessage(path);
    }
  }

  void _sendAudioMessage(String path) async {
    final localId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final file = File(path);
    
    // Optimistic UI for audio
    final optimisticMsg = ChatMessage(
      id: localId,
      senderId: _myUid,
      text: '',
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      audioUrl: path, // Use local path for optimistic play
    );
    
    setState(() {
      _firestoreMessages.insert(0, optimisticMsg);
      _messageMap[optimisticMsg.id] = optimisticMsg;
      _applySearch();
    });

    try {
      final url = await StorageService.instance.uploadChatAudio(
        chatId: _chatId,
        messageId: localId,
        file: file,
      );

      if (url != null) {
        await ChatService.instance.sendMessageWithRetry(
          otherUid: widget.otherUser.id,
          text: '',
          audioUrl: url,
        );
      } else {
        throw Exception("Upload returned null");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send audio')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _firestoreMessages.removeWhere((m) => m.id == localId);
          _messageMap.remove(localId);
          _applySearch();
        });
      }
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
            Text('Block', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ]),
        ),
        const PopupMenuItem(
          value: 'report',
          child: Row(children: [
            Icon(Icons.flag_outlined, size: 20, color: Colors.red),
            SizedBox(width: 12),
            Text('Report', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
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
              userId: widget.otherUser.id,
              userName: widget.otherUser.displayName,
              userAvatar: widget.otherUser.avatarAsset ?? '',
              userUsername: widget.otherUser.username,
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
      title: Text('Block ${widget.otherUser.displayName}?'),
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
      title: Text('Report ${widget.otherUser.displayName}?'),
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

  void _showMessageOptions(Offset position, ChatMessage message) async {
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
        if (message.senderId == _myUid)
          PopupMenuItem(value: 'edit', child: Row(children: [
            Icon(Icons.edit_rounded, size: 20, color: textColor),
            const SizedBox(width: 12),
            Text('Edit', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
          ])),
        const PopupMenuItem(value: 'delete', child: Row(children: [
          Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
          SizedBox(width: 12),
          Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
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
        // Delete from Firestore
        ChatMessage? nextLatest;
        final filtered = _firestoreMessages.where((m) => m.id != message.id).toList();
        if (filtered.isNotEmpty) {
          nextLatest = filtered.first;
        }
        ChatService.instance.deleteMessage(_chatId, message.id, fallbackLastMessage: nextLatest, useFallback: true);
        setState(() {
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

    const myBubbleColor = Color(0xFFE9EEF8);
    final otherBubbleColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF1F1F1);

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
      child: Stack(
        children: [
          Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: bgColor,
            appBar: _isSearching
                ? _buildSearchBar(isDark, textColor)
                : _buildAppBar(isDark, textColor),
            body: Column(
              children: [
                // ── Offline Banner ──
                if (_isOffline)
                  Container(
                    width: double.infinity,
                    color: Colors.red.withValues(alpha: 0.8),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: const Text(
                      'Offline - Waiting for network...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                // ── Message List ──
                Expanded(
                    child: _isLoadingMessages
                        ? const Center(child: KnockpostLoadingIndicator())
                        : ListView.builder(
                              controller: _scrollController,
                              reverse: true,
                              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              itemCount: _allItems.length,
                              itemBuilder: (context, index) {
                                final item = _allItems[index];

                                if (item.isDateSeparator) {
                                  return _buildDateSeparator(item.dateSeparator!, isDark);
                                }

                                if (item.isLocalImage) {
                                  final localImg = item.localImage!;
                                  return _buildLocalImageRow(
                                    localImg,
                                    isDark, myBubbleColor,
                                    textColor, subtleColor,
                                  );
                                }

                                final msg = item.firestore!;
                                ChatMessage? parentMsg;
                                if (msg.replyToId != null) {
                                  parentMsg = _messageMap[msg.replyToId];
                                }
                                
                                bool isFirstInGroup = true;
                                if (index < _allItems.length - 1) {
                                  final olderItem = _allItems[index + 1];
                                  if (olderItem.firestore != null && olderItem.firestore!.senderId == msg.senderId) {
                                    isFirstInGroup = false;
                                  }
                                }

                                bool isLastInGroup = true;
                                if (index > 0) {
                                  final newerItem = _allItems[index - 1];
                                  if (newerItem.firestore != null && newerItem.firestore!.senderId == msg.senderId) {
                                    isLastInGroup = false;
                                  }
                                }

                                return KeyedSubtree(
                                  key: ValueKey(msg.id),
                                  child: _buildMessageRow(
                                    msg, parentMsg,
                                    isDark, myBubbleColor, otherBubbleColor,
                                    textColor, subtleColor,
                                    isFirstInGroup, isLastInGroup,
                                  ),
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

                // ── Inline Attachment Drawer ──
                if (_isAttachmentDrawerOpen)
                  _buildInlineAttachmentDrawer(isDark),

                // ── Smooth Keyboard Animation Spacer ──
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  height: MediaQuery.of(context).viewInsets.bottom > 0 
                      ? MediaQuery.of(context).viewInsets.bottom 
                      : MediaQuery.of(context).padding.bottom,
                ),
              ],
            ),
          ),
          SystemNavBarFill(color: bgColor),
        ],
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
              userId: widget.otherUser.id,
              userName: widget.otherUser.displayName,
              userAvatar: widget.otherUser.avatarAsset ?? '',
              userUsername: widget.otherUser.username,
            ))),
        child: Row(children: [
          _buildAvatar(widget.otherUser.avatarAsset, radius: 18, name: widget.otherUser.displayName),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.otherUser.displayName, style: TextStyle(
              color: textColor, fontWeight: FontWeight.w700, fontSize: 16)),
            StreamBuilder<DocumentSnapshot>(
              stream: _otherUserStream,
              builder: (context, snapshot) {
                String statusText = "";
                bool isOnline = false;
                
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  final updatedUser = UserModel.fromMap(data, widget.otherUser.id);
                  isOnline = updatedUser.isOnline;
                  statusText = isOnline ? "Active now" : _formatLastSeen(updatedUser.lastSeen);
                } else {
                  isOnline = widget.otherUser.isOnline;
                  statusText = isOnline ? "Active now" : _formatLastSeen(widget.otherUser.lastSeen);
                }
                
                return Text(statusText, style: TextStyle(
                  color: isOnline ? Colors.green : Colors.grey.shade500, 
                  fontSize: 12, 
                  fontWeight: FontWeight.w500
                ));
              },
            ),
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
  // Date Separator
  // ─────────────────────────────────────────────
  
  Widget _buildDateSeparator(DateTime date, bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(date.year, date.month, date.day);
    
    String text;
    if (msgDate == today) {
      text = "Today";
    } else if (msgDate == yesterday) {
      text = "Yesterday";
    } else {
      text = DateFormat('MMMM d').format(date); // e.g. May 21
    }
    
    return Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(vertical: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Message Row (with avatars, timestamp, ticks)
  // ─────────────────────────────────────────────

  Widget _buildMessageRow(
    ChatMessage msg,
    ChatMessage? parentMsg,
    bool isDark,
    Color myBubbleColor,
    Color otherBubbleColor,
    Color textColor,
    Color subtleColor,
    bool isFirstInGroup,
    bool isLastInGroup,
  ) {
    final isMe = msg.senderId == _myUid;

    Widget bubble = _buildBubble(
      msg, parentMsg, isDark,
      myBubbleColor, otherBubbleColor,
      textColor, subtleColor,
      isFirstInGroup, isLastInGroup,
    );

    // Avatar
    final avatarAsset = isMe
        ? CurrentUserService.instance.currentUser?.avatarAsset ?? ''
        : widget.otherUser.avatarAsset ?? '';
    final avatarName = isMe
        ? CurrentUserService.instance.currentUser?.displayName ?? 'You'
        : widget.otherUser.displayName;
    final avatarUsername = isMe
        ? CurrentUserService.instance.currentUser?.username ?? 'you'
        : widget.otherUser.username;
    // Avatar widget
    final avatar = _buildAvatar(avatarAsset, radius: 14, name: avatarName);

    // Name & Time
    final nameWidget = Text(
      avatarUsername,
      style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 12.5),
    );

    // Header Row (Avatar, Name)
    Widget? headerRow;
    if (isFirstInGroup) {
      headerRow = isMe
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                nameWidget,
                const SizedBox(width: 8),
                avatar, 
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                avatar,
                const SizedBox(width: 8),
                nameWidget,
              ],
            );
    }

    return _FastLongPressTile(
      onFastLongPress: (pos) {
        KnockHaptics.impact();
        FocusManager.instance.primaryFocus?.unfocus();
        _showMessageOptions(pos, msg);
      },
      onSwipeReply: () => _setReply(msg.id),
      child: Padding(
        padding: EdgeInsets.only(bottom: isLastInGroup ? 16 : 2),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (headerRow != null) ...[
              headerRow,
              const SizedBox(height: 3),
            ],
            Row(
              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe) const SizedBox(width: 36), // indent for avatar
                Flexible(child: bubble),
                if (isMe) const SizedBox(width: 36), // indent for avatar
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalImageRow(
    _LocalImageMessage msg,
    bool isDark,
    Color myBubbleColor,
    Color textColor,
    Color subtleColor,
  ) {
    // Local images are always "isMe"
    final avatarAsset = AuthService.instance.currentUser?.photoURL;
    final avatarName = CurrentUserService.instance.currentUser?.displayName ?? 'You';
    final avatar = _buildAvatar(avatarAsset, radius: 14, name: avatarName);

    final nameWidget = Text(
      avatarName,
      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
    );
    final timeStr = DateFormat('h:mm a').format(DateTime.now());
    
    final inlineTimeWidget = Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(timeStr, style: TextStyle(color: subtleColor, fontSize: 10.5)),
          const SizedBox(width: 3),
          Icon(Icons.schedule_rounded, size: 12, color: subtleColor),
        ],
      ),
    );

    Widget headerRow = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        nameWidget,
        const SizedBox(width: 8),
        avatar,
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          headerRow,
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => FullScreenImageViewer(
                                imageProvider: MemoryImage(msg.bytes),
                                heroTag: 'local_img_${msg.id}',
                              ),
                            ));
                          },
                          child: Hero(
                            tag: 'local_img_${msg.id}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.memory(msg.bytes,
                                  width: MediaQuery.of(context).size.width * 0.62, fit: BoxFit.cover),
                            ),
                          ),
                        ),
                        const KnockpostLoadingIndicator(), // Uploading indicator
                      ],
                    ),
                    if (msg.caption.isNotEmpty)
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.62,
                        ),
                        padding: const EdgeInsets.only(top: 6),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: msg.caption),
                              WidgetSpan(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 6.0),
                                  child: inlineTimeWidget,
                                ),
                                alignment: PlaceholderAlignment.bottom,
                              ),
                            ],
                          ),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 14.5,
                          ),
                        ),
                      )
                    else
                      inlineTimeWidget,
                  ],
                ),
              ),
              const SizedBox(width: 36),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(
    ChatMessage msg,
    ChatMessage? parentMsg,
    bool isDark,
    Color myBubbleColor,
    Color otherBubbleColor,
    Color textColor,
    Color subtleColor,
    bool isFirstInGroup,
    bool isLastInGroup,
  ) {
    final isMe = msg.senderId == _myUid;
    
    // Dynamic border radius for grouped messages
    const outerRadius = 20.0;
    const innerRadius = 4.0;
    
    BorderRadius borderRadius;
    if (isMe) {
      borderRadius = BorderRadius.only(
        topLeft: const Radius.circular(outerRadius),
        bottomLeft: const Radius.circular(outerRadius),
        topRight: Radius.circular(isFirstInGroup ? outerRadius : innerRadius),
        bottomRight: Radius.circular(isLastInGroup ? outerRadius : innerRadius),
      );
    } else {
      borderRadius = BorderRadius.only(
        topRight: const Radius.circular(outerRadius),
        bottomRight: const Radius.circular(outerRadius),
        topLeft: Radius.circular(isFirstInGroup ? outerRadius : innerRadius),
        bottomLeft: Radius.circular(isLastInGroup ? outerRadius : innerRadius),
      );
    }

    final myBgColor = isDark ? const Color(0xFF1E2A3A) : myBubbleColor;
    final otherBgColor = otherBubbleColor;
    final bubbleTextColor = isDark ? Colors.white : Colors.black;
    
    final match = _postUrlRegex.firstMatch(msg.text);
    final String? postId = match?.group(1);

    final timeStr = DateFormat('h:mm a').format(msg.timestamp);
    final inlineTimeWidget = Padding(
      padding: const EdgeInsets.only(left: 6.0, top: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            timeStr,
            style: TextStyle(color: subtleColor, fontSize: 10.5),
          ),
          if (isMe) ...[
            const SizedBox(width: 3),
            Icon(
              msg.seen ? Icons.done_all_rounded : Icons.done_rounded,
              size: 12,
              color: msg.seen ? const Color(0xFF007AFF) : subtleColor,
            ),
          ],
        ],
      ),
    );

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
        if (msg.isImage)
          Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => FullScreenImageViewer(
                      imageProvider: CachedNetworkImageProvider(
                        msg.imageUrl!,
                        cacheManager: KnockpostImageCacheManager.instance,
                      ),
                      heroTag: 'chat_img_${msg.id}',
                    ),
                  ));
                },
                child: Hero(
                  tag: 'chat_img_${msg.id}',
                  child: ClipRRect(
                    borderRadius: borderRadius,
                    child: CachedNetworkImage(
                        imageUrl: msg.imageUrl!,
                        cacheManager: KnockpostImageCacheManager.instance,
                        width: MediaQuery.of(context).size.width * 0.62, 
                        fit: BoxFit.cover,
                        memCacheWidth: 250,
                    ),
                  ),
                ),
              ),
              if (msg.text.isNotEmpty)
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.62,
                  ),
                  padding: const EdgeInsets.only(top: 6),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: msg.text),
                        WidgetSpan(
                          child: inlineTimeWidget,
                          alignment: PlaceholderAlignment.bottom,
                        ),
                      ],
                    ),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 14.5,
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: inlineTimeWidget,
                ),
            ],
          )
        else if (msg.isAudio)
          Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.65),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isMe ? myBgColor : otherBgColor,
              borderRadius: borderRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                AudioMessageBubble(
                  audioUrl: msg.audioUrl ?? '',
                  isMe: isMe,
                  isDark: isDark,
                  foregroundColor: bubbleTextColor,
                  durationMs: msg.audioDuration,
                ),
                if (msg.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0, left: 6, right: 6, bottom: 2),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: msg.text),
                          WidgetSpan(
                            child: inlineTimeWidget,
                            alignment: PlaceholderAlignment.bottom,
                          ),
                        ],
                      ),
                      style: TextStyle(
                        color: bubbleTextColor,
                        fontSize: 15.5,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 6, bottom: 2),
                    child: inlineTimeWidget,
                  ),
              ],
            ),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? myBgColor : otherBgColor,
                    borderRadius: borderRadius,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (postId == null)
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: msg.text),
                              WidgetSpan(
                                child: inlineTimeWidget,
                                alignment: PlaceholderAlignment.bottom,
                              ),
                            ],
                          ),
                          style: TextStyle(
                            color: bubbleTextColor,
                            fontSize: 15.5,
                          ),
                        )
                      else ...[
                        if (msg.text.replaceAll(match!.group(0)!, '').trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              msg.text.replaceAll(match.group(0)!, '').trim(),
                              style: TextStyle(
                                color: bubbleTextColor,
                                fontSize: 15.5,
                              ),
                            ),
                          ),
                        PostMessagePreview(postId: postId, isMe: isMe),
                        Align(
                          alignment: Alignment.centerRight,
                          child: inlineTimeWidget,
                        ),
                      ],
                    ],
                  ),
                ),
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
    final barBg = isDark ? const Color(0xFF141414) : Colors.white;
    final pillBg = isDark ? const Color(0xFF2A2A2E) : Colors.white;
    final pillBorder = isDark ? null : Border.all(color: Colors.grey.shade300, width: 1);
    final iconColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final divColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    Widget micButton = GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) => _stopRecording(),
      child: Padding(
        padding: EdgeInsets.only(
            left: _hasText ? 4 : 8,
            right: _hasText ? 4 : 12,
            bottom: 10,
            top: 10),
        child: Icon(
          _isRecording ? Icons.stop_circle_outlined : Icons.mic_none_rounded,
          color: _isRecording ? Colors.red : iconColor,
          size: 26,
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: barBg,
        border: Border(top: BorderSide(color: divColor, width: 0.8)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Pill: [+ | Mic (if text) | TextField | Send/Mic] ──
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 46, maxHeight: 130),
              decoration: BoxDecoration(
                color: pillBg,
                border: pillBorder,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // '+' attachment button INSIDE pill (left edge)
                  GestureDetector(
                    onTap: () {
                      KnockHaptics.tap();
                      _toggleAttachmentDrawer();
                    },
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

                  // Right Action: Mic + Send Button
                  if (_hasText) ...[
                    micButton,
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6, bottom: 6, top: 6),
                        child: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            color: isDark ? Colors.black : Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ] else
                    micButton,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  // ─────────────────────────────────────────────
  // Attachment Drawer (inline)
  // ─────────────────────────────────────────────

  void _toggleAttachmentDrawer() {
    setState(() => _isAttachmentDrawerOpen = !_isAttachmentDrawerOpen);
  }

  Widget _buildInlineAttachmentDrawer(bool isDark) {
    final drawerBg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    final keyboardUp = MediaQuery.of(context).viewInsets.bottom > 0;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final bottomPad = keyboardUp ? 8.0 : safeBottom + 16;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPad),
      decoration: BoxDecoration(
        color: drawerBg,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _AttachmentOption(
            icon: Icons.camera_alt_rounded,
            label: 'Camera',
            color: Colors.purple,
            onTap: () {
              setState(() => _isAttachmentDrawerOpen = false);
              _openMediaPicker(ImageSource.camera);
            },
          ),
          _AttachmentOption(
            icon: Icons.photo_library_rounded,
            label: 'Gallery',
            color: Colors.blue,
            onTap: () {
              setState(() => _isAttachmentDrawerOpen = false);
              _openMediaPicker(ImageSource.gallery);
            },
          ),
          _AttachmentOption(
            icon: Icons.videocam_rounded,
            label: 'Video',
            color: Colors.red,
            onTap: () {
              setState(() => _isAttachmentDrawerOpen = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Video picker coming soon')),
              );
            },
          ),
          _AttachmentOption(
            icon: Icons.location_on_rounded,
            label: 'Location',
            color: Colors.green,
            onTap: () {
              setState(() => _isAttachmentDrawerOpen = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Location sharing coming soon')),
              );
            },
          ),
        ],
      ),
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
