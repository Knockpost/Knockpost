import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class GlobalKnockState {
  static final Map<String, ValueNotifier<KnockStatus>> _notifiers = {};

  static ValueNotifier<KnockStatus> getNotifier(String userId, KnockStatus initial) {
    if (!_notifiers.containsKey(userId)) {
      _notifiers[userId] = ValueNotifier<KnockStatus>(initial);
    }
    return _notifiers[userId]!;
  }
}
