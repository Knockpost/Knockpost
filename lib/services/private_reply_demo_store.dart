import '../models/message.dart';
import '../models/reply_thread.dart';

class PrivateReplyDemoStore {
  PrivateReplyDemoStore._();

  static final PrivateReplyDemoStore instance = PrivateReplyDemoStore._();

  final Map<String, List<ReplyThread>> _threadsByPost = {};
  final Map<String, List<ReplyMessage>> _messagesByThread = {};

  String _threadKey(String postId, String userId) => '$postId::$userId';

  List<ReplyThread> threadsForPost({
    required String postId,
    required String authorId,
  }) {
    _primePost(postId: postId, authorId: authorId);

    final threads = List<ReplyThread>.from(_threadsByPost[postId] ?? const [])
      ..sort((a, b) => b.lastTimestamp.compareTo(a.lastTimestamp));
    return List.unmodifiable(threads);
  }

  ReplyThread ensureThread({
    required String postId,
    required String authorId,
    required String userId,
  }) {
    _primePost(postId: postId, authorId: authorId);

    final threads = _threadsByPost.putIfAbsent(postId, () => <ReplyThread>[]);
    final existingIndex = threads.indexWhere((thread) => thread.userId == userId);
    if (existingIndex != -1) {
      return threads[existingIndex];
    }

    final now = DateTime.now();
    final thread = ReplyThread(
      postId: postId,
      authorId: authorId,
      userId: userId,
      lastMessage: '',
      lastTimestamp: now,
      unreadCount: 0,
    );
    threads.add(thread);
    _messagesByThread[_threadKey(postId, userId)] = <ReplyMessage>[];
    return thread;
  }

  List<ReplyMessage> messagesForThread(ReplyThread thread) {
    final key = _threadKey(thread.postId, thread.userId);
    final messages = List<ReplyMessage>.from(
      _messagesByThread[key] ?? const <ReplyMessage>[],
    )..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return List.unmodifiable(messages);
  }

  ReplyThread sendMessage({
    required ReplyThread thread,
    required String senderId,
    required String text,
  }) {
    final key = _threadKey(thread.postId, thread.userId);
    final visible = _messagesByThread.putIfAbsent(
      key,
      () => <ReplyMessage>[],
    );
    final timestamp = DateTime.now();
    final receiverId = senderId == thread.authorId ? thread.userId : thread.authorId;

    visible.add(
      ReplyMessage(
        id: 'msg_${timestamp.microsecondsSinceEpoch}',
        senderId: senderId,
        receiverId: receiverId,
        postId: thread.postId,
        text: text,
        timestamp: timestamp,
      ),
    );

    final updatedThread = thread.copyWith(
      lastMessage: text,
      lastTimestamp: timestamp,
      unreadCount: senderId == thread.authorId ? 0 : thread.unreadCount + 1,
    );
    _upsertThread(updatedThread);
    return updatedThread;
  }

  ReplyThread markThreadRead(ReplyThread thread) {
    if (thread.unreadCount == 0) {
      return thread;
    }

    final updatedThread = thread.copyWith(unreadCount: 0);
    _upsertThread(updatedThread);
    return updatedThread;
  }

  void _upsertThread(ReplyThread updatedThread) {
    final threads = _threadsByPost.putIfAbsent(
      updatedThread.postId,
      () => <ReplyThread>[],
    );
    final index = threads.indexWhere((thread) => thread.userId == updatedThread.userId);
    if (index == -1) {
      threads.add(updatedThread);
    } else {
      threads[index] = updatedThread;
    }
  }

  void _primePost({
    required String postId,
    required String authorId,
  }) {
    if (_threadsByPost.containsKey(postId)) {
      return;
    }

    _threadsByPost[postId] = <ReplyThread>[];
    final now = DateTime.now();

    if (authorId == 'me') {
      _seedThread(
        postId: postId,
        authorId: authorId,
        userId: 'arya01',
        unreadCount: 0,
        messages: <ReplyMessage>[
          ReplyMessage(
            id: '${postId}_arya_1',
            senderId: 'arya01',
            receiverId: 'me',
            postId: postId,
            text: 'This feels so calm. Was it early morning or sunset?',
            timestamp: now.subtract(const Duration(hours: 5, minutes: 18)),
          ),
          ReplyMessage(
            id: '${postId}_arya_2',
            senderId: 'me',
            receiverId: 'arya01',
            postId: postId,
            text: 'Sunset, just before the light disappeared.',
            timestamp: now.subtract(const Duration(hours: 4, minutes: 44)),
          ),
          ReplyMessage(
            id: '${postId}_arya_3',
            senderId: 'arya01',
            receiverId: 'me',
            postId: postId,
            text: 'That softness makes so much sense now.',
            timestamp: now.subtract(const Duration(hours: 4, minutes: 5)),
          ),
          ReplyMessage(
            id: '${postId}_arya_4',
            senderId: 'me',
            receiverId: 'arya01',
            postId: postId,
            text: 'The air was almost still, so everything stayed quiet.',
            timestamp: now.subtract(const Duration(hours: 3, minutes: 16)),
          ),
        ],
      );

      _seedThread(
        postId: postId,
        authorId: authorId,
        userId: 'suman01',
        unreadCount: 1,
        messages: <ReplyMessage>[
          ReplyMessage(
            id: '${postId}_suman_1',
            senderId: 'suman01',
            receiverId: 'me',
            postId: postId,
            text: 'The colors in this post are incredible.',
            timestamp: now.subtract(const Duration(hours: 8, minutes: 12)),
          ),
          ReplyMessage(
            id: '${postId}_suman_2',
            senderId: 'me',
            receiverId: 'suman01',
            postId: postId,
            text: 'Thank you. Shimla did most of the work for me.',
            timestamp: now.subtract(const Duration(hours: 7, minutes: 42)),
          ),
          ReplyMessage(
            id: '${postId}_suman_3',
            senderId: 'suman01',
            receiverId: 'me',
            postId: postId,
            text: 'Was this from your last trip or an older one?',
            timestamp: now.subtract(const Duration(hours: 2, minutes: 35)),
          ),
          ReplyMessage(
            id: '${postId}_suman_4',
            senderId: 'me',
            receiverId: 'suman01',
            postId: postId,
            text: 'Last trip. It started raining ten minutes after this frame.',
            timestamp: now.subtract(const Duration(hours: 2, minutes: 2)),
          ),
          ReplyMessage(
            id: '${postId}_suman_5',
            senderId: 'suman01',
            receiverId: 'me',
            postId: postId,
            text: 'That haze makes perfect sense now.',
            timestamp: now.subtract(const Duration(minutes: 41)),
          ),
        ],
      );

      _seedThread(
        postId: postId,
        authorId: authorId,
        userId: 'saptarshi01',
        unreadCount: 1,
        messages: <ReplyMessage>[
          ReplyMessage(
            id: '${postId}_sap_1',
            senderId: 'saptarshi01',
            receiverId: 'me',
            postId: postId,
            text: 'Love how quiet this looks.',
            timestamp: now.subtract(const Duration(hours: 11, minutes: 50)),
          ),
          ReplyMessage(
            id: '${postId}_sap_2',
            senderId: 'me',
            receiverId: 'saptarshi01',
            postId: postId,
            text: 'It was one of those rare empty mornings.',
            timestamp: now.subtract(const Duration(hours: 11, minutes: 8)),
          ),
          ReplyMessage(
            id: '${postId}_sap_3',
            senderId: 'saptarshi01',
            receiverId: 'me',
            postId: postId,
            text: 'You should keep posting more frames like this.',
            timestamp: now.subtract(const Duration(hours: 1, minutes: 14)),
          ),
        ],
      );
      return;
    }

    _seedThread(
      postId: postId,
      authorId: authorId,
      userId: 'me',
      unreadCount: 0,
      messages: <ReplyMessage>[
        ReplyMessage(
          id: '${postId}_me_1',
          senderId: 'me',
          receiverId: authorId,
          postId: postId,
          text: 'This is absolutely beautiful. Where was this taken?',
          timestamp: now.subtract(const Duration(hours: 2, minutes: 34)),
        ),
        ReplyMessage(
          id: '${postId}_me_2',
          senderId: authorId,
          receiverId: 'me',
          postId: postId,
          text: 'Thank you. It was taken in Shimla during sunset.',
          timestamp: now.subtract(const Duration(hours: 2, minutes: 5)),
        ),
        ReplyMessage(
          id: '${postId}_me_3',
          senderId: 'me',
          receiverId: authorId,
          postId: postId,
          text: 'The colors in it are incredible.',
          timestamp: now.subtract(const Duration(minutes: 48)),
        ),
        ReplyMessage(
          id: '${postId}_me_4',
          senderId: authorId,
          receiverId: 'me',
          postId: postId,
          text: 'That light only stayed for about two minutes.',
          timestamp: now.subtract(const Duration(minutes: 18)),
        ),
      ],
    );
  }

  void _seedThread({
    required String postId,
    required String authorId,
    required String userId,
    required List<ReplyMessage> messages,
    required int unreadCount,
  }) {
    final key = _threadKey(postId, userId);
    final lastMessage = messages.last;

    _threadsByPost[postId]!.add(
      ReplyThread(
        postId: postId,
        authorId: authorId,
        userId: userId,
        lastMessage: lastMessage.text,
        lastTimestamp: lastMessage.timestamp,
        unreadCount: unreadCount,
      ),
    );
    _messagesByThread[key] = List<ReplyMessage>.from(messages);
  }
}
