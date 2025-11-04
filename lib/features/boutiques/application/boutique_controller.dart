import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../auth/controllers/auth_controller.dart';
import '../data/boutique_repository.dart';
import '../data/cache/boutique_cache_store.dart';
import '../data/firebase_boutique_repository.dart';
import '../domain/boutique.dart';
import 'boutique_list_state.dart';

final boutiqueListControllerProvider =
    StateNotifierProvider<BoutiqueListController, BoutiqueListState>((ref) {
      final repository = ref.watch(boutiqueRepositoryProvider);
      final cacheStore = ref.watch(boutiqueCacheStoreProvider);
      final authState = ref.watch(authControllerProvider);
      final firebaseAuth = ref.watch(firebaseAuthProvider);
      final collectorId =
          authState.isAuthenticated ? firebaseAuth.currentUser?.uid : null;
      final controller = BoutiqueListController(
        repository,
        cacheStore,
        collectorId: collectorId,
      );
      controller.initialize();
      return controller;
    });

class BoutiqueListController extends StateNotifier<BoutiqueListState> {
  BoutiqueListController(
    this._repository,
    this._cacheStore, {
    required String? collectorId,
  })  : _collectorId = collectorId,
        super(const BoutiqueListState.initial());

  final BoutiqueRepository _repository;
  final BoutiqueCacheStore _cacheStore;
  final String? _collectorId;
  final Uuid _uuid = const Uuid();

  Future<void> initialize() async {
    final collectorId = _collectorId;
    if (collectorId == null || collectorId.isEmpty) {
      state = state.copyWith(
        boutiques: const [],
        isLoading: false,
        isOfflineFallback: false,
      );
      return;
    }

    final cachedBoutiques = await _cacheStore.load();
    state = state.copyWith(
      boutiques: cachedBoutiques.isNotEmpty ? cachedBoutiques : state.boutiques,
      isLoading: cachedBoutiques.isEmpty,
      isOfflineFallback: false,
    );
    try {
      final items = await _repository.loadBoutiques(collectorId);
      state = state.copyWith(
        boutiques: items,
        isLoading: false,
        isOfflineFallback: false,
      );
      await _cacheStore.saveAll(items);
    } catch (_) {
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

      final index = updatedItems.indexWhere((item) => item.id == saved.id);
      if (index != -1) {
        updatedItems[index] = saved;
      } else {
        updatedItems.add(saved);
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
      final index = updatedItems.indexWhere((item) => item.id == localId);
      if (index != -1) {
        updatedItems[index] = pending;
      } else {
        updatedItems.add(pending);
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
}
