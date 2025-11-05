import 'package:collecte_revendeurs/features/itinerary/application/agent_itinerary_controller.dart';
import 'package:collecte_revendeurs/features/itinerary/application/agent_itinerary_state.dart';
import 'package:collecte_revendeurs/features/itinerary/data/collector_track_repository.dart';
import 'package:collecte_revendeurs/features/itinerary/domain/collector_track_point.dart';
import 'package:collecte_revendeurs/features/itinerary/presentation/agent_itinerary_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubAgentItineraryController extends AgentItineraryController {
  _StubAgentItineraryController()
    : super(
        repository: const _NoopCollectorTrackRepository(),
        collectorId: 'stub-agent',
      ) {
    state = AgentItineraryState(
      selectedDate: DateTime(2024, 1, 1),
      points: [
        CollectorTrackPoint(
          id: 'p1',
          quartier: 'Cocody',
          latitude: 5.31,
          longitude: -4.03,
          timestamp: DateTime(2024, 1, 1, 8, 15),
        ),
      ],
      geoPoints: [
        CollectorTrackPoint(
          id: 'p1',
          quartier: 'Cocody',
          latitude: 5.31,
          longitude: -4.03,
          timestamp: DateTime(2024, 1, 1, 8, 15),
        ),
      ],
      isLoading: false,
    );
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
  Stream<List<CollectorTrackPoint>> watchTrackPoints({
    required String collectorId,
    required DateTime date,
  }) {
    return const Stream.empty();
  }
}

void main() {
  testWidgets('table headers are rendered', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agentItineraryControllerProvider.overrideWith(
            (ref) => _StubAgentItineraryController(),
          ),
        ],
        child: const MaterialApp(home: AgentItineraryPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Quartier'), findsOneWidget);
    expect(find.text('Latitude'), findsOneWidget);
    expect(find.text('Longitude'), findsOneWidget);
    expect(find.text('Heure'), findsOneWidget);
  });
}
