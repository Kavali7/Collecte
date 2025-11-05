import 'package:flutter_map/flutter_map.dart';

import '../domain/collector_track_point.dart';

class AgentItineraryState {
  AgentItineraryState({
    required this.selectedDate,
    this.points = const [],
    this.geoPoints = const [],
    this.isLoading = false,
    this.errorMessage,
    this.locationErrorMessage,
    this.bounds,
  });

  factory AgentItineraryState.initial() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return AgentItineraryState(selectedDate: today, isLoading: true);
  }

  final DateTime selectedDate;
  final List<CollectorTrackPoint> points;
  final List<CollectorTrackPoint> geoPoints;
  final bool isLoading;
  final String? errorMessage;
  final String? locationErrorMessage;
  final LatLngBounds? bounds;

  bool get hasPoints => points.isNotEmpty;
  bool get hasGeoPoints => geoPoints.isNotEmpty;

  AgentItineraryState copyWith({
    DateTime? selectedDate,
    List<CollectorTrackPoint>? points,
    List<CollectorTrackPoint>? geoPoints,
    bool? isLoading,
    String? errorMessage,
    bool resetError = false,
    String? locationErrorMessage,
    bool resetLocationError = false,
    LatLngBounds? bounds,
    bool clearBounds = false,
  }) {
    return AgentItineraryState(
      selectedDate: selectedDate ?? this.selectedDate,
      points: points ?? this.points,
      geoPoints: geoPoints ?? this.geoPoints,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: resetError ? null : (errorMessage ?? this.errorMessage),
      locationErrorMessage: resetLocationError
          ? null
          : (locationErrorMessage ?? this.locationErrorMessage),
      bounds: clearBounds ? null : (bounds ?? this.bounds),
    );
  }
}
