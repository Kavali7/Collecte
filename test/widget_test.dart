// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:collecte_revendeurs/app.dart';
import 'package:collecte_revendeurs/core/location/location_providers.dart';
import 'package:collecte_revendeurs/core/location/location_service.dart';
import 'package:collecte_revendeurs/core/permissions/permissions_controller.dart';
import 'package:collecte_revendeurs/core/permissions/permissions_state.dart';
import 'package:collecte_revendeurs/features/auth/controllers/auth_controller.dart';
import 'package:collecte_revendeurs/features/itinerary/data/collector_track_repository.dart';
import 'package:collecte_revendeurs/features/itinerary/data/collector_track_sync_result.dart';
import 'package:collecte_revendeurs/features/itinerary/data/firestore_collector_track_repository.dart';
import 'package:collecte_revendeurs/features/itinerary/domain/collector_track_point.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils/fake_location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('affiche la page de connexion', (tester) async {
    final mockAuth = MockFirebaseAuth();
    final fakeLocationService = FakeLocationService(
      initialResult: const LocationResult.success(
        DeviceLocation(latitude: 0, longitude: 0),
      ),
    );
    addTearDown(fakeLocationService.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          permissionsControllerProvider.overrideWith(
            (ref) => _AlwaysGrantedPermissionsController(),
          ),
          firebaseAuthProvider.overrideWithValue(
            mockAuth,
          ),
          locationServiceProvider.overrideWithValue(fakeLocationService),
          collectorTrackRepositoryProvider.overrideWith(
            (ref) => const _NoopCollectorTrackRepository(),
          ),
        ],
        child: const CollecteApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Collecte des revendeurs'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Adresse email'), findsOneWidget);
  });
}

class _AlwaysGrantedPermissionsController extends PermissionsController {
  _AlwaysGrantedPermissionsController() {
    state = const PermissionsState(isGranted: true, isLoading: false);
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> openSettings() async {}
}

class _NoopCollectorTrackRepository implements CollectorTrackRepository {
  const _NoopCollectorTrackRepository();

  @override
  Future<void> enqueuePoint({
    required String collectorId,
    required CollectorTrackPoint point,
  }) async {}

  @override
  Future<void> markSynced({
    required String collectorId,
    required CollectorTrackSyncResult result,
  }) async {}

  @override
  Future<int> pendingCount({required String collectorId}) async => 0;

  @override
  Future<List<CollectorTrackSyncResult>> syncPending({
    required String collectorId,
  }) async {
    return const [];
  }

  @override
  Stream<List<CollectorTrackPoint>> watchTrackPoints({
    required String collectorId,
    required DateTime date,
  }) {
    return const Stream.empty();
  }
}
