import 'package:latlong2/latlong.dart';

import '../../../core/location/location_service.dart';

/// Radius (in meters) used to decide whether the collector is still within
/// the same stop.
const double kStopRadiusMeters = 15;

/// Minimum duration the collector must stay within [kStopRadiusMeters] for a
/// stop to be considered valid.
const Duration kStopMinDuration = Duration(minutes: 3);

class StopEvent {
  const StopEvent({
    required this.latitude,
    required this.longitude,
    required this.arrivedAt,
    required this.confirmedAt,
  });

  final double latitude;
  final double longitude;
  final DateTime arrivedAt;
  final DateTime confirmedAt;
}

class StopDetector {
  StopDetector({
    this.radiusMeters = kStopRadiusMeters,
    this.minDuration = kStopMinDuration,
    DateTime Function()? clock,
    Distance? distanceCalculator,
  }) : _clock = clock ?? DateTime.now,
       _distance = distanceCalculator ?? const Distance();

  final double radiusMeters;
  final Duration minDuration;
  final DateTime Function() _clock;
  final Distance _distance;

  _StopCandidate? _candidate;

  StopEvent? register(DeviceLocation location) {
    final now = _clock();
    final candidate = _candidate;

    if (candidate == null) {
      _candidate = _StopCandidate(
        latitude: location.latitude,
        longitude: location.longitude,
        startedAt: now,
        lastSeenAt: now,
        hasReported: false,
      );
      return null;
    }

    final meters = _distance(
      LatLng(candidate.latitude, candidate.longitude),
      LatLng(location.latitude, location.longitude),
    );

    if (meters > radiusMeters) {
      _candidate = _StopCandidate(
        latitude: location.latitude,
        longitude: location.longitude,
        startedAt: now,
        lastSeenAt: now,
        hasReported: false,
      );
      return null;
    }

    final updated = candidate.copyWith(lastSeenAt: now);
    _candidate = updated;

    if (updated.hasReported) return null;

    final stableDuration = now.difference(updated.startedAt);
    if (stableDuration >= minDuration) {
      final event = StopEvent(
        latitude: updated.latitude,
        longitude: updated.longitude,
        arrivedAt: updated.startedAt,
        confirmedAt: now,
      );
      _candidate = updated.copyWith(hasReported: true);
      return event;
    }

    return null;
  }

  void reset() {
    _candidate = null;
  }
}

class _StopCandidate {
  const _StopCandidate({
    required this.latitude,
    required this.longitude,
    required this.startedAt,
    required this.lastSeenAt,
    required this.hasReported,
  });

  final double latitude;
  final double longitude;
  final DateTime startedAt;
  final DateTime lastSeenAt;
  final bool hasReported;

  _StopCandidate copyWith({
    double? latitude,
    double? longitude,
    DateTime? startedAt,
    DateTime? lastSeenAt,
    bool? hasReported,
  }) {
    return _StopCandidate(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      startedAt: startedAt ?? this.startedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      hasReported: hasReported ?? this.hasReported,
    );
  }
}
