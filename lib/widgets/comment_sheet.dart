import 'dart:io';

import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../models/reply_thread.dart';
import '../models/user_model.dart';
import '../screens/profile/other_profile_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/reply_chat_screen.dart';
import '../screens/reply_list_screen.dart';
import '../services/comment_service.dart';
import '../services/current_user_service.dart';
import '../services/database_service.dart';
import '../models/message.dart';
import '../utils/haptic_helper.dart';
import '../utils/image_helper.dart';

class CommentSheet extends StatefulWidget {
  final String postId;
  final UserModel postAuthor;
  final bool isPostOwner;

  const CommentSheet({
    super.key,
    required this.postId,
    required this.postAuthor,
    this.isPostOwner = false,
  });

  static void show(
    BuildContext context, {
    required String postId,
    required UserModel postAuthor,
    bool isPostOwner = false,
  }) {
    KnockHaptics.tap();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentSheet(
        postId: postId,
        postAuthor: postAuthor,
        isPostOwner: isPostOwner,
      ),
    );
  }

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final PageController _pageController = PageController();

  String? _selectedThreadUserId;
  bool _showChatPage = false;
  final Map<String, UserModel> _userCache = {};

  UserModel get _viewer =>
      CurrentUserService.instance.currentUser!;

  @override
  void initState() {
    super.initState();
    _showChatPage = !widget.isPostOwner;
    if (!widget.isPostOwner) {
      _selectedThreadUserId = _viewer.id;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  UserModel _resolveUser(String userId) {
    if (userId == CurrentUserService.instance.currentUser?.id) {
      return CurrentUserService.instance.currentUser!;
    }
    // Return from cache if available, otherwise placeholder
    return _userCache[userId] ??
        UserModel(id: userId, displayName: 'User', username: 'user');
  }

  Future<void> _fetchAndCacheUser(String userId) async {
    if (_userCache.containsKey(userId)) return;
    if (userId == CurrentUserService.instance.currentUser?.id) return;
    try {
      final user = await DatabaseService.instance.getUserById(userId);
      if (user != null && mounted) {
        setState(() => _userCache[userId] = user);
      }
    } catch (_) {}
  }

  Future<void> _openThread(ReplyThread thread) async {
    KnockHaptics.selection();
    // Pre-fetch the user before showing the chat page
    await _fetchAndCacheUser(thread.userId);
    setState(() {
      _selectedThreadUserId = thread.userId;
      _showChatPage = true;
    });

    CommentService.instance.markThreadRead(
      postId: widget.postId,
      threadUserId: thread.userId,
    );

    await _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _closeThread() async {
    KnockHaptics.tap();
    setState(() => _showChatPage = false);
    await _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    setState(() => _selectedThreadUserId = null);
  }

  void _sendMessage(String text, String threadUserId) {
    CommentService.instance.sendMessage(
      postId: widget.postId,
      postAuthorId: widget.postAuthor.id,
      senderId: _viewer.id,
      threadUserId: threadUserId,
      text: text,
    );
  }

  void _openProfile(UserModel user) {
    final resolvedUser = user;
    final posts = <PostModel>[];

    KnockHaptics.tap();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => resolvedUser.isOwnProfile
            ? ProfileScreen(user: resolvedUser, posts: posts)
            : OtherProfileScreen(user: resolvedUser, posts: posts),
      ),
    );
  }

  Widget _buildChatPage(String threadUserId, ReplyThread? activeThread) {
    // We create a fallback thread if it doesn't exist yet
    final thread =
        activeThread ??
        ReplyThread(
          postId: widget.postId,
          authorId: widget.postAuthor.id,
          userId: threadUserId,
          lastMessage: '',
          lastTimestamp: DateTime.now(),
        );

    return StreamBuilder<List<ReplyMessage>>(
      stream: CommentService.instance.getMessagesForThread(
        postId: widget.postId,
        threadUserId: threadUserId,
      ),
      builder: (context, snapshot) {
        final messages = snapshot.data ?? [];
        return ReplyChatScreen(
          thread: thread,
          author: widget.postAuthor,
          currentViewer: _viewer,
          threadUser: _resolveUser(threadUserId),
          messages: messages,
          onSend: (text) => _sendMessage(text, threadUserId),
          onOpenProfile: _openProfile,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final sheetColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFEAEAEA);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: 0.88,
          child: Container(
            decoration: BoxDecoration(
              color: sheetColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: StreamBuilder<List<ReplyThread>>(
              stream: CommentService.instance.getThreadsForPost(
                postId: widget.postId,
                currentUserId: _viewer.id,
                isPostOwner: widget.isPostOwner,
              ),
              builder: (context, snapshot) {
                final threads = snapshot.data ?? [];

                // Pre-fetch all thread user profiles into cache when threads arrive
                for (final t in threads) {
                  _fetchAndCacheUser(t.userId);
                }

                ReplyThread? activeThread;
                if (_selectedThreadUserId != null) {
                  try {
                    activeThread = threads.firstWhere(
                      (t) => t.userId == _selectedThreadUserId,
                    );
                  } catch (e) {
                    activeThread = null;
                  }
                }

                UserModel? activePartner;
                if (_showChatPage && _selectedThreadUserId != null) {
                  activePartner = widget.isPostOwner
                      ? _resolveUser(_selectedThreadUserId!)
                      : widget.postAuthor;
                }

                return Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF3A3A3A)
                            : const Color(0xFFDADADA),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SheetHeader(
                      showListHeader: widget.isPostOwner && !_showChatPage,
                      participant: _showChatPage ? activePartner : null,
                      onParticipantTap: _showChatPage && activePartner != null
                          ? () => _openProfile(activePartner!)
                          : null,
                      onBack: widget.isPostOwner && _showChatPage
                          ? _closeThread
                          : null,
                    ),
                    Divider(height: 1, color: borderColor),
                    Expanded(
                      child: widget.isPostOwner
                          ? PageView(
                              controller: _pageController,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                ReplyListScreen(
                                  threads: threads,
                                  resolveUser: _resolveUser,
                                  onThreadTap: _openThread,
                                ),
                                _selectedThreadUserId == null
                                    ? const SizedBox.shrink()
                                    : _buildChatPage(
                                        _selectedThreadUserId!,
                                        activeThread,
                                      ),
                              ],
                            )
                          : _buildChatPage(_viewer.id, activeThread),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final bool showListHeader;
  final UserModel? participant;
  final VoidCallback? onParticipantTap;
  final VoidCallback? onBack;

  const _SheetHeader({
    required this.showListHeader,
    this.participant,
    this.onParticipantTap,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF171717);
    final subtleColor = isDark
        ? const Color(0xFF9A9A9A)
        : const Color(0xFF757575);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SizedBox(
        height: 46,
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: onBack == null
                  ? null
                  : IconButton(
                      onPressed: onBack,
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: textColor,
                      ),
                    ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: showListHeader
                    ? Center(
                        key: const ValueKey<String>('reply-title'),
                        child: Text(
                          'Replies',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      )
                    : GestureDetector(
                        key: ValueKey<String>(participant?.id ?? 'reply-user'),
                        onTap: onParticipantTap,
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          width: double.infinity,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              _HeaderAvatar(user: participant),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  participant?.username ?? 'Replies',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
            SizedBox(
              width: 40,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: subtleColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  final UserModel? user;

  const _HeaderAvatar({this.user});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtleColor = isDark
        ? const Color(0xFF9A9A9A)
        : const Color(0xFF757575);

    return CircleAvatar(
      radius: 16,
      backgroundColor: isDark
          ? const Color(0xFF2A2A2A)
          : const Color(0xFFEEEEEE),
      backgroundImage: ImageHelper.resolveAvatar(user?.avatarAsset),
      child: user?.avatarAsset == null
          ? Icon(Icons.person_rounded, size: 18, color: subtleColor)
          : null,
    );
  }
}
