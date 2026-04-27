import 'dart:io';

import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../models/reply_thread.dart';
import '../models/user_model.dart';
import '../screens/profile/other_profile_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/reply_chat_screen.dart';
import '../screens/reply_list_screen.dart';
import '../services/private_reply_demo_store.dart';
import '../utils/haptic_helper.dart';

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
  final PrivateReplyDemoStore _store = PrivateReplyDemoStore.instance;
  final PageController _pageController = PageController();

  String? _selectedThreadUserId;
  bool _showChatPage = false;

  UserModel get _viewer => widget.isPostOwner ? widget.postAuthor : demoOwnUser;

  List<ReplyThread> get _threads => _store.threadsForPost(
        postId: widget.postId,
        authorId: widget.postAuthor.id,
      );

  ReplyThread get _activeThread {
    if (widget.isPostOwner) {
      return _threads.firstWhere((thread) => thread.userId == _selectedThreadUserId);
    }

    return _store.ensureThread(
      postId: widget.postId,
      authorId: widget.postAuthor.id,
      userId: _viewer.id,
    );
  }

  UserModel get _activePartner {
    if (widget.isPostOwner) {
      return _resolveUser(_activeThread.userId);
    }
    return widget.postAuthor;
  }

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
    return findDemoUserById(userId) ?? demoOwnUser;
  }

  Future<void> _openThread(ReplyThread thread) async {
    KnockHaptics.selection();
    setState(() {
      _selectedThreadUserId = thread.userId;
      _showChatPage = true;
      _store.markThreadRead(thread);
    });

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

  void _sendMessage(String text) {
    final updatedThread = _store.sendMessage(
      thread: _activeThread,
      senderId: _viewer.id,
      text: text,
    );
    setState(() {
      _selectedThreadUserId = updatedThread.userId;
    });
  }

  void _openProfile(UserModel user) {
    final resolvedUser = findDemoUserById(user.id) ?? user;
    final posts = getDemoPostsForUser(resolvedUser.id);

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final sheetColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEAEAEA);

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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFDADADA),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
                _SheetHeader(
                  showListHeader: widget.isPostOwner && !_showChatPage,
                  participant: _showChatPage ? _activePartner : null,
                  onParticipantTap: _showChatPage ? () => _openProfile(_activePartner) : null,
                  onBack: widget.isPostOwner && _showChatPage ? _closeThread : null,
                ),
                Divider(height: 1, color: borderColor),
                Expanded(
                  child: widget.isPostOwner
                      ? PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            ReplyListScreen(
                              threads: _threads,
                              resolveUser: _resolveUser,
                              onThreadTap: _openThread,
                            ),
                            _selectedThreadUserId == null
                                ? const SizedBox.shrink()
                                : ReplyChatScreen(
                                    thread: _activeThread,
                                    author: widget.postAuthor,
                                    currentViewer: _viewer,
                                    threadUser: _resolveUser(_activeThread.userId),
                                    messages: _store.messagesForThread(_activeThread),
                                    onSend: _sendMessage,
                                    onOpenProfile: _openProfile,
                                  ),
                          ],
                        )
                      : ReplyChatScreen(
                          thread: _activeThread,
                          author: widget.postAuthor,
                          currentViewer: _viewer,
                          threadUser: _resolveUser(_activeThread.userId),
                          messages: _store.messagesForThread(_activeThread),
                          onSend: _sendMessage,
                          onOpenProfile: _openProfile,
                        ),
                ),
              ],
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
    final subtleColor = isDark ? const Color(0xFF9A9A9A) : const Color(0xFF757575);

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
    final subtleColor = isDark ? const Color(0xFF9A9A9A) : const Color(0xFF757575);

    return CircleAvatar(
      radius: 16,
      backgroundColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
      backgroundImage: user?.avatarAsset != null
          ? (user!.avatarAsset!.startsWith('assets/')
                ? AssetImage(user!.avatarAsset!) as ImageProvider
                : FileImage(File(user!.avatarAsset!)))
          : null,
      child: user?.avatarAsset == null
          ? Icon(Icons.person_rounded, size: 18, color: subtleColor)
          : null,
    );
  }
}
