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
    required bool canViewAllCollectors,
    required bool isSuperAdmin,
    DateTime Function()? clock,
  }) : _repository = repository,
       _cacheStore = cacheStore,
       _connectivityService = connectivityService,
       _locationService = locationService,
       _collectorId = collectorId,
       _canViewAllCollectors = canViewAllCollectors,
       _isSuperAdmin = isSuperAdmin,
       _clock = clock ?? DateTime.now,
       _currentDay = DayRange.normalize((clock ?? DateTime.now)()),
       super(const BoutiqueMapState.initial());

  final BoutiqueRepository _repository;
  final BoutiqueCacheStore _cacheStore;
  final ConnectivityService _connectivityService;
  final LocationService _locationService;
  final String? _collectorId;
  final bool _canViewAllCollectors;
  final bool _isSuperAdmin;
  final DateTime Function() _clock;
  DateTime _currentDay;

  StreamSubscription<bool>? _connectivitySub;
  StreamSubscription<DeviceLocation>? _userLocationSub;

  Future<void> initialize() async {
    final filterDate = _initializeFilter();
    final collectorId = _collectorId;
    if (collectorId == null || collectorId.isEmpty) {
      state = state.copyWith(
        boutiques: const [],
        isLoading: false,
        isOffline: false,
        resetError: true,
        selectedDate: filterDate,
        isAllTime: _shouldStartInAllTimeMode,
        canChangeDateScope: _isSuperAdmin,
      );
      return;
    }

    await _loadForFilter(filterDate);

    await refreshUserLocation();
  }

  Future<void> sync() async {
    final collectorId = _collectorId;
    final filterDate = _currentFilterDate();
    if (collectorId == null || collectorId.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Utilisateur non authentifie.',
        resetError: false,
      );
      return;
    }
    final isOnline = await _connectivityService.isOnline();
    state = state.copyWith(isOffline: !isOnline);
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

  DateTime? _initializeFilter() {
    _currentDay = DayRange.normalize(_clock());
    final shouldStartAllTime = _shouldStartInAllTimeMode;
    final initialDate = shouldStartAllTime ? null : _currentDay;

    state = state.copyWith(
      selectedDate: initialDate,
      isAllTime: shouldStartAllTime,
      canChangeDateScope: _isSuperAdmin,
      resetError: true,
      isLoading: false,
    );
    return initialDate;
  }

  Future<void> setFilterToToday() async {
    if (!_isSuperAdmin) return;
    final today = DayRange.normalize(_clock());
    _currentDay = today;
    await _applyFilter(targetDate: today, isAllTime: false);
  }

  Future<void> setFilterToAllTime() async {
    if (!_isSuperAdmin) return;
    await _applyFilter(targetDate: null, isAllTime: true);
  }

  Future<void> setFilterToDate(DateTime date) async {
    if (!_isSuperAdmin) return;
    final normalized = DayRange.normalize(date);
    await _applyFilter(targetDate: normalized, isAllTime: false);
  }

  Future<void> _applyFilter({
    required DateTime? targetDate,
    required bool isAllTime,
  }) async {
    final currentTarget = _currentFilterDate();
    final isSameFilter = (isAllTime && state.isAllTime) ||
        (!isAllTime &&
            !state.isAllTime &&
            currentTarget != null &&
            targetDate != null &&
            DayRange.isSameDay(currentTarget, targetDate));
    if (isSameFilter) return;

    if (targetDate != null) {
      _currentDay = targetDate;
    }

    state = state.copyWith(
      selectedDate: targetDate,
      isAllTime: isAllTime,
      isLoading: true,
      resetError: true,
      clearSelectedDate: targetDate == null,
    );

    await _loadForFilter(targetDate);
  }

  DateTime? _currentFilterDate() {
    if (state.isAllTime) {
      return null;
    }

    final selected = state.selectedDate ?? _currentDay;
    final normalized = DayRange.normalize(selected);

    if (!_isSuperAdmin && !_canViewAllCollectors) {
      final today = DayRange.normalize(_clock());
      if (!DayRange.isSameDay(today, _currentDay)) {
        _currentDay = today;
        _pruneStateForDate(today);
      }
      if (!DayRange.isSameDay(normalized, today)) {
        state = state.copyWith(selectedDate: today);
        return today;
      }
      return today;
    }

    return normalized;
  }

  Future<void> _loadForFilter(DateTime? targetDate) async {
    final cached = await _cacheStore.load(forDate: targetDate);
    final isOnline = await _connectivityService.isOnline();

    state = state.copyWith(
      boutiques: cached,
      isLoading: state.isLoading || cached.isEmpty,
      isOffline: !isOnline,
      resetError: true,
    );

    _connectivitySub ??= _connectivityService.onStatusChanged.listen(
      _onConnectivityChanged,
    );

    if (isOnline) {
      await _refreshFromRemote(
        targetDate: targetDate,
        showLoading: cached.isEmpty,
      );
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _refreshFromRemote({
    required DateTime? targetDate,
    required bool showLoading,
  }) async {
    if (showLoading) {
      state = state.copyWith(isLoading: true, resetError: true);
    }
    try {
      final remote = await _fetchRemoteBoutiques(targetDate);
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
    DateTime? targetDate,
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

  bool get _shouldStartInAllTimeMode =>
      !_isSuperAdmin && _canViewAllCollectors;

  Future<List<Boutique>> _fetchRemoteBoutiques(DateTime? targetDate) {
    if (_canViewAllCollectors) {
      return _repository.loadAllBoutiques(forDate: targetDate);
    }
    final collectorId = _collectorId;
    if (collectorId == null || collectorId.isEmpty) {
      return Future.value(const []);
    }
    return _repository.loadBoutiques(
      collectorId,
      forDate: targetDate,
    );
  }

  void _pruneStateForDate(DateTime date) {
    final range = DayRange(date);
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
      final collectorId =
          authState.isAuthenticated ? authState.userId : null;
      final canViewAll = authState.canManageAllCollectors;
      final isSuperAdmin = authState.isSuperAdmin;
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
        canViewAllCollectors: canViewAll,
        isSuperAdmin: isSuperAdmin,
      );
    });
