import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/location/location_constants.dart';
import '../../../core/location/locationiq_reverse_geocoding.dart';
import '../../../core/location/reverse_geocoding_cache.dart';
import '../../../core/location/location_providers.dart';
import '../../auth/controllers/auth_controller.dart';
import '../data/collector_track_repository.dart';
import '../data/firestore_collector_track_repository.dart';
import '../domain/collector_track_point.dart';
import 'agent_itinerary_state.dart';

class AgentItineraryController extends StateNotifier<AgentItineraryState> {
  AgentItineraryController({
    required CollectorTrackRepository repository,
    required ReverseGeocodingCache reverseGeocodingCache,
    required String? collectorId,
  }) : _repository = repository,
       _reverseGeocodingCache = reverseGeocodingCache,
       _collectorId = collectorId,
       super(AgentItineraryState.initial());

  final CollectorTrackRepository _repository;
  final ReverseGeocodingCache _reverseGeocodingCache;
  final String? _collectorId;

  StreamSubscription<List<CollectorTrackPoint>>? _tracksSubscription;
  Future<void>? _quartierResolveChain;
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
            unawaited(_resolveMissingQuartiers(sorted));
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

    return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
  }

  Future<void> _resolveMissingQuartiers(
    List<CollectorTrackPoint> points,
  ) async {
    final collectorId = _collectorId;
    if (collectorId == null || collectorId.isEmpty) return;
    final pendingPoints = <CollectorTrackPoint>[];
    final coordinates = <ReverseGeocodingCoordinate>[];
    for (final point in points) {
      if (_needsQuartierResolution(point)) {
        pendingPoints.add(point);
        coordinates.add(
          ReverseGeocodingCoordinate(
            latitude: point.latitude,
            longitude: point.longitude,
          ),
        );
      }
    }
    if (pendingPoints.isEmpty) return;
    _quartierResolveChain = (_quartierResolveChain ?? Future.value()).then(
      (_) => _performQuartierResolution(
        collectorId: collectorId,
        pendingPoints: pendingPoints,
        coordinates: coordinates,
      ),
    );
    await _quartierResolveChain;
  }

  Future<void> _performQuartierResolution({
    required String collectorId,
    required List<CollectorTrackPoint> pendingPoints,
    required List<ReverseGeocodingCoordinate> coordinates,
  }) async {
    List<ReverseGeocodingAddress?> addresses;
    try {
      addresses = await _reverseGeocodingCache.resolveBatch(coordinates);
    } catch (_) {
      return;
    }
    if (addresses.length != pendingPoints.length) return;
    final currentPoints = [...state.points];
    var hasUpdates = false;
    final updateFutures = <Future<void>>[];
    for (var i = 0; i < pendingPoints.length; i++) {
      final address = addresses[i];
      if (address == null) continue;
      final normalized = _normalizeQuartier(address);
      if (normalized == null) continue;
      final targetId = pendingPoints[i].id;
      final index = currentPoints.indexWhere((point) => point.id == targetId);
      if (index == -1) continue;
      if (currentPoints[index].quartier == normalized) continue;
      currentPoints[index] = currentPoints[index].copyWith(
        quartier: normalized,
      );
      hasUpdates = true;
      updateFutures.add(
        _repository.updateQuartier(
          collectorId: collectorId,
          localId: targetId,
          quartier: normalized,
        ),
      );
    }
    if (hasUpdates && mounted) {
      state = state.copyWith(points: currentPoints);
    }
    if (updateFutures.isNotEmpty) {
      try {
        await Future.wait(updateFutures, eagerError: false);
      } catch (_) {}
    }
  }

  bool _needsQuartierResolution(CollectorTrackPoint point) {
    final label = point.quartier.trim();
    return label.isEmpty || label == kUnknownQuartierLabel;
  }

  String? _normalizeQuartier(ReverseGeocodingAddress address) {
    final label = resolveQuartierLabelOrFallback(address).trim();
    if (label.isEmpty || label == kUnknownQuartierLabel) {
      return null;
    }
    return label;
  }

  @override
  void dispose() {
    _tracksSubscription?.cancel();
    super.dispose();
  }
}

final agentItineraryControllerProvider =
    StateNotifierProvider.autoDispose<
      AgentItineraryController,
      AgentItineraryState
    >((ref) {
      final repository = ref.watch(collectorTrackRepositoryProvider);
      final reverseGeocodingCache = ref.watch(reverseGeocodingCacheProvider);
      final authState = ref.watch(authControllerProvider);
      final collectorId = authState.isAuthenticated ? authState.userId : null;
      final controller = AgentItineraryController(
        repository: repository,
        reverseGeocodingCache: reverseGeocodingCache,
        collectorId: collectorId,
      );
      controller.initialize();
      return controller;
    });
