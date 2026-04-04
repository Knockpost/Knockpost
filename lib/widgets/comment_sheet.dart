import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/comment_model.dart';
import '../utils/haptic_helper.dart';

/// Quick-reaction emojis shown above the input
const List<String> _quickEmojis = ['❤', '🙌', '🔥', '👏', '😭', '😍', '😮', '😢'];

/// Instagram-style comment bottom sheet for Knockpost's
/// private 2-sided comment system.
class CommentSheet extends StatefulWidget {
  final String postId;
  final bool isPostOwner;

  const CommentSheet({
    super.key,
    required this.postId,
    this.isPostOwner = false,
  });

  /// Show the comment sheet as a modal bottom sheet
  static void show(BuildContext context, {required String postId, bool isPostOwner = false}) {
    KnockHaptics.tap();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentSheet(postId: postId, isPostOwner: isPostOwner),
    );
  }

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<Comment> _comments = [];
  String? _replyingToId;
  String? _replyingToUsername;
  String? _editingCommentId;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _comments = generateDemoComments();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendComment([String? text]) {
    final commentText = text ?? _controller.text.trim();
    if (commentText.isEmpty) return;

    KnockHaptics.impact();

    if (_editingCommentId != null) {
      setState(() {
        final index = _comments.indexWhere((c) => c.id == _editingCommentId);
        if (index != -1) {
          final old = _comments[index];
          _comments[index] = Comment(
             id: old.id,
             text: commentText,
             authorUsername: old.authorUsername,
             isPostOwner: old.isPostOwner,
             replyToId: old.replyToId,
             timestamp: old.timestamp,
          );
        }
        _editingCommentId = null;
      });
    } else {
      setState(() {
        _comments.add(Comment(
          id: 'c${DateTime.now().millisecondsSinceEpoch}',
          text: commentText,
          authorUsername: 'you',
          isPostOwner: widget.isPostOwner,
          replyToId: _replyingToId,
        ));
        _replyingToId = null;
        _replyingToUsername = null;
      });
    }

    if (text == null) _controller.clear();

    // Scroll to bottom after adding
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendQuickEmoji(String emoji) {
    KnockHaptics.selection();
    final currentText = _controller.text;
    final selection = _controller.selection;
    if (selection.isValid && selection.baseOffset >= 0) {
      final newText = currentText.replaceRange(
        selection.start,
        selection.end,
        emoji,
      );
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start + emoji.length,
        ),
      );
    } else {
      _controller.text = currentText + emoji;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
    _focusNode.requestFocus();
  }

  void _setReply(String commentId, String username) {
    KnockHaptics.selection();
    setState(() {
      _replyingToId = commentId;
      _replyingToUsername = username;
      _editingCommentId = null;
    });
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    KnockHaptics.tap();
    setState(() {
      _replyingToId = null;
      _replyingToUsername = null;
    });
  }

  void _startEditing(Comment comment) {
    setState(() {
      _editingCommentId = comment.id;
      _replyingToId = null;
      _replyingToUsername = null;
    });
    _controller.text = comment.text;
    _focusNode.requestFocus();
  }

  void _cancelEdit() {
    KnockHaptics.tap();
    setState(() {
      _editingCommentId = null;
      _controller.clear();
    });
    _focusNode.unfocus();
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtleColor = isDark ? Colors.grey.shade600 : Colors.grey.shade400;
    final inputBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ── Drag handle ──
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: subtleColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        'Private comments',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () {
                          KnockHaptics.tap();
                          Navigator.pop(context);
                        },
                        child: Icon(Icons.close, size: 22, color: subtleColor),
                      ),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: subtleColor.withOpacity(0.3)),

              // ── Private Notice ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(color: subtleColor.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Only you and the creator can see what you write here. No one else can view these comments.',
                        style: TextStyle(
                          color: textColor.withOpacity(0.8),
                          fontSize: 13,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Your comments stay visible only to you and this creator.',
                        style: TextStyle(
                          color: textColor.withOpacity(0.7),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Comment list ──
              Expanded(
                child: _comments.isEmpty
                    ? _buildEmptyState(textColor, subtleColor)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          Comment? parent;
                          if (comment.replyToId != null) {
                            try {
                              parent = _comments.firstWhere((c) => c.id == comment.replyToId);
                            } catch (_) {}
                          }
                          return _buildCommentTile(comment, textColor, subtleColor, isReply: false, parentComment: parent);
                        },
                      ),
              ),

              // ── Reply preview ──
              if (_replyingToId != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: inputBg,
                  child: Row(
                    children: [
                      Icon(Icons.reply, size: 16, color: subtleColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Replying to @$_replyingToUsername',
                          style: TextStyle(
                            fontSize: 13,
                            color: subtleColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _cancelReply,
                        child: Icon(Icons.close, size: 16, color: subtleColor),
                      ),
                    ],
                  ),
                ),

              // ── Edit preview ──
              if (_editingCommentId != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: inputBg,
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 16, color: subtleColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Editing message',
                          style: TextStyle(
                            fontSize: 13,
                            color: subtleColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _cancelEdit,
                        child: Icon(Icons.close, size: 16, color: subtleColor),
                      ),
                    ],
                  ),
                ),

              // ── Emoji quick-reactions row ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border(
                    top: BorderSide(color: subtleColor.withOpacity(0.15)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _quickEmojis.take(6).map((emoji) {
                    return GestureDetector(
                      onTap: () => _sendQuickEmoji(emoji),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // ── Input bar ──
              Container(
                padding: EdgeInsets.fromLTRB(
                  12, 8, 12,
                  keyboardHeight > 0 ? 8.0 : safeBottom + 8.0,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                ),
                child: Row(
                  children: [
                    // Avatar
                    const CircleAvatar(
                      radius: 17,
                      backgroundColor: Color(0xFF2B8EFF),
                      child: Text(
                        'Y',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Text input
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: inputBg,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          style: TextStyle(fontSize: 14, color: textColor),
                          decoration: InputDecoration(
                            hintText: 'Send a private comment...',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: subtleColor,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendComment(),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Send button
                    GestureDetector(
                      onTap: _hasText ? _sendComment : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _hasText
                              ? const Color(0xFF2B8EFF)
                              : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          size: 20,
                          color: _hasText ? Colors.white : subtleColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      ),
    );
  }

  Widget _buildCommentTile(
    Comment comment,
    Color textColor,
    Color subtleColor, {
    required bool isReply,
    Comment? parentComment,
  }) {
    final isMe = comment.authorUsername == 'you';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;

    return Padding(
      padding: EdgeInsets.only(
        left: comment.isPostOwner ? 48.0 : 16.0,
        right: 16.0,
        top: 6.0,
        bottom: 6.0,
      ),
      child: _FastLongPressTile(
        onSwipeReply: () {
          _setReply(comment.id, comment.authorUsername);
        },
        onFastLongPress: (position) {
          KnockHaptics.impact();
          FocusManager.instance.primaryFocus?.unfocus(); // automatically dismiss keyboard safely
          _showCommentOptions(context, position, comment, isMe);
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: isReply ? 14 : 16,
              backgroundImage: comment.authorUsername == 'you'
                  ? const AssetImage('assets/test1.jpg')
                  : null,
              backgroundColor: comment.isPostOwner
                  ? textColor
                  : Colors.grey.shade400,
              child: comment.authorUsername != 'you'
                  ? Icon(
                      Icons.person,
                      size: isReply ? 14 : 16,
                      color: comment.isPostOwner ? bgColor : Colors.grey.shade600,
                    )
                  : null,
            ),
            const SizedBox(width: 10),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Username + Author badge + Time
                  Row(
                    children: [
                      Text(
                        comment.authorUsername,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      if (comment.isPostOwner) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: textColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Author',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: subtleColor,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        _timeAgo(comment.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: subtleColor,
                        ),
                      ),
                    ], // Row children
                  ), // Row

                  const SizedBox(height: 3),

                  // ── Replied message preview ──
                  if (parentComment != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.subdirectory_arrow_right_rounded,
                            size: 12,
                            color: subtleColor.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            parentComment.authorUsername,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: subtleColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              parentComment.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: subtleColor.withOpacity(0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Comment text
                  Text(
                    comment.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor,
                      height: 1.3,
                    ),
                  ),
                ], // Column children
              ), // Column
            ), // Expanded
          ], // Row children
        ), // Row
      ), // GestureDetector
    ); // Padding
  }
  
  void _showCommentOptions(BuildContext context, Offset position, Comment comment, bool isMe) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff2A2A2A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: bgColor,
      elevation: 8,
      items: [
        PopupMenuItem(
          value: 'reply',
          child: Row(
            children: [
              Icon(Icons.reply, size: 20, color: textColor),
              const SizedBox(width: 12),
              Text('Reply', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
            ]
          )
        ),
        PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy, size: 20, color: textColor),
              const SizedBox(width: 12),
              Text('Copy', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
            ]
          )
        ),
        if (isMe)
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit, size: 20, color: textColor),
                const SizedBox(width: 12),
                Text('Edit', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
              ]
            )
          ),
        if (isMe)
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 20, color: Colors.red),
                SizedBox(width: 12),
                Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              ]
            )
          ),
      ],
    );

    if (!context.mounted) return;

    if (result == 'reply') {
      KnockHaptics.selection();
      _setReply(comment.id, comment.authorUsername);
    } else if (result == 'copy') {
      KnockHaptics.selection();
      Clipboard.setData(ClipboardData(text: comment.text));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message copied')));
    } else if (result == 'delete') {
      KnockHaptics.heavy();
      setState(() => _comments.removeWhere((c) => c.id == comment.id));
    } else if (result == 'edit') {
      KnockHaptics.selection();
      _startEditing(comment);
    }
  }

  Widget _buildEmptyState(Color textColor, Color subtleColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 56,
            color: subtleColor.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No comments yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Start the conversation',
            style: TextStyle(
              fontSize: 13,
              color: subtleColor,
            ),
          ),
        ],
      ),
    );
  }
}

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

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _cancelTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        _cancelTimer();
        _timer = Timer(const Duration(milliseconds: 250), () {
          widget.onFastLongPress(details.globalPosition);
        });
      },
      onTapUp: (_) => _cancelTimer(),
      onTapCancel: () => _cancelTimer(),
      onHorizontalDragEnd: (details) {
        _cancelTimer();
        if (details.primaryVelocity! > 100) {
          widget.onSwipeReply();
        }
      },
      child: widget.child,
    );
  }
}

/// Small like button for individual comments
class _CommentLikeButton extends StatefulWidget {
  final Color subtleColor;
  const _CommentLikeButton({required this.subtleColor});

  @override
  State<_CommentLikeButton> createState() => _CommentLikeButtonState();
}

class _CommentLikeButtonState extends State<_CommentLikeButton> {
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        KnockHaptics.selection();
        setState(() => _liked = !_liked);
      },
      child: Icon(
        _liked ? Icons.favorite : Icons.favorite_border,
        size: 16,
        color: _liked ? const Color(0xFFED4956) : widget.subtleColor,
      ),
    );
  }
}
