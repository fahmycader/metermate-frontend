import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamController<bool>? _connectionController;
  Stream<bool>? _connectionStream;
  bool _isConnected = true;

  Stream<bool> get connectionStream {
    _connectionController ??= StreamController<bool>.broadcast();
    _connectionStream ??= _connectionController!.stream;
    return _connectionStream!;
  }

  bool get isConnected => _isConnected;

  Future<void> initialize() async {
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _isConnected = _hasConnection(result);
    _connectionController?.add(_isConnected);

    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final connected = _hasConnection(results);
      if (connected != _isConnected) {
        _isConnected = connected;
        _connectionController?.add(_isConnected);
      }
    });
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    // Check if any connection type is available (WiFi, mobile, ethernet, etc.)
    return results.any((result) =>
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet ||
        result == ConnectivityResult.vpn ||
        result == ConnectivityResult.other);
  }

  Future<bool> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _isConnected = _hasConnection(results);
    return _isConnected;
  }

  void dispose() {
    _connectionController?.close();
    _connectionController = null;
    _connectionStream = null;
  }
}

