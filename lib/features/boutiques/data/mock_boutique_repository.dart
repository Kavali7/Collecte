import 'dart:async';

import 'package:uuid/uuid.dart';

import '../domain/boutique.dart';
import 'boutique_repository.dart';

class MockBoutiqueRepository implements BoutiqueRepository {
  MockBoutiqueRepository() {
    _seedBoutiques();
  }

  final _uuid = const Uuid();
  final List<Boutique> _boutiques = [];

  @override
  Future<List<Boutique>> loadBoutiques() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return List.unmodifiable(_boutiques);
  }

  @override
  Future<Boutique> create(Boutique boutique) async {
    final newBoutique = boutique.copyWith(
      id: _uuid.v4(),
      syncStatus: SyncStatus.pending,
    );
    _boutiques.add(newBoutique);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return newBoutique;
  }

  @override
  Future<Boutique> update(Boutique boutique) async {
    final index = _boutiques.indexWhere((item) => item.id == boutique.id);
    if (index == -1) {
      throw StateError('Boutique introuvable');
    }
    final updated = boutique.copyWith(syncStatus: SyncStatus.pending);
    _boutiques[index] = updated;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return updated;
  }

  void _seedBoutiques() {
    if (_boutiques.isNotEmpty) return;

    _boutiques.addAll([
      Boutique(
        id: _uuid.v4(),
        nom: 'Boutique Soleil',
        nomGerantComplet: 'Awa Kouassi',
        telephone: '+225 07 55 12 34',
        latitude: 5.30966,
        longitude: -4.00426,
        photoPath: null,
        dateDeVisite: DateTime.now().subtract(const Duration(days: 2)),
        syncStatus: SyncStatus.synced,
      ),
      Boutique(
        id: _uuid.v4(),
        nom: 'TechnoPlus',
        nomGerantComplet: 'Moussa Diallo',
        telephone: '+225 05 11 22 33',
        latitude: 5.32813,
        longitude: -4.02342,
        photoPath: null,
        dateDeVisite: DateTime.now().subtract(const Duration(days: 5)),
        syncStatus: SyncStatus.synced,
      ),
      Boutique(
        id: _uuid.v4(),
        nom: 'Mode Elegance',
        nomGerantComplet: 'Mariame Traore',
        telephone: '+225 01 77 88 99',
        latitude: 5.39012,
        longitude: -4.08745,
        photoPath: null,
        dateDeVisite: DateTime.now().subtract(const Duration(days: 1)),
        syncStatus: SyncStatus.synced,
      ),
    ]);
  }
}
