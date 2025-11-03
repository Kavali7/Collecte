import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/boutique_repository.dart';
import '../data/firebase_boutique_repository.dart';
import '../domain/boutique.dart';
import 'boutique_list_state.dart';

final boutiqueListControllerProvider =
    StateNotifierProvider<BoutiqueListController, BoutiqueListState>((ref) {
      final repository = ref.watch(boutiqueRepositoryProvider);
      final controller = BoutiqueListController(repository);
      controller.initialize();
      return controller;
    });

class BoutiqueListController extends StateNotifier<BoutiqueListState> {
  BoutiqueListController(this._repository)
    : super(const BoutiqueListState.initial());

  final BoutiqueRepository _repository;

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);
    final items = await _repository.loadBoutiques();
    state = state.copyWith(boutiques: items, isLoading: false);
  }

  void search(String term) {
    state = state.copyWith(searchTerm: term);
  }

  Future<Boutique> createOrUpdate(Boutique boutique) async {
    state = state.copyWith(isLoading: true);
    final updatedItems = [...state.boutiques];
    late Boutique saved;

    if (boutique.id.isEmpty) {
      saved = await _repository.create(boutique);
      updatedItems.add(saved);
    } else {
      saved = await _repository.update(boutique);
      final index = updatedItems.indexWhere((item) => item.id == saved.id);
      if (index != -1) {
        updatedItems[index] = saved;
      } else {
        updatedItems.add(saved);
      }
    }

    state = state.copyWith(boutiques: updatedItems, isLoading: false);
    return saved;
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
