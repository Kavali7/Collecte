import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/network/connectivity_providers.dart';
import '../../../core/location/location_providers.dart';
import '../../../core/location/location_service.dart';
import '../data/boutique_repository.dart';
import '../data/cache/boutique_cache_store.dart';
import '../data/firebase_boutique_repository.dart';
import '../domain/boutique.dart';
import '../domain/day_range.dart';
import 'boutique_map_state.dart';

class BoutiqueMapController extends StateNotifier<BoutiqueMapState> {
  BoutiqueMapController({
    required BoutiqueRepository repository,
    required BoutiqueCacheStore cacheStore,
    required ConnectivityService connectivityService,
    required LocationService locationService,
    required String? collectorId,
    DateTime Function()? clock,
  }) : _repository = repository,
       _cacheStore = cacheStore,
       _connectivityService = connectivityService,
       _locationService = locationService,
       _collectorId = collectorId,
       _clock = clock ?? DateTime.now,
       _currentDay = DayRange.normalize((clock ?? DateTime.now)()),
       super(const BoutiqueMapState.initial());

  final BoutiqueRepository _repository;
  final BoutiqueCacheStore _cacheStore;
  final ConnectivityService _connectivityService;
  final LocationService _locationService;
  final String? _collectorId;
  final DateTime Function() _clock;
  DateTime _currentDay;

  StreamSubscription<bool>? _connectivitySub;
  StreamSubscription<DeviceLocation>? _userLocationSub;

  Future<void> initialize() async {
    final filterDate = _refreshFilterDate();
    final collectorId = _collectorId;
    if (collectorId == null || collectorId.isEmpty) {
      state = state.copyWith(
        boutiques: const [],
        isLoading: false,
        isOffline: false,
        resetError: true,
      );
      return;
    }

    final cached = await _cacheStore.load(forDate: filterDate);
    final isOnline = await _connectivityService.isOnline();
    state = state.copyWith(
      boutiques: cached,
      isLoading: cached.isEmpty,
      isOffline: !isOnline,
      resetError: true,
    );

    _connectivitySub ??= _connectivityService.onStatusChanged.listen(
      _onConnectivityChanged,
    );

    if (isOnline) {
      await _refreshFromRemote(
        collectorId: collectorId,
        targetDate: filterDate,
        showLoading: cached.isEmpty,
      );
    } else {
      state = state.copyWith(isLoading: false);
    }

    await refreshUserLocation();
  }

  Future<void> sync() async {
    final collectorId = _collectorId;
    final filterDate = _refreshFilterDate();
    if (collectorId == null || collectorId.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Utilisateur non authentifie.',
        resetError: false,
      );
      return;
    }
    final isOnline = await _connectivityService.isOnline();
    if (!isOnline) {
      state = state.copyWith(
        errorMessage: 'Synchronisation impossible hors connexion.',
        resetError: false,
      );
      return;
    }

    state = state.copyWith(isSyncing: true, resetError: true);
    try {
      await _pushPending();
      await _refreshFromRemote(
        collectorId: collectorId,
        targetDate: filterDate,
        showLoading: false,
      );
    } catch (_) {
      state = state.copyWith(
        errorMessage: 'Une erreur est survenue pendant la synchronisation.',
        resetError: false,
      );
    } finally {
      state = state.copyWith(isSyncing: false);
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _userLocationSub?.cancel();
    super.dispose();
  }

  Future<void> refreshUserLocation() async {
    state = state.copyWith(isLocatingUser: true, resetLocationError: true);

    final result = await _locationService.getCurrentLocation();
    if (result.hasLocation && result.location != null) {
      state = state.copyWith(
        userLocation: result.location,
        isLocatingUser: false,
        resetLocationError: true,
      );
      _startUserLocationStream();
    } else if (result.failure != null) {
      state = state.copyWith(
        isLocatingUser: false,
        locationErrorMessage: result.failure!.message,
        clearUserLocation: true,
        resetLocationError: false,
      );
    } else {
      state = state.copyWith(isLocatingUser: false);
    }
  }

  Future<void> _refreshFromRemote({
    required String collectorId,
    required DateTime targetDate,
    required bool showLoading,
  }) async {
    if (showLoading) {
      state = state.copyWith(isLoading: true, resetError: true);
    }
    try {
      final remote = await _repository.loadBoutiques(
        collectorId,
        forDate: targetDate,
      );
      final merged = await _mergeWithLocalPending(remote, targetDate);
      await _cacheStore.saveAll(merged);
      state = state.copyWith(
        boutiques: merged,
        isLoading: false,
        resetError: true,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de recuperer les donnees distantes.',
        resetError: false,
      );
    }
  }

  Future<void> _pushPending() async {
    final cached = await _cacheStore.load();
    if (cached.isEmpty) return;

    final pending = cached
        .where((boutique) => boutique.syncStatus != SyncStatus.synced)
        .toList();
    if (pending.isEmpty) return;

    final updated = [...cached];
    var hasChanges = false;

    for (final boutique in pending) {
      try {
        Boutique saved;
        if (boutique.id.isEmpty || boutique.id.startsWith('local-')) {
          saved = await _repository.create(boutique.copyWith(id: ''));
        } else {
          saved = await _repository.update(boutique);
        }
        final normalized = saved.copyWith(syncStatus: SyncStatus.synced);

        final index = updated.indexWhere(
          (element) => element.id == boutique.id,
        );
        if (index != -1) {
          updated[index] = normalized;
        } else {
          updated.add(normalized);
        }
        hasChanges = true;
      } catch (_) {
        final index = updated.indexWhere(
          (element) => element.id == boutique.id,
        );
        if (index != -1) {
          updated[index] = boutique.copyWith(syncStatus: SyncStatus.error);
          hasChanges = true;
        }
      }
    }

    if (hasChanges) {
      await _cacheStore.saveAll(updated);
      state = state.copyWith(boutiques: updated, resetError: true);
    }
  }

  Future<List<Boutique>> _mergeWithLocalPending(
    List<Boutique> remote,
    DateTime targetDate,
  ) async {
    final cached = await _cacheStore.load(forDate: targetDate);
    if (cached.isEmpty) {
      return remote
          .map((boutique) => boutique.copyWith(syncStatus: SyncStatus.synced))
          .toList();
    }

    final remoteIds = remote.map((item) => item.id).toSet();
    final remoteSynced = remote
        .map((boutique) => boutique.copyWith(syncStatus: SyncStatus.synced))
        .toList();

    final pending = cached.where((boutique) {
      final isPending = boutique.syncStatus != SyncStatus.synced;
      final missingRemote = !remoteIds.contains(boutique.id);
      return isPending && missingRemote;
    }).toList();

    return [...remoteSynced, ...pending];
  }

  void _onConnectivityChanged(bool isOnline) {
    state = state.copyWith(isOffline: !isOnline);
  }

  void _startUserLocationStream() {
    _userLocationSub ??= _locationService.watchPosition().listen(
      (location) {
        state = state.copyWith(
          userLocation: location,
          resetLocationError: true,
        );
      },
      onError: (_) {
        state = state.copyWith(locationErrorMessage: 'Suivi GPS indisponible.');
      },
    );
  }

  DateTime _refreshFilterDate() {
    final today = DayRange.normalize(_clock());
    if (!DayRange.isSameDay(today, _currentDay)) {
      _currentDay = today;
      _pruneStateForCurrentDay();
    }
    return _currentDay;
  }

  void _pruneStateForCurrentDay() {
    final range = DayRange(_currentDay);
    final filtered = state.boutiques
        .where((boutique) => range.contains(boutique.submittedAt))
        .toList();
    if (filtered.length != state.boutiques.length) {
      state = state.copyWith(boutiques: filtered);
    }
  }
}

final boutiqueMapControllerProvider =
    StateNotifierProvider.autoDispose<BoutiqueMapController, BoutiqueMapState>((
      ref,
    ) {
      final authState = ref.watch(authControllerProvider);
      final firebaseAuth = ref.watch(firebaseAuthProvider);
      final collectorId =
          authState.isAuthenticated ? firebaseAuth.currentUser?.uid : null;
      final repository = ref.watch(boutiqueRepositoryProvider);
      final cacheStore = ref.watch(boutiqueCacheStoreProvider);
      final connectivityService = ref.watch(connectivityServiceProvider);
      final locationService = ref.watch(locationServiceProvider);
      return BoutiqueMapController(
        repository: repository,
        cacheStore: cacheStore,
        connectivityService: connectivityService,
        locationService: locationService,
        collectorId: collectorId,
      );
    });
