import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/boutique_repository.dart';
import '../data/cache/boutique_cache_store.dart';
import '../data/firebase_boutique_repository.dart';
import '../domain/boutique.dart';
import 'boutique_list_state.dart';

final boutiqueListControllerProvider =
    StateNotifierProvider<BoutiqueListController, BoutiqueListState>((ref) {
      final repository = ref.watch(boutiqueRepositoryProvider);
      final cacheStore = ref.watch(boutiqueCacheStoreProvider);
      final controller = BoutiqueListController(repository, cacheStore);
      controller.initialize();
      return controller;
    });

class BoutiqueListController extends StateNotifier<BoutiqueListState> {
  BoutiqueListController(this._repository, this._cacheStore)
    : super(const BoutiqueListState.initial());

  final BoutiqueRepository _repository;
  final BoutiqueCacheStore _cacheStore;
  final Uuid _uuid = const Uuid();

  Future<void> initialize() async {
    final cachedBoutiques = await _cacheStore.load();
    state = state.copyWith(
      boutiques: cachedBoutiques.isNotEmpty ? cachedBoutiques : state.boutiques,
      isLoading: cachedBoutiques.isEmpty,
    );
    try {
      final items = await _repository.loadBoutiques();
      state = state.copyWith(boutiques: items, isLoading: false);
      await _cacheStore.saveAll(items);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void search(String term) {
    state = state.copyWith(searchTerm: term);
  }

  Future<Boutique> createOrUpdate(Boutique boutique) async {
    state = state.copyWith(isLoading: true);
    final updatedItems = [...state.boutiques];
    late Boutique saved;

    try {
      final isLocalEntry =
          boutique.id.isNotEmpty && boutique.id.startsWith('local-');

      if (boutique.id.isEmpty || isLocalEntry) {
        saved = await _repository.create(boutique.copyWith(id: ''));
      } else {
        saved = await _repository.update(boutique);
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
      final pending = boutique.copyWith(
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

  Future<bool> isTelephoneAvailable(String telephone, {String? excludeId}) {
    return _repository.isTelephoneAvailable(telephone, excludeId: excludeId);
  }

  Boutique? findById(String id) {
    if (id.isEmpty) return null;
    try {
      return state.boutiques.firstWhere((boutique) => boutique.id == id);
    } on StateError {
      return null;
    }
  }
}
