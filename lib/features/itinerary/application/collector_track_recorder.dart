import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/location/location_constants.dart';
import '../../../core/location/location_providers.dart';
import '../../../core/location/location_service.dart';
import '../../../core/location/quartier_resolver.dart';
import '../../../core/location/reverse_geocoding_cache.dart';
import '../../auth/controllers/auth_controller.dart';
import '../data/collector_track_repository.dart';
import '../data/firestore_collector_track_repository.dart';
import '../domain/collector_track_point.dart';
import 'collector_track_recorder_state.dart';
import 'stop_detector.dart';

class CollectorTrackRecorder
    extends StateNotifier<CollectorTrackRecorderState> {
  CollectorTrackRecorder({
    required CollectorTrackRepository repository,
    required LocationService locationService,
    required QuartierResolver quartierResolver,
    required String? collectorId,
    Duration syncInterval = const Duration(minutes: 5),
    DateTime Function()? clock,
    StopDetector? stopDetector,
    Duration reverseGeocodeRetryDelay = const Duration(seconds: 30),
    int reverseGeocodeMaxAttempts = 3,
    int reverseGeocodeBatchSize = 4,
  }) : _repository = repository,
       _locationService = locationService,
       _quartierResolver = quartierResolver,
       _collectorId = collectorId,
       _syncInterval = syncInterval,
       _clock = clock ?? DateTime.now,
       _stopDetector =
           stopDetector ?? StopDetector(clock: clock ?? DateTime.now),
       _reverseGeocodeRetryDelay = reverseGeocodeRetryDelay,
       _reverseGeocodeMaxAttempts = reverseGeocodeMaxAttempts,
       _reverseGeocodeBatchSize = reverseGeocodeBatchSize,
       super(const CollectorTrackRecorderState()) {
    _boot();
  }

  final CollectorTrackRepository _repository;
  final LocationService _locationService;
  final QuartierResolver _quartierResolver;
  final String? _collectorId;
  final Duration _syncInterval;
  final DateTime Function() _clock;
  final StopDetector _stopDetector;
  final Duration _reverseGeocodeRetryDelay;
  final int _reverseGeocodeMaxAttempts;
  final int _reverseGeocodeBatchSize;
  final Uuid _uuid = const Uuid();
  final Queue<_PendingQuartierRetry> _quartierRetryQueue = Queue();
  final Set<String> _quartierRetryIds = <String>{};

  StreamSubscription<DeviceLocation>? _locationSubscription;
  Timer? _syncTimer;
  Future<void> _recordingChain = Future.value();
  Future<void>? _syncFuture;
  bool _initialized = false;
  bool _quartierRetryActive = false;
  bool _stopRetryWorker = false;

  void _boot() {
    Future.microtask(_initialize);
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (_activeCollectorId == null) return;
    await _refreshPendingCount();
    await _ensurePermissions();
    _startLocationStream();
    await syncNow();
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) {
      syncNow();
    });
  }

  Future<void> _ensurePermissions() async {
    try {
      final result = await _locationService.getCurrentLocation();
      if (!mounted) return;
      if (result.hasFailure && result.failure != null) {
        state = state.copyWith(
          locationFailure: result.failure!.type,
          errorMessage: result.failure!.message,
        );
      } else if (result.hasLocation) {
        state = state.copyWith(resetLocationFailure: true, resetError: true);
      }
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(errorMessage: 'Erreur reseau/permissions');
    }
  }

  void _startLocationStream() {
    if (_activeCollectorId == null) return;
    _locationSubscription?.cancel();
    _stopDetector.reset();
    _locationSubscription = _locationService.watchPosition().listen(
      (location) {
        _recordingChain = _recordingChain.then((_) => _recordSample(location));
      },
      onError: (error) {
        if (!mounted) return;
        state = state.copyWith(
          errorMessage: 'Erreur reseau/permissions',
          locationFailure: error is LocationFailure
              ? error.type
              : LocationFailureType.unknown,
          isTracking: false,
        );
      },
    );
    if (mounted) {
      state = state.copyWith(
        isTracking: true,
        resetLocationFailure: true,
        resetError: true,
      );
    }
  }

  Future<void> _recordSample(DeviceLocation location) async {
    final collectorId = _activeCollectorId;
    if (collectorId == null) return;
    final stopEvent = _stopDetector.register(location);
    if (stopEvent == null) return;
    final resolution = await _resolveQuartier(
      latitude: stopEvent.latitude,
      longitude: stopEvent.longitude,
    );
    final localId = 'local-${_uuid.v4()}';
    final point = CollectorTrackPoint(
      id: localId,
      quartier: resolution.label,
      latitude: stopEvent.latitude,
      longitude: stopEvent.longitude,
      timestamp: stopEvent.arrivedAt,
    );
    try {
      await _repository.enqueuePoint(collectorId: collectorId, point: point);
      await _refreshPendingCount();
      if (!resolution.isResolved) {
        _scheduleQuartierRetry(
          collectorId: collectorId,
          localId: localId,
          latitude: stopEvent.latitude,
          longitude: stopEvent.longitude,
        );
      }
      if (!mounted) return;
      state = state.copyWith(resetError: true, resetLocationFailure: true);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(errorMessage: 'Erreur reseau/permissions');
    }
  }

  Future<QuartierResolution> _resolveQuartier({
    required double latitude,
    required double longitude,
  }) async {
    try {
      return await _quartierResolver.resolve(
        latitude: latitude,
        longitude: longitude,
      );
    } catch (_) {
      return const QuartierResolution.unknown();
    }
  }

  void _scheduleQuartierRetry({
    required String collectorId,
    required String localId,
    required double latitude,
    required double longitude,
  }) {
    if (_stopRetryWorker) return;
    if (!_quartierRetryIds.add(localId)) return;
    _quartierRetryQueue.add(
      _PendingQuartierRetry(
        collectorId: collectorId,
        localId: localId,
        latitude: latitude,
        longitude: longitude,
        attempts: 0,
      ),
    );
    if (_quartierRetryActive) return;
    _quartierRetryActive = true;
    _processQuartierRetryQueue();
  }

  Future<void> _processQuartierRetryQueue() async {
    while (_quartierRetryQueue.isNotEmpty && !_stopRetryWorker && mounted) {
      final batch = <_PendingQuartierRetry>[];
      while (batch.length < _reverseGeocodeBatchSize &&
          _quartierRetryQueue.isNotEmpty) {
        batch.add(_quartierRetryQueue.removeFirst());
      }
      if (_reverseGeocodeRetryDelay > Duration.zero) {
        await Future.delayed(_reverseGeocodeRetryDelay);
      }
      final coordinates = batch
          .map(
            (job) => ReverseGeocodingCoordinate(
              latitude: job.latitude,
              longitude: job.longitude,
            ),
          )
          .toList(growable: false);
      List<QuartierResolution> resolutions;
      try {
        resolutions = await _quartierResolver.resolveBatch(coordinates);
      } catch (_) {
        resolutions = List<QuartierResolution>.filled(
          batch.length,
          const QuartierResolution.unknown(),
          growable: false,
        );
      }
      for (var i = 0; i < batch.length; i++) {
        final job = batch[i];
        final resolution = i < resolutions.length
            ? resolutions[i]
            : const QuartierResolution.unknown();
        if (_stopRetryWorker || !mounted) {
          _quartierRetryIds.remove(job.localId);
          continue;
        }
        if (job.collectorId != _activeCollectorId) {
          _quartierRetryIds.remove(job.localId);
          continue;
        }
        final resolved = await _attemptQuartierUpdate(job, resolution);
        if (!resolved) {
          final nextAttempts = job.attempts + 1;
          if (nextAttempts < _reverseGeocodeMaxAttempts) {
            _quartierRetryQueue.add(job.copyWith(attempts: nextAttempts));
          } else {
            _quartierRetryIds.remove(job.localId);
          }
        }
      }
    }
    _quartierRetryActive = false;
  }

  Future<bool> _attemptQuartierUpdate(
    _PendingQuartierRetry job,
    QuartierResolution resolution,
  ) async {
    try {
      if (!resolution.isResolved) {
        return false;
      }
      final label = resolution.label.trim();
      if (label.isEmpty || label == kUnknownQuartierLabel) {
        return false;
      }
      await _repository.updateQuartier(
        collectorId: job.collectorId,
        localId: job.localId,
        quartier: label,
      );
      _quartierRetryIds.remove(job.localId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _refreshPendingCount() async {
    final collectorId = _activeCollectorId;
    if (collectorId == null) return;
    final pending = await _repository.pendingCount(collectorId: collectorId);
    if (!mounted) return;
    state = state.copyWith(pendingPoints: pending);
  }

  Future<void> syncNow() {
    final collectorId = _activeCollectorId;
    if (collectorId == null) return Future.value();
    if (_syncFuture != null) return _syncFuture!;
    final future = _performSync(collectorId);
    _syncFuture = future;
    future.whenComplete(() => _syncFuture = null);
    return future;
  }

  Future<void> _performSync(String collectorId) async {
    if (mounted) {
      state = state.copyWith(isSyncing: true, resetError: true);
    }
    try {
      final results = await _repository.syncPending(collectorId: collectorId);
      for (final result in results) {
        await _repository.markSynced(collectorId: collectorId, result: result);
      }
      await _refreshPendingCount();
      if (!mounted) return;
      state = state.copyWith(isSyncing: false, lastSyncAt: _clock());
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        isSyncing: false,
        errorMessage: 'Erreur reseau pendant la synchronisation.',
      );
    }
  }

  String? get _activeCollectorId {
    final id = _collectorId;
    if (id == null || id.isEmpty) return null;
    return id;
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _locationSubscription?.cancel();
    _stopRetryWorker = true;
    _quartierRetryQueue.clear();
    _quartierRetryIds.clear();
    syncNow();
    super.dispose();
  }
}

final collectorTrackRecorderProvider =
    StateNotifierProvider<CollectorTrackRecorder, CollectorTrackRecorderState>((
      ref,
    ) {
      final repository = ref.watch(collectorTrackRepositoryProvider);
      final locationService = ref.watch(locationServiceProvider);
      final quartierResolver = ref.watch(quartierResolverProvider);
      final authState = ref.watch(authControllerProvider);
      final firebaseAuth = ref.watch(firebaseAuthProvider);
      final collectorId = authState.isAuthenticated
          ? firebaseAuth.currentUser?.uid
          : null;
      return CollectorTrackRecorder(
        repository: repository,
        locationService: locationService,
        quartierResolver: quartierResolver,
        collectorId: collectorId,
      );
    });

class _PendingQuartierRetry {
  const _PendingQuartierRetry({
    required this.collectorId,
    required this.localId,
    required this.latitude,
    required this.longitude,
    required this.attempts,
  });

  final String collectorId;
  final String localId;
  final double latitude;
  final double longitude;
  final int attempts;

  _PendingQuartierRetry copyWith({int? attempts}) {
    return _PendingQuartierRetry(
      collectorId: collectorId,
      localId: localId,
      latitude: latitude,
      longitude: longitude,
      attempts: attempts ?? this.attempts,
    );
  }
}
