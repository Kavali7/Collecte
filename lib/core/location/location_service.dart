import 'package:geolocator/geolocator.dart';

class DeviceLocation {
  const DeviceLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

enum LocationFailureType {
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
  unknown,
}

class LocationFailure {
  const LocationFailure({required this.type, required this.message});

  final LocationFailureType type;
  final String message;
}

class LocationResult {
  const LocationResult._({this.location, this.failure});

  const LocationResult.success(DeviceLocation location)
    : this._(location: location);

  const LocationResult.failure(LocationFailure failure)
    : this._(failure: failure);

  final DeviceLocation? location;
  final LocationFailure? failure;

  bool get hasLocation => location != null;
  bool get hasFailure => failure != null;
}

abstract class LocationService {
  Future<LocationResult> getCurrentLocation();
  Stream<DeviceLocation> watchPosition();
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  static const _serviceDisabledMessage =
      'Le service de localisation est desactive. Active le GPS du telephone puis reessaye.';
  static const _permissionDeniedMessage =
      'Autorisation localisation indisponible. Active-la dans les reglages et reessaie.';
  static const _genericErrorMessage =
      'Impossible de recuperer la localisation actuelle.';

  @override
  Future<LocationResult> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult.failure(
          LocationFailure(
            type: LocationFailureType.serviceDisabled,
            message: _serviceDisabledMessage,
          ),
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return const LocationResult.failure(
          LocationFailure(
            type: LocationFailureType.permissionDenied,
            message: _permissionDeniedMessage,
          ),
        );
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult.failure(
          LocationFailure(
            type: LocationFailureType.permissionPermanentlyDenied,
            message: _permissionDeniedMessage,
          ),
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return LocationResult.success(
        DeviceLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    } catch (_) {
      return const LocationResult.failure(
        LocationFailure(
          type: LocationFailureType.unknown,
          message: _genericErrorMessage,
        ),
      );
    }
  }

  @override
  Stream<DeviceLocation> watchPosition() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).map(
      (position) => DeviceLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      ),
    );
  }
}
