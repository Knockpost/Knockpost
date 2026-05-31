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
import 'knockpost_avatar.dart';

class CommentSheet extends StatefulWidget {
  final String postId;
  final UserModel postAuthor;
  final bool isPostOwner;
  final String? initialThreadUserId;
  final String? postThumbnailUrl;

  const CommentSheet({
    super.key,
    required this.postId,
    required this.postAuthor,
    this.isPostOwner = false,
    this.initialThreadUserId,
    this.postThumbnailUrl,
  });

  static void show(
    BuildContext context, {
    required String postId,
    required UserModel postAuthor,
    bool isPostOwner = false,
    String? initialThreadUserId,
    String? postThumbnailUrl,
  }) {
    KnockHaptics.tap();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => CommentSheet(
        postId: postId,
        postAuthor: postAuthor,
        isPostOwner: isPostOwner,
        initialThreadUserId: initialThreadUserId,
        postThumbnailUrl: postThumbnailUrl,
      ),
    );
  }

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  late final PageController _pageController;

  String? _selectedThreadUserId;
  bool _showChatPage = false;
  final Map<String, UserModel> _userCache = {};
  bool _isSending = false;

  /// Cached once in initState so widget rebuilds (keyboard, setState)
  /// don't tear down and recreate the Firestore listener.
  late final Stream<List<ReplyThread>> _threadsStream;

  UserModel get _viewer =>
      CurrentUserService.instance.currentUser!;

  @override
  void initState() {
    super.initState();

    // Initialize the threads stream ONCE
    _threadsStream = CommentService.instance.getThreadsForPost(
      postId: widget.postId,
      currentUserId: CurrentUserService.instance.currentUser!.id,
      isPostOwner: widget.isPostOwner,
    );

    // If isPostOwner and there's an initialThreadUserId, jump directly to that chat
    if (widget.isPostOwner && widget.initialThreadUserId != null) {
      _selectedThreadUserId = widget.initialThreadUserId;
      _showChatPage = true;
      _pageController = PageController(initialPage: 1);
      // Pre-fetch the thread user
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _fetchAndCacheUser(widget.initialThreadUserId!);
      });
    } else {
      _pageController = PageController(initialPage: 0);
      _showChatPage = !widget.isPostOwner;
      if (!widget.isPostOwner) {
        _selectedThreadUserId = _viewer.id;
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Release cached Firestore listeners so they don't leak, targeted by post
    CommentService.instance.disposePostStreams(widget.postId);
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
      isPostOwner: widget.isPostOwner,
    );

    await _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutQuart,
    );
  }

  Future<void> _closeThread({bool haptic = true}) async {
    if (haptic) KnockHaptics.tap();
    setState(() => _showChatPage = false);
    await _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutQuart,
    );
    if (!mounted) return;
    setState(() => _selectedThreadUserId = null);
  }

  void _sendMessage(String text, String threadUserId) {
    if (_isSending) return;
    _isSending = true;

    CommentService.instance.sendMessageWithRetry(
      postId: widget.postId,
      postAuthorId: widget.postAuthor.id,
      senderId: _viewer.id,
      threadUserId: threadUserId,
      text: text,
      postThumbnailUrl: widget.postThumbnailUrl,
    ).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send reply')),
        );
      }
    }).whenComplete(() {
      _isSending = false;
    });
  }

  void _openProfile(UserModel user) {
    if (user.id != _viewer.id && !_userCache.containsKey(user.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account no longer exists')),
      );
      return;
    }

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

    Widget chatWidget = StreamBuilder<List<ReplyMessage>>(
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

    // Post owners can swipe right to go back to reply list
    if (widget.isPostOwner) {
      chatWidget = GestureDetector(
        onHorizontalDragEnd: (details) {
          // Swipe right (positive velocity) → go back to list
          if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
            _closeThread();
          }
        },
        child: chatWidget,
      );
    }

    return chatWidget;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF333333).withValues(alpha: 0.5)
        : const Color(0xFFE5E5E5).withValues(alpha: 0.6);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final viewPadding = MediaQuery.of(context).viewPadding.bottom;
    // Intercept Android back button: if post owner is in chat, go back to list
    final interceptBack = widget.isPostOwner && _showChatPage;

    return PopScope(
      canPop: !interceptBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && interceptBack) {
          _closeThread(haptic: false);
        }
      },
      child: FractionallySizedBox(
        heightFactor: 0.78,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(30),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: sheetColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(30),
            ),
            border: Border(top: BorderSide(color: borderColor)),
          ),
          child: Column(
            children: [
              // ── Drag handle ──
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),

              // ── Header ──
              StreamBuilder<List<ReplyThread>>(
                stream: _threadsStream,
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

                  return Expanded(
                    child: Column(
                      children: [
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
                    ),
                  );
                },
              ),

              // ── Bottom safe area + keyboard spacing ──
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                height: viewInsets > 0 ? viewInsets : viewPadding,
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
    final subtleColor = isDark
        ? const Color(0xFF9A9A9A)
        : const Color(0xFF757575);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            if (onBack != null)
              SizedBox(
                width: 40,
                child: IconButton(
                  onPressed: onBack,
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: textColor,
                  ),
                ),
              )
            else
              SizedBox(width: showListHeader ? 40 : 12),
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
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
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
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  participant?.username ?? 'Replies',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 17,
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
                icon: Icon(Icons.close_rounded, color: subtleColor, size: 22),
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
    return KnockPostAvatar(
      url: user?.avatarAsset,
      radius: 15,
      name: user?.displayName,
    );
  }
}
