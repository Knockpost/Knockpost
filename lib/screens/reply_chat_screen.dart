import 'package:flutter/material.dart';

import '../models/message.dart';
import '../models/reply_thread.dart';
import '../models/user_model.dart';
import '../utils/haptic_helper.dart';
import '../widgets/message_bubble.dart';

const List<String> _quickReplyReactions = <String>[
  '❤️',
  '🙌',
  '🔥',
  '👏',
  '😭',
  '😍',
];

class ReplyChatScreen extends StatefulWidget {
  final ReplyThread thread;
  final UserModel author;
  final UserModel currentViewer;
  final UserModel threadUser;
  final List<ReplyMessage> messages;
  final ValueChanged<String> onSend;
  final ValueChanged<UserModel> onOpenProfile;

  const ReplyChatScreen({
    super.key,
    required this.thread,
    required this.author,
    required this.currentViewer,
    required this.threadUser,
    required this.messages,
    required this.onSend,
    required this.onOpenProfile,
  });

  @override
  State<ReplyChatScreen> createState() => _ReplyChatScreenState();
}

class _ReplyChatScreenState extends State<ReplyChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  bool _hasText = false;
  bool _isComposerFocused = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  @override
  void didUpdateWidget(covariant ReplyChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final threadChanged = oldWidget.thread.id != widget.thread.id;
    final messageCountChanged = oldWidget.messages.length != widget.messages.length;
    final lastMessageChanged =
        oldWidget.messages.isEmpty ||
        widget.messages.isEmpty ||
        oldWidget.messages.last.id != widget.messages.last.id;

    if (threadChanged) {
      _controller.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
      return;
    }

    if (messageCountChanged && lastMessageChanged) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _jumpToBottom(animated: true),
      );
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus != _isComposerFocused) {
      setState(() => _isComposerFocused = _focusNode.hasFocus);
      // Auto-scroll to bottom when keyboard opens
      if (_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _jumpToBottom(animated: true);
        });
      }
    }
  }

  void _jumpToBottom({bool animated = false}) {
    if (!_scrollController.hasClients) {
      return;
    }

    final offset = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(offset);
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }

    KnockHaptics.impact();
    widget.onSend(text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  void _insertQuickReaction(String emoji) {
    KnockHaptics.selection();
    final value = _controller.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final start = selection.start >= 0 ? selection.start : value.text.length;
    final end = selection.end >= 0 ? selection.end : value.text.length;
    final nextText = value.text.replaceRange(start, end, emoji);
    final caretOffset = start + emoji.length;

    _controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: caretOffset),
    );
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF171717);
    final subtleColor = isDark ? const Color(0xFF9A9A9A) : const Color(0xFF757575);
    final composerSurface = isDark ? const Color(0xFF141414) : Colors.white;
    final composerBorder = isDark ? const Color(0xFF252525) : const Color(0xFFF1F1F1);
    final inputFill = isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF6F6F6);
    final inputBorderColor = _isComposerFocused
        ? (isDark ? const Color(0xFF414141) : const Color(0xFFDDDDDD))
        : Colors.transparent;
    final sendButtonIdle = isDark ? const Color(0xFF252525) : const Color(0xFFEDEDED);
    final sendButtonActive = isDark ? const Color(0xFFE8EDF2) : const Color(0xFF171717);
    final sendIconColor = _hasText
        ? (isDark ? const Color(0xFF111111) : Colors.white)
        : subtleColor;
    final otherParticipant = widget.currentViewer.id == widget.author.id
        ? widget.threadUser
        : widget.author;
    final noticeText =
        'Private to you and @${otherParticipant.username}';

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Column(
        children: [
          // ── Messages area ──
          Expanded(
            child: CustomScrollView(
              key: PageStorageKey<String>('reply-chat-${widget.thread.id}'),
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                // Privacy notice
                SliverToBoxAdapter(
                  child: _PrivacyNotice(text: noticeText),
                ),

                // Empty state or messages
                if (widget.messages.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 80),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 32,
                              color: subtleColor.withValues(alpha: 0.35),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Start the conversation',
                              style: TextStyle(
                                color: subtleColor.withValues(alpha: 0.7),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate.fixed([
                        for (int index = 0; index < widget.messages.length; index++) ...[
                          if (_shouldShowDayDivider(index))
                            _DayDivider(label: _dayLabel(widget.messages[index].timestamp)),
                          MessageBubble(
                            message: widget.messages[index],
                            sender: _senderFor(widget.messages[index]),
                            isUserSide: _isCurrentViewerMessage(widget.messages[index]),
                            showSenderMeta: _shouldShowSenderMeta(index),
                            timeLabel: _timeLabel(widget.messages[index].timestamp),
                            onUserTap: () => widget.onOpenProfile(
                              _senderFor(widget.messages[index]),
                            ),
                          ),
                        ],
                      ]),
                    ),
                  ),
              ],
            ),
          ),

          // ── Composer area ──
          Container(
            decoration: BoxDecoration(
              color: composerSurface,
              border: Border(top: BorderSide(color: composerBorder)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Quick reactions row — responsive, never wraps
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _QuickReactionsRow(
                      reactions: _quickReplyReactions,
                      isDark: isDark,
                      onTap: _insertQuickReaction,
                    ),
                  ),

                  // Input field
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.fromLTRB(14, 4, 5, 4),
                    decoration: BoxDecoration(
                      color: inputFill,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: inputBorderColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            textInputAction: TextInputAction.send,
                            minLines: 1,
                            maxLines: 4,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Send a reply...',
                              hintStyle: TextStyle(
                                color: subtleColor,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        GestureDetector(
                          onTap: _hasText ? _sendMessage : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _hasText ? sendButtonActive : sendButtonIdle,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_upward_rounded,
                              color: sendIconColor,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
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

  bool _shouldShowSenderMeta(int index) {
    if (index == 0) {
      return true;
    }

    final previous = widget.messages[index - 1];
    final current = widget.messages[index];
    return previous.senderId != current.senderId ||
        !_isSameDay(previous.timestamp, current.timestamp);
  }

  bool _shouldShowDayDivider(int index) {
    if (index == 0) {
      return true;
    }
    return !_isSameDay(
      widget.messages[index - 1].timestamp,
      widget.messages[index].timestamp,
    );
  }

  UserModel _senderFor(ReplyMessage message) {
    if (message.senderId == widget.author.id) {
      return widget.author;
    }
    return widget.threadUser;
  }

  bool _isCurrentViewerMessage(ReplyMessage message) {
    return message.senderId == widget.currentViewer.id;
  }

  String _timeLabel(DateTime timestamp) {
    final hour = timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final suffix = timestamp.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  String _dayLabel(DateTime timestamp) {
    final now = DateTime.now();
    if (_isSameDay(now, timestamp)) {
      return 'Today';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    if (_isSameDay(yesterday, timestamp)) {
      return 'Yesterday';
    }

    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[timestamp.month - 1]} ${timestamp.day}';
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Reactions Row — responsive, never wraps
// ─────────────────────────────────────────────────────────────────────────────

class _QuickReactionsRow extends StatelessWidget {
  final List<String> reactions;
  final bool isDark;
  final ValueChanged<String> onTap;

  const _QuickReactionsRow({
    required this.reactions,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fillColor = isDark ? const Color(0xFF202020) : const Color(0xFFF5F5F5);
    final screenWidth = MediaQuery.of(context).size.width;
    // Calculate button size: available width / count, with min/max constraints
    const horizontalPadding = 14.0 * 2; // parent padding
    final availableWidth = screenWidth - horizontalPadding;
    const spacing = 8.0;
    final totalSpacing = spacing * (reactions.length - 1);
    final rawSize = (availableWidth - totalSpacing) / reactions.length;
    final buttonSize = rawSize.clamp(36.0, 46.0);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < reactions.length; i++) ...[
          if (i > 0) const SizedBox(width: spacing),
          _QuickReactionButton(
            emoji: reactions[i],
            fillColor: fillColor,
            size: buttonSize,
            onTap: () => onTap(reactions[i]),
          ),
        ],
      ],
    );
  }
}

class _QuickReactionButton extends StatefulWidget {
  final String emoji;
  final Color fillColor;
  final double size;
  final VoidCallback onTap;

  const _QuickReactionButton({
    required this.emoji,
    required this.fillColor,
    required this.size,
    required this.onTap,
  });

  @override
  State<_QuickReactionButton> createState() => _QuickReactionButtonState();
}

class _QuickReactionButtonState extends State<_QuickReactionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 0.0,
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _scaleController.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _scaleController.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    // Emoji font size scales with button size
    final emojiSize = widget.size * 0.52;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleController,
        builder: (context, child) {
          final scale = 1.0 - (_scaleController.value * 0.12);
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.fillColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              widget.emoji,
              style: TextStyle(
                fontSize: emojiSize,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day Divider
// ─────────────────────────────────────────────────────────────────────────────

class _DayDivider extends StatelessWidget {
  final String label;

  const _DayDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFF8F8F8F) : const Color(0xFF7A7A7A);
    final fillColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F2F2);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Privacy Notice — minimal
// ─────────────────────────────────────────────────────────────────────────────

class _PrivacyNotice extends StatelessWidget {
  final String text;

  const _PrivacyNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtleColor = isDark
        ? const Color(0xFF6E6E6E)
        : const Color(0xFF9A9A9A);

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 6),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 12,
              color: subtleColor,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: subtleColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
