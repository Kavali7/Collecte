import 'dart:async';

import 'package:collecte_revendeurs/core/location/location_service.dart';

class FakeLocationService implements LocationService {
  FakeLocationService({LocationResult? initialResult})
    : _nextResult =
          initialResult ??
          const LocationResult.failure(
            LocationFailure(
              type: LocationFailureType.unknown,
              message: 'Location not configured',
            ),
          ),
      _controller = StreamController<DeviceLocation>.broadcast();

  LocationResult _nextResult;
  final StreamController<DeviceLocation> _controller;

  @override
  Future<LocationResult> getCurrentLocation() async => _nextResult;

  @override
  Stream<DeviceLocation> watchPosition() => _controller.stream;

  void setNextResult(LocationResult result) {
    _nextResult = result;
  }

  void emitLocation(DeviceLocation location) {
    _controller.add(location);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
