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
      LocationFailure(
        type: LocationFailureType.unknown,
        message: 'noop',
      ),
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
  testWidgets('shows summary, map and status messages', (tester) async {
    final stubState = AgentItineraryState(
      selectedDate: DateTime(2024, 2, 10),
      points: const [],
      geoPoints: const [],
      isLoading: false,
    );
    final recorderState = const CollectorTrackRecorderState(
      pendingPoints: 3,
      errorMessage: 'Erreur reseau pendant la synchronisation.',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agentItineraryControllerProvider.overrideWith(
            (ref) => _StubAgentItineraryController(stubState),
          ),
          collectorTrackRecorderProvider.overrideWith(
            (ref) => _StubCollectorTrackRecorder(recorderState),
          ),
        ],
        child: const MaterialApp(home: AgentItineraryPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('0 arrets enregistres'), findsOneWidget);
    expect(find.text('Aucun trajet'), findsOneWidget);
    expect(find.text('Synchronisation en attente (3)'), findsOneWidget);
    expect(find.text('Erreur reseau/permissions'), findsOneWidget);
  });
}
