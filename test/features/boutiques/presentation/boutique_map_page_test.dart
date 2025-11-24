import 'dart:io';

import 'package:collecte_revendeurs/features/boutiques/application/boutique_map_controller.dart';
import 'package:collecte_revendeurs/features/boutiques/data/boutique_repository.dart';
import 'package:collecte_revendeurs/features/boutiques/data/cache/boutique_cache_store.dart';
import 'package:collecte_revendeurs/features/boutiques/domain/boutique.dart';
import 'package:collecte_revendeurs/features/boutiques/presentation/pages/boutique_map_page.dart';
import 'package:collecte_revendeurs/core/location/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils/fake_connectivity_service.dart';
import '../../../test_utils/fake_location_service.dart';

class _FakeBoutiqueRepository implements BoutiqueRepository {
  @override
  Future<Boutique> create(Boutique boutique) async => boutique;

  @override
  Future<List<Boutique>> loadBoutiques(
    String collectorId, {
    DateTime? forDate,
  }) async =>
      const [];

  @override
  Future<List<Boutique>> loadAllBoutiques({DateTime? forDate}) async =>
      const [];

  @override
  Future<Boutique> update(Boutique boutique) async => boutique;

  @override
  Future<bool> isTelephoneAvailable(
    String collectorId,
    String telephone, {
    String? excludeId,
  }) async {
    return true;
  }
}

class _StubBoutiqueMapController extends BoutiqueMapController {
  _StubBoutiqueMapController(Directory cacheDir)
    : super(
        repository: _FakeBoutiqueRepository(),
        cacheStore: BoutiqueCacheStore(
          baseDirectory: cacheDir,
          collectorId: 'collector-test',
        ),
        connectivityService: FakeConnectivityService(initiallyOnline: true),
        locationService: FakeLocationService(
          initialResult: const LocationResult.success(
            DeviceLocation(latitude: 0, longitude: 0),
          ),
        ),
        collectorId: 'collector-test',
        canViewAllCollectors: false,
        isSuperAdmin: false,
      );

  @override
  Future<void> initialize() async {
    state = state.copyWith(isLoading: false, resetError: true);
  }
}

void main() {
  group('BoutiqueMapPage', () {
    late Directory cacheDir;

    setUp(() {
      cacheDir = Directory.systemTemp.createTempSync('boutique_map_page_test');
    });

    tearDown(() {
      if (cacheDir.existsSync()) {
        cacheDir.deleteSync(recursive: true);
      }
    });

    testWidgets('back button triggers Navigator.pop', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            boutiqueMapControllerProvider.overrideWith((ref) {
              return _StubBoutiqueMapController(cacheDir);
            }),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: const Scaffold(body: Text('root')),
          ),
        ),
      );

      navigatorKey.currentState!.push(
        MaterialPageRoute(builder: (_) => const BoutiqueMapPage()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Carte des collectes'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('root'), findsOneWidget);
    });
  });
}
