import 'dart:async';
import 'chat_logger.dart';
import 'connectivity_service.dart';

typedef RetryAction = Future<void> Function();

class _RetryTask {
  final String messageId;
  final RetryAction action;
  int attempts = 0;
  final int maxAttempts = 3;

  _RetryTask({
    required this.messageId,
    required this.action,
  });
}

class MessageRetryQueue {
  MessageRetryQueue._() {
    ConnectivityService.instance.onConnectivityChanged.listen((isOnline) {
      if (isOnline) {
        _processQueue();
      }
    });
  }

  static final MessageRetryQueue instance = MessageRetryQueue._();

  final List<_RetryTask> _queue = [];
  bool _isProcessing = false;

  void enqueue(String messageId, RetryAction action) {
    // Avoid duplicates
    if (_queue.any((t) => t.messageId == messageId)) {
      ChatLogger.instance.info('RetryQueue', 'Task $messageId already in queue, skipping enqueue.');
      return;
    }

    ChatLogger.instance.info('RetryQueue', 'Enqueued failed message $messageId');
    _queue.add(_RetryTask(messageId: messageId, action: action));

    if (ConnectivityService.instance.isOnline) {
      _processQueue();
    }
  }

  void remove(String messageId) {
    _queue.removeWhere((t) => t.messageId == messageId);
  }

  Future<void> _processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;
    _isProcessing = true;

    ChatLogger.instance.info('RetryQueue', 'Starting queue processing. Tasks: ${_queue.length}');

    // Copy queue to process safely
    final tasksToProcess = List<_RetryTask>.from(_queue);

    for (var task in tasksToProcess) {
      if (!ConnectivityService.instance.isOnline) {
        ChatLogger.instance.warning('RetryQueue', 'Offline during processing. Halting queue.');
        break;
      }

      task.attempts++;
      ChatLogger.instance.info('RetryQueue', 'Retrying task ${task.messageId} (Attempt ${task.attempts}/${task.maxAttempts})');

      try {
        await task.action();
        ChatLogger.instance.info('RetryQueue', 'Task ${task.messageId} succeeded');
        _queue.remove(task);
      } catch (e, stack) {
        ChatLogger.instance.error('RetryQueue', 'Task ${task.messageId} failed on retry', e, stack);
        if (task.attempts >= task.maxAttempts) {
          ChatLogger.instance.warning('RetryQueue', 'Task ${task.messageId} max attempts reached. Dropping.');
          _queue.remove(task);
        } else {
          // Keep in queue for next reconnect
          await Future.delayed(const Duration(seconds: 2)); // slight backoff before continuing next tasks
        }
      }
    }

    _isProcessing = false;
  }
}
