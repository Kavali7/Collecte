import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

import 'package:collecte_revendeurs/features/itinerary/data/cache/collector_track_cache_store.dart';
import 'package:collecte_revendeurs/features/itinerary/data/firestore_collector_track_repository.dart';
import 'package:collecte_revendeurs/features/itinerary/domain/collector_track_point.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirestoreCollectorTrackRepository', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreCollectorTrackRepository repository;
    late Directory cacheDir;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      cacheDir = await Directory.systemTemp.createTemp('track_repo_test');
      final cacheStore = CollectorTrackCacheStore(
        baseDirectory: cacheDir,
        collectorId: 'agent-a',
      );
      repository = FirestoreCollectorTrackRepository(
        firestore: firestore,
        cacheStore: cacheStore,
      );
    });

    tearDown(() async {
      if (cacheDir.existsSync()) {
        await cacheDir.delete(recursive: true);
      }
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
          .skip(1)
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

    test('serves cached data before remote results', () async {
      final day = DateTime(2024, 5, 1);
      await repository.enqueuePoint(
        collectorId: 'agent-a',
        point: CollectorTrackPoint(
          id: 'local-1',
          quartier: 'Quartier inconnu',
          latitude: 5.1,
          longitude: -4.1,
          timestamp: day.add(const Duration(hours: 8)),
        ),
      );

      final results = await repository
          .watchTrackPoints(collectorId: 'agent-a', date: day)
          .first;

      expect(results, hasLength(1));
      expect(results.first.id, equals('local-1'));
    });

    test('syncPending uploads cached points and clears pending queue', () async {
      final day = DateTime(2024, 6, 1, 9);
      await repository.enqueuePoint(
        collectorId: 'agent-a',
        point: CollectorTrackPoint(
          id: 'local-42',
          quartier: 'Quartier inconnu',
          latitude: 5.2,
          longitude: -4.2,
          timestamp: day,
        ),
      );

      expect(
        await repository.pendingCount(collectorId: 'agent-a'),
        equals(1),
      );

      final results =
          await repository.syncPending(collectorId: 'agent-a');
      expect(results, isNotEmpty);
      for (final result in results) {
        await repository.markSynced(
          collectorId: 'agent-a',
          result: result,
        );
      }

      expect(
        await repository.pendingCount(collectorId: 'agent-a'),
        equals(0),
      );

      final docs =
          await firestore.collection('collector_track_points').get();
      expect(docs.docs.length, results.length);
    });
  });
}
