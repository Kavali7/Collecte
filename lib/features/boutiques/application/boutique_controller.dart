import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../../core/network/connectivity_providers.dart';
import '../../../core/network/connectivity_service.dart';
import '../data/boutique_repository.dart';
import '../data/cache/boutique_cache_store.dart';
import '../data/firebase_boutique_repository.dart';
import '../domain/boutique.dart';
import '../domain/day_range.dart';
import 'boutique_list_state.dart';

final boutiqueListControllerProvider =
    StateNotifierProvider<BoutiqueListController, BoutiqueListState>((ref) {
      final repository = ref.watch(boutiqueRepositoryProvider);
      final cacheStore = ref.watch(boutiqueCacheStoreProvider);
      final authState = ref.watch(authControllerProvider);
      final connectivityService = ref.watch(connectivityServiceProvider);
      final collectorId =
          authState.isAuthenticated ? authState.userId : null;
      final canViewAll = authState.canManageAllCollectors;
      final controller = BoutiqueListController(
        repository,
        cacheStore,
        connectivityService: connectivityService,
        collectorId: collectorId,
        canViewAllCollectors: canViewAll,
        restrictToToday: !canViewAll,
      );
      controller.initialize();
      return controller;
    });

class BoutiqueListController extends StateNotifier<BoutiqueListState> {
  BoutiqueListController(
    this._repository,
    this._cacheStore, {
    required String? collectorId,
    required ConnectivityService connectivityService,
    required bool canViewAllCollectors,
    bool restrictToToday = true,
    DateTime Function()? clock,
  })  : _collectorId = collectorId,
        _canViewAllCollectors = canViewAllCollectors,
        _restrictToToday = restrictToToday,
        _connectivityService = connectivityService,
        _clock = clock ?? DateTime.now,
        _currentDay = DayRange.normalize((clock ?? DateTime.now)()),
        super(const BoutiqueListState.initial());

  final BoutiqueRepository _repository;
  final BoutiqueCacheStore _cacheStore;
  final ConnectivityService _connectivityService;
  StreamSubscription<bool>? _connectivitySub;
  bool _connectivityInitialized = false;
  bool _isOffline = false;
  final String? _collectorId;
  final bool _canViewAllCollectors;
  final bool _restrictToToday;
  final DateTime Function() _clock;
  DateTime _currentDay;
  final Uuid _uuid = const Uuid();

  Future<void> initialize() async {
    final filterDate = _restrictToToday ? _refreshCurrentDay() : null;
    await _ensureConnectivityMonitoring();
    if (!mounted) return;
    final collectorId = _collectorId;
    if (collectorId == null || collectorId.isEmpty) {
      state = state.copyWith(
        boutiques: const [],
        isLoading: false,
        isOfflineFallback: false,
        isOffline: _isOffline,
      );
      return;
    }

    final cachedBoutiques = await _cacheStore.load(forDate: filterDate);
    if (!mounted) return;
    state = state.copyWith(
      boutiques: cachedBoutiques.isNotEmpty ? cachedBoutiques : state.boutiques,
      isLoading: !_isOffline && cachedBoutiques.isEmpty,
      isOfflineFallback: _isOffline ? cachedBoutiques.isNotEmpty : false,
      isOffline: _isOffline,
    );
    if (_isOffline) {
      return;
    }
    try {
      final items = _canViewAllCollectors
          ? await _repository.loadAllBoutiques(forDate: filterDate)
          : await _repository.loadBoutiques(
              collectorId,
              forDate: filterDate,
            );
      if (!mounted) return;
      state = state.copyWith(
        boutiques: items,
        isLoading: false,
        isOfflineFallback: false,
      );
      await _cacheStore.saveAll(items);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        isOfflineFallback: state.boutiques.isNotEmpty,
      );
    }
  }

  void search(String term) {
    state = state.copyWith(searchTerm: term);
  }

  Future<Boutique> createOrUpdate(Boutique boutique) async {
    final filterDate = _restrictToToday ? _refreshCurrentDay() : null;
    final dayRange = filterDate != null ? DayRange(filterDate) : null;
    final collectorId = _collectorId;
    if (collectorId == null || collectorId.isEmpty) {
      throw StateError('Collector ID non disponible');
    }
    state = state.copyWith(isLoading: true);
    final updatedItems = [...state.boutiques];
    final normalizedBoutique = _normalizeForSave(boutique, collectorId);
    late Boutique saved;

    try {
      final isLocalEntry =
          boutique.id.isNotEmpty && boutique.id.startsWith('local-');

      if (boutique.id.isEmpty || isLocalEntry) {
        saved = await _repository.create(normalizedBoutique.copyWith(id: ''));
      } else {
        saved = await _repository.update(normalizedBoutique);
      }

      if (isLocalEntry) {
        updatedItems.removeWhere((item) => item.id == boutique.id);
      }

      if (dayRange == null || dayRange.contains(saved.submittedAt)) {
        final index = updatedItems.indexWhere((item) => item.id == saved.id);
        if (index != -1) {
          updatedItems[index] = saved;
        } else {
          updatedItems.add(saved);
        }
      } else {
        updatedItems.removeWhere((item) => item.id == saved.id);
      }

      state = state.copyWith(boutiques: updatedItems, isLoading: false);
      await _cacheStore.saveAll(updatedItems);
      return saved;
    } catch (_) {
      final localId = boutique.id.isEmpty ? 'local-${_uuid.v4()}' : boutique.id;
      final pending = normalizedBoutique.copyWith(
        id: localId,
        syncStatus: SyncStatus.pending,
      );
      if (dayRange == null || dayRange.contains(pending.submittedAt)) {
        final index = updatedItems.indexWhere((item) => item.id == localId);
        if (index != -1) {
          updatedItems[index] = pending;
        } else {
          updatedItems.add(pending);
        }
      } else {
        updatedItems.removeWhere((item) => item.id == localId);
      }
      state = state.copyWith(boutiques: updatedItems, isLoading: false);
      await _cacheStore.saveAll(updatedItems);
      return pending;
    }
  }

  Future<bool> isTelephoneAvailable(String telephone, {String? excludeId}) async {
    final collectorId = _collectorId;
    if (collectorId == null || collectorId.isEmpty) {
      return false;
    }
    return _repository.isTelephoneAvailable(
      collectorId,
      telephone,
      excludeId: excludeId,
    );
  }

  Boutique? findById(String id) {
    if (id.isEmpty) return null;
    try {
      return state.boutiques.firstWhere((boutique) => boutique.id == id);
    } on StateError {
      return null;
    }
  }

  Boutique _normalizeForSave(Boutique boutique, String collectorId) {
    final withCollector = boutique.copyWith(collectorId: collectorId);
    if (withCollector.submittedAt != null) {
      return withCollector;
    }
    return withCollector.copyWith(submittedAt: DateTime.now());
  }

  DateTime _refreshCurrentDay() {
    if (!_restrictToToday) return _currentDay;
    final today = DayRange.normalize(_clock());
    if (!DayRange.isSameDay(today, _currentDay)) {
      _currentDay = today;
      _pruneStateForCurrentDay();
    }
    return _currentDay;
  }

  void _pruneStateForCurrentDay() {
    if (!_restrictToToday) return;
    final range = DayRange(_currentDay);
    final filtered = state.boutiques
        .where((boutique) => range.contains(boutique.submittedAt))
        .toList();
    if (filtered.length != state.boutiques.length) {
      state = state.copyWith(boutiques: filtered);
    }
  }

  Future<void> _ensureConnectivityMonitoring() async {
    if (_connectivityInitialized) return;
    _connectivityInitialized = true;
    final isOnline = await _connectivityService.isOnline();
    if (!mounted) return;
    _isOffline = !isOnline;
    state = state.copyWith(isOffline: _isOffline);
    _connectivitySub = _connectivityService.onStatusChanged.listen((online) {
      if (!mounted) return;
      final wasOffline = _isOffline;
      _isOffline = !online;
      state = state.copyWith(isOffline: _isOffline);
      if (wasOffline && !_isOffline) {
        // Trigger a refresh when the connection is restored.
        unawaited(initialize());
      }
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}
