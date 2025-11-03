import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_service.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final connectivity = Connectivity();
  return FlutterConnectivityService(connectivity);
});
