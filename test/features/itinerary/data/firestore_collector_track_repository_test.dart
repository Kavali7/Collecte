import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collecte_revendeurs/features/itinerary/data/firestore_collector_track_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirestoreCollectorTrackRepository', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreCollectorTrackRepository repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository =
          FirestoreCollectorTrackRepository(firestore: firestore);
    });

    test('filters by collector and selected day', () async {
      final collection =
          firestore.collection('collector_track_points');
      final day = DateTime(2024, 10, 1);

      await collection.add({
        'collectorId': 'agent-a',
        'quartier': 'Plateau',
        'latitude': 5.3456,
        'longitude': -4.0123,
        'timestamp': Timestamp.fromDate(day.add(const Duration(hours: 7))),
      });
      await collection.add({
        'collectorId': 'agent-a',
        'quartier': 'Cocody',
        'latitude': 5.356,
        'longitude': -4.03,
        'timestamp': Timestamp.fromDate(day.add(const Duration(hours: 10))),
      });
      await collection.add({
        'collectorId': 'agent-b',
        'quartier': 'Treichville',
        'latitude': 5.3,
        'longitude': -4.0,
        'timestamp': Timestamp.fromDate(day.add(const Duration(hours: 11))),
      });

      final results = await repository
          .watchTrackPoints(collectorId: 'agent-a', date: day)
          .first;

      expect(results, hasLength(2));
      expect(
        results.map((point) => point.quartier),
        containsAllInOrder(['Plateau', 'Cocody']),
      );
      expect(results.first.timestamp.isBefore(results.last.timestamp), isTrue);
    });

    test('emits empty list when collectorId missing', () async {
      final results = await repository
          .watchTrackPoints(collectorId: '', date: DateTime.now())
          .first;
      expect(results, isEmpty);
    });
  });
}
