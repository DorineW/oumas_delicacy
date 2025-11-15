import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

abstract class ConnectivityProviderBase {
  void retry();
  bool get isConnected;
  Stream<bool> get connectionStream;
}

class ConnectivityProvider extends ChangeNotifier
    implements ConnectivityProviderBase {
  final Connectivity _connectivity = Connectivity();
  bool _isConnected = true;
  
  @override
  bool get isConnected => _isConnected;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  
  @override
  Stream<bool> get connectionStream => _controller.stream;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  ConnectivityProvider() {
    _init();
  }

  Future<void> _init() async {
    final result = await _connectivity.checkConnectivity();
    _updateStatus(result);
    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final connected = results.isNotEmpty && !results.every((r) => r == ConnectivityResult.none);
    if (connected != _isConnected) {
      _isConnected = connected;
      _controller.add(_isConnected);
      notifyListeners();
      debugPrint('📡 Connectivity changed: ${_isConnected ? "ONLINE" : "OFFLINE"}');
    }
  }

  @override
  Future<void> retry() async {
    debugPrint('🔄 Retrying connectivity check...');
    final result = await _connectivity.checkConnectivity();
    _updateStatus(result);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.close();
    super.dispose();
  }
}
