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
        duration: const Duration(milliseconds: 220),
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
    final reactionButtonFill =
        isDark ? const Color(0xFF202020) : const Color(0xFFF5F5F5);
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
        'Only you and @${otherParticipant.username} can view these replies.';

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              key: PageStorageKey<String>('reply-chat-${widget.thread.id}'),
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(
                  child: _PrivacyNotice(text: noticeText),
                ),
                if (widget.messages.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 44,
                              color: subtleColor.withValues(alpha: 0.65),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'This private thread starts with the first reply.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Say something about the post and the conversation stays only between the author and this user.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: subtleColor,
                                fontSize: 13.5,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 18),
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
          Container(
            decoration: BoxDecoration(
              color: composerSurface,
              border: Border(top: BorderSide(color: composerBorder)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final emoji in _quickReplyReactions)
                            _QuickReactionButton(
                              emoji: emoji,
                              fillColor: reactionButtonFill,
                              onTap: () => _insertQuickReaction(emoji),
                            ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.fromLTRB(16, 5, 6, 5),
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
                            duration: const Duration(milliseconds: 180),
                            width: 40,
                            height: 40,
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

class _QuickReactionButton extends StatelessWidget {
  final String emoji;
  final Color fillColor;
  final VoidCallback onTap;

  const _QuickReactionButton({
    required this.emoji,
    required this.fillColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: fillColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              emoji,
              style: const TextStyle(
                fontSize: 25,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayDivider extends StatelessWidget {
  final String label;

  const _DayDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFF8F8F8F) : const Color(0xFF7A7A7A);
    final fillColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F2F2);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  final String text;

  const _PrivacyNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtleColor = isDark ? const Color(0xFF9A9A9A) : const Color(0xFF757575);

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text.rich(
            TextSpan(
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: subtleColor.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                TextSpan(
                  text: text,
                  style: TextStyle(
                    color: subtleColor,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
