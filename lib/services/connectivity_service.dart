import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';

class ConnectivityService with WidgetsBindingObserver {
  ConnectivityService._() {
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  static final ConnectivityService instance = ConnectivityService._();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  final _controller = StreamController<bool>.broadcast();
  Stream<bool> get onConnectivityChanged => _controller.stream;

  Timer? _pollingTimer;

  void _startPolling() {
    _checkConnectivity();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkConnectivity());
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _checkConnectivity() async {
    bool previousState = _isOnline;
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
      _isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      _isOnline = false;
    }

    if (_isOnline != previousState) {
      _controller.add(_isOnline);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _stopPolling();
    }
  }

  void dispose() {
    _stopPolling();
    WidgetsBinding.instance.removeObserver(this);
    _controller.close();
  }
}
