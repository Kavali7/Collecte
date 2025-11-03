import 'package:connectivity_plus/connectivity_plus.dart';

abstract class ConnectivityService {
  Future<bool> isOnline();
  Stream<bool> get onStatusChanged;
}

class FlutterConnectivityService implements ConnectivityService {
  FlutterConnectivityService(this._connectivity);

  final Connectivity _connectivity;

  @override
  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  @override
  Stream<bool> get onStatusChanged {
    return _connectivity.onConnectivityChanged.map(
      (event) => event != ConnectivityResult.none,
    );
  }
}
