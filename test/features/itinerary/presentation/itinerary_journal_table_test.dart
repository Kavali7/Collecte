import 'package:collecte_revendeurs/features/itinerary/domain/collector_track_point.dart';
import 'package:collecte_revendeurs/features/itinerary/presentation/widgets/itinerary_journal_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CollectorTrackPoint _buildPoint({
  required String id,
  required DateTime timestamp,
  String quartier = 'Quartier test',
  double latitude = 5.0,
  double longitude = -4.0,
}) {
  return CollectorTrackPoint(
    id: id,
    quartier: quartier,
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp,
  );
}

void main() {
  group('ItineraryJournalTable utils', () {
    test('buildItineraryJournalEntries computes chronologic durations', () {
      final points = [
        _buildPoint(
          id: 'a',
          quartier: 'Point A',
          latitude: 5.1,
          longitude: -4.1,
          timestamp: DateTime(2024, 1, 1, 10),
        ),
        _buildPoint(
          id: 'b',
          quartier: 'Point B',
          latitude: 5.2,
          longitude: -4.2,
          timestamp: DateTime(2024, 1, 1, 10, 30),
        ),
      ];
      final entries = buildItineraryJournalEntries(
        points,
        currentTime: DateTime(2024, 1, 1, 11),
      );

      expect(entries, hasLength(2));
      expect(entries.first.duration, const Duration(minutes: 30));
      expect(entries.first.usesRealtimeFallback, isFalse);
      expect(entries.last.duration, const Duration(minutes: 30));
      expect(entries.last.usesRealtimeFallback, isTrue);
    });

    test('formatJournalDuration renders readable labels', () {
      expect(
        formatJournalDuration(const Duration(hours: 1, minutes: 5)),
        equals('1h 05min'),
      );
      expect(
        formatJournalDuration(const Duration(minutes: 12)),
        equals('12min'),
      );
      expect(
        formatJournalDuration(const Duration(seconds: 45)),
        equals('45s'),
      );
    });
  });

  group('ItineraryJournalTable widget', () {
    testWidgets('renders headers and stop details', (tester) async {
      final points = [
        _buildPoint(
          id: '1',
          quartier: 'Plateau',
          latitude: 5.3201,
          longitude: -4.0201,
          timestamp: DateTime(2024, 1, 1, 10, 0),
        ),
        _buildPoint(
          id: '2',
          quartier: 'Cocody',
          latitude: 5.3502,
          longitude: -4.0011,
          timestamp: DateTime(2024, 1, 1, 10, 20),
        ),
      ];
      final entries = buildItineraryJournalEntries(
        points,
        currentTime: DateTime(2024, 1, 1, 11, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItineraryJournalTable(entries: entries, height: 260),
          ),
        ),
      );

      expect(find.text('Quartier'), findsOneWidget);
      expect(find.text('Heure d\'arrivee'), findsOneWidget);
      expect(find.text('Plateau'), findsOneWidget);
      expect(find.text('Cocody'), findsOneWidget);
      expect(find.text('5.32010'), findsOneWidget);
      expect(find.text('-4.02010'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
      expect(find.text('20min'), findsOneWidget);
      expect(find.text('40min'), findsOneWidget);
    });

    testWidgets('supports scrolling to reveal far rows', (tester) async {
      final base = DateTime(2024, 3, 10, 8);
      final points = List.generate(
        8,
        (index) => _buildPoint(
          id: 'stop-$index',
          quartier: 'Stop $index',
          timestamp: base.add(Duration(minutes: 30 * index)),
        ),
      );
      final entries = buildItineraryJournalEntries(
        points,
        currentTime: base.add(const Duration(hours: 6)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItineraryJournalTable(entries: entries, height: 200),
          ),
        ),
      );

      expect(find.text('Stop 7'), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('Stop 7'), findsOneWidget);
    });

    testWidgets('highlights anomalous durations', (tester) async {
      final entry = ItineraryJournalEntry(
        point: _buildPoint(
          id: 'alert',
          quartier: 'Attente longue',
          timestamp: DateTime(2024, 4, 1, 9),
        ),
        arrival: DateTime(2024, 4, 1, 9),
        duration: const Duration(minutes: 45),
        usesRealtimeFallback: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItineraryJournalTable(entries: [entry], height: 180),
          ),
        ),
      );

      final durationText = find.text('45min');
      final durationWidget = tester.widget<Text>(durationText);
      final context = tester.element(durationText);
      final expectedColor = Theme.of(context).colorScheme.error;
      expect(durationWidget.style?.color, equals(expectedColor));
    });
  });
}
