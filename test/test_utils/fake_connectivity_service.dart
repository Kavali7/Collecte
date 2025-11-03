import 'dart:async';

import 'package:collecte_revendeurs/core/network/connectivity_service.dart';

class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({required bool initiallyOnline})
    : _isOnline = initiallyOnline,
      _controller = StreamController<bool>.broadcast();

  bool _isOnline;
  final StreamController<bool> _controller;

  @override
  Future<bool> isOnline() async => _isOnline;

  @override
  Stream<bool> get onStatusChanged => _controller.stream;

  void setOnline(bool value) {
    if (_isOnline == value) return;
    _isOnline = value;
    _controller.add(value);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
