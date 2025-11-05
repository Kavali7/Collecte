import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../auth/controllers/auth_controller.dart';
import '../data/collector_track_repository.dart';
import '../data/firestore_collector_track_repository.dart';
import '../domain/collector_track_point.dart';
import 'agent_itinerary_state.dart';

class AgentItineraryController
    extends StateNotifier<AgentItineraryState> {
  AgentItineraryController({
    required CollectorTrackRepository repository,
    required String? collectorId,
  })  : _repository = repository,
        _collectorId = collectorId,
        super(AgentItineraryState.initial());

  final CollectorTrackRepository _repository;
  final String? _collectorId;

  StreamSubscription<List<CollectorTrackPoint>>? _tracksSubscription;
  bool _hasInitialized = false;

  Future<void> initialize() async {
    if (_hasInitialized) return;
    _hasInitialized = true;
    await loadForDate(state.selectedDate);
  }

  Future<void> changeDate(DateTime date) async {
    await loadForDate(date);
  }

  Future<void> loadForDate(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    final collectorId = _collectorId;

    if (collectorId == null || collectorId.isEmpty) {
      state = state.copyWith(
        selectedDate: normalized,
        points: const [],
        geoPoints: const [],
        isLoading: false,
        errorMessage: 'Utilisateur non authentifie.',
        clearBounds: true,
      );
      return;
    }

    await _tracksSubscription?.cancel();
    state = state.copyWith(
      selectedDate: normalized,
      isLoading: true,
      resetError: true,
      resetLocationError: true,
      points: const [],
      geoPoints: const [],
      clearBounds: true,
    );

    _tracksSubscription = _repository
        .watchTrackPoints(collectorId: collectorId, date: normalized)
        .listen(
      (points) {
        final sorted = [...points]
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        final geoPoints = sorted
            .where(
              (point) =>
                  point.latitude.isFinite && point.longitude.isFinite,
            )
            .toList();
        final hasMissing = geoPoints.length != sorted.length;
        final bounds = _computeBounds(geoPoints);
        state = state.copyWith(
          points: sorted,
          geoPoints: geoPoints,
          bounds: bounds,
          isLoading: false,
          resetError: true,
          locationErrorMessage: hasMissing
              ? 'Certains points manquent de coordonnees GPS.'
              : null,
          resetLocationError: !hasMissing,
        );
      },
      onError: (_) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Erreur de synchronisation des trajets.',
          resetError: false,
        );
      },
    );
  }

  LatLngBounds? _computeBounds(List<CollectorTrackPoint> points) {
    if (points.isEmpty) return null;
    // Le calcul de bounding box s'appuie sur les min/max pour recentrer la carte
    // sur l'ensemble du trajet sans zoom manuel.
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
  }

  @override
  void dispose() {
    _tracksSubscription?.cancel();
    super.dispose();
  }
}

final agentItineraryControllerProvider = StateNotifierProvider.autoDispose<
    AgentItineraryController, AgentItineraryState>((ref) {
  final repository = ref.watch(collectorTrackRepositoryProvider);
  final authState = ref.watch(authControllerProvider);
  final collectorId = authState.isAuthenticated ? authState.userId : null;
  final controller = AgentItineraryController(
    repository: repository,
    collectorId: collectorId,
  );
  controller.initialize();
  return controller;
});
