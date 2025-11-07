import 'package:collecte_revendeurs/core/location/location_service.dart';
import 'package:collecte_revendeurs/features/itinerary/application/agent_itinerary_controller.dart';
import 'package:collecte_revendeurs/features/itinerary/application/agent_itinerary_state.dart';
import 'package:collecte_revendeurs/features/itinerary/application/collector_track_recorder.dart';
import 'package:collecte_revendeurs/features/itinerary/application/collector_track_recorder_state.dart';
import 'package:collecte_revendeurs/features/itinerary/data/collector_track_repository.dart';
import 'package:collecte_revendeurs/features/itinerary/data/collector_track_sync_result.dart';
import 'package:collecte_revendeurs/features/itinerary/domain/collector_track_point.dart';
import 'package:collecte_revendeurs/features/itinerary/presentation/agent_itinerary_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubAgentItineraryController extends AgentItineraryController {
  _StubAgentItineraryController(AgentItineraryState stubState)
    : super(
        repository: const _NoopCollectorTrackRepository(),
        collectorId: 'stub-agent',
      ) {
    state = stubState;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> changeDate(DateTime date) async {}

  @override
  Future<void> loadForDate(DateTime date) async {}
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

class _NoopLocationService implements LocationService {
  const _NoopLocationService();

  @override
  Future<LocationResult> getCurrentLocation() async {
    return const LocationResult.failure(
      LocationFailure(type: LocationFailureType.unknown, message: 'noop'),
    );
  }

  @override
  Stream<DeviceLocation> watchPosition() => const Stream.empty();
}

class _StubCollectorTrackRecorder extends CollectorTrackRecorder {
  _StubCollectorTrackRecorder(CollectorTrackRecorderState stubState)
    : super(
        repository: const _NoopCollectorTrackRepository(),
        locationService: const _NoopLocationService(),
        collectorId: '',
      ) {
    state = stubState;
  }
}

void main() {
  testWidgets('shows enlarged map and journal table', (tester) async {
    final stubState = AgentItineraryState(
      selectedDate: DateTime(2024, 2, 10),
      points: const [],
      geoPoints: const [],
      isLoading: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agentItineraryControllerProvider.overrideWith(
            (ref) => _StubAgentItineraryController(stubState),
          ),
          collectorTrackRecorderProvider.overrideWith(
            (ref) => _StubCollectorTrackRecorder(
              const CollectorTrackRecorderState(),
            ),
          ),
        ],
        child: const MaterialApp(home: AgentItineraryPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Quartier'), findsOneWidget);
    expect(find.text('Heure d\'arrivee'), findsOneWidget);
    expect(find.text('Aucun arret confirme pour cette date.'), findsOneWidget);
  });

  testWidgets('map section height remains above half of viewport', (
    tester,
  ) async {
    final view = tester.view;
    view.physicalSize = const Size(400, 900);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    final stubState = AgentItineraryState(
      selectedDate: DateTime(2024, 2, 10),
      points: const [],
      geoPoints: const [],
      isLoading: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agentItineraryControllerProvider.overrideWith(
            (ref) => _StubAgentItineraryController(stubState),
          ),
          collectorTrackRecorderProvider.overrideWith(
            (ref) => _StubCollectorTrackRecorder(
              const CollectorTrackRecorderState(),
            ),
          ),
        ],
        child: const MaterialApp(home: AgentItineraryPage()),
      ),
    );

    await tester.pumpAndSettle();

    final screenHeight = view.physicalSize.height / view.devicePixelRatio;
    final mapFinder = find.byType(ItineraryMapSection);
    final mapSize = tester.getSize(mapFinder);
    expect(mapSize.height, greaterThanOrEqualTo(screenHeight * 0.5));
    expect((mapSize.height - screenHeight * 0.6).abs(), lessThanOrEqualTo(1));
  });
}
