import 'package:flutter/material.dart';

/// যখন home feed-এ কোনো Waves card tap হয়,
/// সেই video-র URL এখানে set হয়।
/// WavesFeedScreen এটা শুনে সেই video-তে jump করে।
class WavesFeedState {
  WavesFeedState._();

  /// তাৎক্ষণিকভাবে jump করার জন্য requested video URL।
  /// WavesFeedScreen এটা consume করার পর null করে দেয়।
  static final ValueNotifier<String?> requestedVideoUrl =
      ValueNotifier<String?>(null);

  /// Event to skip to the next wave (e.g. from Hide action)
  static final ValueNotifier<bool> skipToNextWave = ValueNotifier<bool>(false);
}
