import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/location/location_providers.dart';
import '../../../core/location/location_service.dart';
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
    required String? collectorId,
    Duration syncInterval = const Duration(minutes: 5),
    DateTime Function()? clock,
    StopDetector? stopDetector,
  }) : _repository = repository,
       _locationService = locationService,
       _collectorId = collectorId,
       _syncInterval = syncInterval,
       _clock = clock ?? DateTime.now,
       _stopDetector =
           stopDetector ?? StopDetector(clock: clock ?? DateTime.now),
       super(const CollectorTrackRecorderState()) {
    _boot();
  }

  final CollectorTrackRepository _repository;
  final LocationService _locationService;
  final String? _collectorId;
  final Duration _syncInterval;
  final DateTime Function() _clock;
  final StopDetector _stopDetector;
  final Uuid _uuid = const Uuid();

  StreamSubscription<DeviceLocation>? _locationSubscription;
  Timer? _syncTimer;
  Future<void> _recordingChain = Future.value();
  Future<void>? _syncFuture;
  bool _initialized = false;

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
    final point = CollectorTrackPoint(
      id: 'local-${_uuid.v4()}',
      quartier: 'Quartier inconnu',
      latitude: stopEvent.latitude,
      longitude: stopEvent.longitude,
      timestamp: stopEvent.arrivedAt,
    );
    try {
      await _repository.enqueuePoint(collectorId: collectorId, point: point);
      await _refreshPendingCount();
      if (!mounted) return;
      state = state.copyWith(resetError: true, resetLocationFailure: true);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(errorMessage: 'Erreur reseau/permissions');
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
      final authState = ref.watch(authControllerProvider);
      final firebaseAuth = ref.watch(firebaseAuthProvider);
      final collectorId = authState.isAuthenticated
          ? firebaseAuth.currentUser?.uid
          : null;
      return CollectorTrackRecorder(
        repository: repository,
        locationService: locationService,
        collectorId: collectorId,
      );
    });
