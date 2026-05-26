import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'knock_state_manager.dart';

class GlobalKnockState {
  static ValueNotifier<KnockStatus> getNotifier(String userId, KnockStatus initial) {
    return KnockStateManager.instance.getNotifier(userId, initial);
  }
}
