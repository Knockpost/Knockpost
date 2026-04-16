import 'package:flutter/widgets.dart';

class _PostLockController extends ValueNotifier<bool> {
  _PostLockController() : super(false);

  final Set<ScrollController> _controllers = <ScrollController>{};
  final Map<ScrollPosition, ScrollHoldController> _holds =
      <ScrollPosition, ScrollHoldController>{};
  int _lockCount = 0;

  void register(ScrollController controller) {
    _controllers.add(controller);
    if (value) {
      _holdController(controller);
    }
  }

  void unregister(ScrollController controller) {
    _releaseController(controller);
    _controllers.remove(controller);
  }

  void lock() {
    _lockCount += 1;
    if (_lockCount != 1) return;

    _acquireAllHolds();
    value = true;
  }

  void unlock() {
    if (_lockCount == 0) return;

    _lockCount -= 1;
    if (_lockCount != 0) return;

    _releaseAllHolds();
    value = false;
  }

  void reset() {
    _lockCount = 0;
    _releaseAllHolds();
    if (value) {
      value = false;
    }
  }

  void _acquireAllHolds() {
    for (final controller in _controllers) {
      _holdController(controller);
    }
  }

  void _holdController(ScrollController controller) {
    for (final position in controller.positions) {
      if (_holds.containsKey(position)) continue;
      _holds[position] = position.hold(_handleHoldCanceled);
    }
  }

  void _releaseController(ScrollController controller) {
    for (final position in controller.positions.toList(growable: false)) {
      final hold = _holds.remove(position);
      hold?.cancel();
    }
  }

  void _releaseAllHolds() {
    final holds = _holds.values.toList(growable: false);
    _holds.clear();
    for (final hold in holds) {
      hold.cancel();
    }
  }

  void _handleHoldCanceled() {}

  @override
  void dispose() {
    reset();
    super.dispose();
  }
}

class PostScrollLockController extends _PostLockController {
  PostScrollLockController();
}

class PostPageSwipeLockController extends _PostLockController {
  PostPageSwipeLockController();
}

class PostScrollLockScope extends InheritedWidget {
  final PostScrollLockController controller;

  const PostScrollLockScope({
    super.key,
    required this.controller,
    required super.child,
  });

  static PostScrollLockController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<PostScrollLockScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(PostScrollLockScope oldWidget) {
    return controller != oldWidget.controller;
  }
}

class PostPageSwipeLockScope extends InheritedWidget {
  final PostPageSwipeLockController controller;

  const PostPageSwipeLockScope({
    super.key,
    required this.controller,
    required super.child,
  });

  static PostPageSwipeLockController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<PostPageSwipeLockScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(PostPageSwipeLockScope oldWidget) {
    return controller != oldWidget.controller;
  }
}
