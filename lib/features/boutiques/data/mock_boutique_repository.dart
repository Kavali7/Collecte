import 'dart:async';

import 'package:uuid/uuid.dart';

import '../domain/boutique.dart';
import '../domain/day_range.dart';
import 'boutique_repository.dart';

class MockBoutiqueRepository implements BoutiqueRepository {
  MockBoutiqueRepository() {
    _seedBoutiques();
  }

  final _uuid = const Uuid();
  final List<Boutique> _boutiques = [];

  @override
  Future<List<Boutique>> loadBoutiques(
    String collectorId, {
    DateTime? forDate,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final dayRange = forDate != null ? DayRange(forDate) : null;
    return List.unmodifiable(
      _boutiques.where(
        (boutique) =>
            boutique.collectorId == collectorId &&
            (dayRange == null || dayRange.contains(boutique.submittedAt)),
      ),
    );
  }

  @override
  Future<List<Boutique>> loadAllBoutiques({DateTime? forDate}) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final dayRange = forDate != null ? DayRange(forDate) : null;
    return List.unmodifiable(
      _boutiques.where(
        (boutique) => dayRange == null || dayRange.contains(boutique.submittedAt),
      ),
    );
  }

  @override
  Future<Boutique> create(Boutique boutique) async {
    final newBoutique = boutique.copyWith(
      id: _uuid.v4(),
      submittedAt: boutique.submittedAt ?? DateTime.now(),
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
    final updated = boutique.copyWith(
      submittedAt: boutique.submittedAt ?? DateTime.now(),
      syncStatus: SyncStatus.pending,
    );
    _boutiques[index] = updated;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return updated;
  }

  @override
  Future<bool> isTelephoneAvailable(
    String collectorId,
    String telephone, {
    String? excludeId,
  }) async {
    final normalized = telephone.trim();
    if (normalized.isEmpty) {
      return false;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return !_boutiques.any((boutique) {
      if (boutique.collectorId != collectorId) return false;
      final matchesNumber = boutique.telephones.any(
        (value) => value.trim() == normalized,
      );
      if (!matchesNumber) return false;
      if (excludeId == null) return true;
      return boutique.id != excludeId;
    });
  }

  void _seedBoutiques() {
    if (_boutiques.isNotEmpty) return;

    _boutiques.addAll([
      Boutique(
        id: _uuid.v4(),
        nom: 'Boutique Soleil',
        nomGerantComplet: 'Awa Kouassi',
        collectorId: 'mock-user',
        specialite: BoutiqueSpecialite.telephone,
        telephones: const ['+225 07 55 12 34'],
        latitude: 5.30966,
        longitude: -4.00426,
        photoPaths: const [],
        dateDeVisite: DateTime.now().subtract(const Duration(days: 2)),
        submittedAt: DateTime.now().subtract(const Duration(days: 2)),
        syncStatus: SyncStatus.synced,
      ),
      Boutique(
        id: _uuid.v4(),
        nom: 'TechnoPlus',
        nomGerantComplet: 'Moussa Diallo',
        collectorId: 'mock-user',
        specialite: BoutiqueSpecialite.reparation,
        telephones: const ['+225 05 11 22 33'],
        latitude: 5.32813,
        longitude: -4.02342,
        photoPaths: const [],
        dateDeVisite: DateTime.now().subtract(const Duration(days: 5)),
        submittedAt: DateTime.now().subtract(const Duration(days: 5)),
        syncStatus: SyncStatus.synced,
      ),
      Boutique(
        id: _uuid.v4(),
        nom: 'Mode Elegance',
        nomGerantComplet: 'Mariame Traore',
        collectorId: 'mock-user',
        specialite: BoutiqueSpecialite.telephone,
        telephones: const ['+225 01 77 88 99'],
        latitude: 5.39012,
        longitude: -4.08745,
        photoPaths: const [],
        dateDeVisite: DateTime.now().subtract(const Duration(days: 1)),
        submittedAt: DateTime.now().subtract(const Duration(days: 1)),
        syncStatus: SyncStatus.synced,
      ),
    ]);
  }
}
