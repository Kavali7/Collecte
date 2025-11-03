import 'dart:io';

import 'package:collecte_revendeurs/features/boutiques/application/boutique_map_controller.dart';
import 'package:collecte_revendeurs/features/boutiques/application/boutique_map_state.dart';
import 'package:collecte_revendeurs/features/boutiques/data/boutique_repository.dart';
import 'package:collecte_revendeurs/features/boutiques/data/cache/boutique_cache_store.dart';
import 'package:collecte_revendeurs/features/boutiques/domain/boutique.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils/fake_connectivity_service.dart';

void main() {
  late Directory tempDir;
  late BoutiqueCacheStore cacheStore;
  late _FakeBoutiqueRepository repository;
  late FakeConnectivityService connectivity;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('boutique-map-cache');
    cacheStore = BoutiqueCacheStore(baseDirectory: tempDir);
    repository = _FakeBoutiqueRepository();
    connectivity = FakeConnectivityService(initiallyOnline: false);
  });

  tearDown(() async {
    await connectivity.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('load cached boutiques when offline', () async {
    final cachedBoutique = Boutique(
      id: 'cache-1',
      nom: 'Boutique Cached',
      nomGerantComplet: 'Gerant',
      telephone: '0700000000',
      latitude: 5.32,
      longitude: -4.00,
      dateDeVisite: DateTime(2024, 6, 12),
      syncStatus: SyncStatus.pending,
    );

    await cacheStore.saveAll([cachedBoutique]);

    final controller = BoutiqueMapController(
      repository: repository,
      cacheStore: cacheStore,
      connectivityService: connectivity,
    );

    expect(controller.state, const BoutiqueMapState.initial());

    await controller.initialize();

    final state = controller.state;
    expect(state.isOffline, isTrue);
    expect(state.isLoading, isFalse);
    expect(state.boutiques, hasLength(1));
    expect(state.boutiques.first.id, 'cache-1');
    expect(state.boutiques.first.latitude, 5.32);
    expect(state.boutiques.first.syncStatus, SyncStatus.pending);

    controller.dispose();
  });
}

class _FakeBoutiqueRepository implements BoutiqueRepository {
  List<Boutique> remoteBoutiques = const [];

  @override
  Future<Boutique> create(Boutique boutique) async {
    remoteBoutiques = [...remoteBoutiques, boutique];
    return boutique;
  }

  @override
  Future<List<Boutique>> loadBoutiques() async {
    return remoteBoutiques;
  }

  @override
  Future<Boutique> update(Boutique boutique) async {
    remoteBoutiques = remoteBoutiques.map((existing) {
      if (existing.id == boutique.id) return boutique;
      return existing;
    }).toList();
    return boutique;
  }

  @override
  Future<bool> isTelephoneAvailable(
    String telephone, {
    String? excludeId,
  }) async {
    return true;
  }
}
