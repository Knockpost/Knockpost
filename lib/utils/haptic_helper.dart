import 'package:flutter/services.dart';

/// Centralized haptic feedback helper for Knockpost.
/// Mirrors the haptic patterns used by Instagram, Facebook, X, and Substack.
class KnockHaptics {
  KnockHaptics._();

  /// Light tap — buttons, nav items, icon taps, send, toggles.
  static void tap() => HapticFeedback.lightImpact();

  /// Medium impact — reactions, double-tap like, threshold events, long-press open.
  static void impact() => HapticFeedback.mediumImpact();

  /// Selection tick — hovering over emoji/options during drag, toggling states.
  static void selection() => HapticFeedback.selectionClick();

  /// Heavy impact — destructive actions (delete, remove).
  static void heavy() => HapticFeedback.heavyImpact();

  /// Full vibrate — error states.
  static void vibrate() => HapticFeedback.vibrate();
}
