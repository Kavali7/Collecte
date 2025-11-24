import 'dart:io';

import 'package:collecte_revendeurs/core/location/location_service.dart';
import 'package:collecte_revendeurs/features/boutiques/application/boutique_map_controller.dart';
import 'package:collecte_revendeurs/features/boutiques/application/boutique_map_state.dart';
import 'package:collecte_revendeurs/features/boutiques/data/boutique_repository.dart';
import 'package:collecte_revendeurs/features/boutiques/data/cache/boutique_cache_store.dart';
import 'package:collecte_revendeurs/features/boutiques/domain/boutique.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils/fake_connectivity_service.dart';
import '../../../test_utils/fake_location_service.dart';

void main() {
  late Directory tempDir;
  late BoutiqueCacheStore cacheStore;
  late _FakeBoutiqueRepository repository;
  late FakeConnectivityService connectivity;
  late FakeLocationService locationService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('boutique-map-cache');
    cacheStore = BoutiqueCacheStore(
      baseDirectory: tempDir,
      collectorId: 'tester',
    );
    repository = _FakeBoutiqueRepository();
    connectivity = FakeConnectivityService(initiallyOnline: false);
    locationService = FakeLocationService(
      initialResult: LocationResult.success(
        const DeviceLocation(latitude: 5.32, longitude: -4.0),
      ),
    );
  });

  tearDown(() async {
    await connectivity.dispose();
    await locationService.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('load cached boutiques when offline', () async {
    final now = DateTime.now();
    final cachedBoutique = Boutique(
      id: 'cache-1',
      nom: 'Boutique Cached',
      nomGerantComplet: 'Gerant',
      collectorId: 'tester',
      specialite: BoutiqueSpecialite.telephone,
      telephones: const ['0700000000'],
      latitude: 5.32,
      longitude: -4.00,
      dateDeVisite: DateTime(
        now.year,
        now.month,
        now.day,
        8,
        0,
      ),
      submittedAt: now,
      syncStatus: SyncStatus.pending,
    );

    await cacheStore.saveAll([cachedBoutique]);

    final controller = BoutiqueMapController(
      repository: repository,
      cacheStore: cacheStore,
      connectivityService: connectivity,
      locationService: locationService,
      collectorId: 'tester',
      canViewAllCollectors: false,
      isSuperAdmin: false,
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

  test(
    'refreshUserLocation stores latest coordinates and updates via stream',
    () async {
    final controller = BoutiqueMapController(
      repository: repository,
      cacheStore: cacheStore,
      connectivityService: connectivity,
      locationService: locationService,
      collectorId: 'tester',
      canViewAllCollectors: false,
      isSuperAdmin: false,
    );

      await controller.refreshUserLocation();

      expect(controller.state.userLocation, isNotNull);
      expect(controller.state.locationErrorMessage, isNull);

      locationService.emitLocation(
        const DeviceLocation(latitude: 6.0, longitude: -4.1),
      );

      await Future<void>.delayed(Duration.zero);

      expect(controller.state.userLocation?.latitude, 6.0);
      expect(controller.state.userLocation?.longitude, -4.1);

      controller.dispose();
    },
  );

  test('refreshUserLocation surfaces permission error', () async {
    locationService.setNextResult(
      const LocationResult.failure(
        LocationFailure(
          type: LocationFailureType.permissionDenied,
          message: 'Autorisation refusee.',
        ),
      ),
    );

    final controller = BoutiqueMapController(
      repository: repository,
      cacheStore: cacheStore,
      connectivityService: connectivity,
      locationService: locationService,
      collectorId: 'tester',
      canViewAllCollectors: false,
      isSuperAdmin: false,
    );

    await controller.refreshUserLocation();

    expect(controller.state.userLocation, isNull);
    expect(controller.state.locationErrorMessage, 'Autorisation refusee.');
    expect(controller.state.isLocatingUser, isFalse);

    controller.dispose();
  });

  test(
    'super admin demarre sur la date du jour et peut basculer sur tout',
    () async {
      final now = DateTime(2025, 1, 20, 10);
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      repository.remoteBoutiques = [
        Boutique(
          id: 'today',
          nom: 'Boutique Today',
          nomGerantComplet: 'Gerant',
          collectorId: 'collector-a',
          specialite: BoutiqueSpecialite.telephone,
          telephones: const ['0101010101'],
          latitude: 5.3,
          longitude: -4.0,
          submittedAt: today,
          syncStatus: SyncStatus.synced,
        ),
        Boutique(
          id: 'yesterday',
          nom: 'Boutique Old',
          nomGerantComplet: 'Gerant',
          collectorId: 'collector-b',
          specialite: BoutiqueSpecialite.telephone,
          telephones: const ['0202020202'],
          latitude: 5.4,
          longitude: -4.1,
          submittedAt: yesterday,
          syncStatus: SyncStatus.synced,
        ),
      ];
      connectivity.setOnline(true);

      final controller = BoutiqueMapController(
        repository: repository,
        cacheStore: cacheStore,
        connectivityService: connectivity,
        locationService: locationService,
        collectorId: 'admin',
        canViewAllCollectors: true,
        isSuperAdmin: true,
        clock: () => now,
      );

      await controller.initialize();

      expect(controller.state.isAllTime, isFalse);
      expect(controller.state.selectedDate, today);
      expect(controller.state.boutiques, hasLength(1));
      expect(controller.state.boutiques.first.id, 'today');

      await controller.setFilterToAllTime();

      expect(controller.state.isAllTime, isTrue);
      expect(controller.state.selectedDate, isNull);
      final ids = controller.state.boutiques.map((b) => b.id).toSet();
      expect(ids, containsAll({'today', 'yesterday'}));

      controller.dispose();
    },
  );
}

class _FakeBoutiqueRepository implements BoutiqueRepository {
  List<Boutique> remoteBoutiques = const [];

  @override
  Future<Boutique> create(Boutique boutique) async {
    remoteBoutiques = [...remoteBoutiques, boutique];
    return boutique;
  }

  @override
  Future<List<Boutique>> loadBoutiques(
    String collectorId, {
    DateTime? forDate,
  }) async {
    DateTime? start;
    DateTime? end;
    if (forDate != null) {
      start = DateTime(forDate.year, forDate.month, forDate.day);
      end = start.add(const Duration(days: 1));
    }
    return remoteBoutiques.where((boutique) {
      if (boutique.collectorId != collectorId) return false;
      if (start == null || end == null) return true;
      final submittedAt = boutique.submittedAt;
      if (submittedAt == null) return false;
      final local = submittedAt.isUtc ? submittedAt.toLocal() : submittedAt;
      return !local.isBefore(start) && local.isBefore(end);
    }).toList();
  }

  @override
  Future<List<Boutique>> loadAllBoutiques({DateTime? forDate}) async {
    DateTime? start;
    DateTime? end;
    if (forDate != null) {
      start = DateTime(forDate.year, forDate.month, forDate.day);
      end = start.add(const Duration(days: 1));
    }
    return remoteBoutiques.where((boutique) {
      if (start == null || end == null) return true;
      final submittedAt = boutique.submittedAt;
      if (submittedAt == null) return false;
      final local = submittedAt.isUtc ? submittedAt.toLocal() : submittedAt;
      return !local.isBefore(start) && local.isBefore(end);
    }).toList();
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
    String collectorId,
    String telephone, {
    String? excludeId,
  }) async {
    return true;
  }
}
