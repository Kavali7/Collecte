import 'package:collecte_revendeurs/core/location/location_service.dart';
import 'package:collecte_revendeurs/features/itinerary/application/collector_track_recorder.dart';
import 'package:collecte_revendeurs/features/itinerary/data/collector_track_repository.dart';
import 'package:collecte_revendeurs/features/itinerary/data/collector_track_sync_result.dart';
import 'package:collecte_revendeurs/features/itinerary/domain/collector_track_point.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils/fake_location_service.dart';

class _RecorderRepositoryFake implements CollectorTrackRepository {
  final List<CollectorTrackPoint> _pending = [];
  bool throwOnSync = false;

  int get pendingCountValue => _pending.length;

  @override
  Future<void> enqueuePoint({
    required String collectorId,
    required CollectorTrackPoint point,
  }) async {
    _pending.add(point);
  }

  @override
  Future<void> markSynced({
    required String collectorId,
    required CollectorTrackSyncResult result,
  }) async {
    if (result.isSuccess) {
      _pending.removeWhere((point) => point.id == result.localId);
    }
  }

  @override
  Future<int> pendingCount({required String collectorId}) async {
    return _pending.length;
  }

  @override
  Future<List<CollectorTrackSyncResult>> syncPending({
    required String collectorId,
  }) async {
    if (throwOnSync) throw Exception('network');
    return _pending
        .map(
          (point) => CollectorTrackSyncResult.success(
            localId: point.id,
            remoteId: 'remote-${point.id}',
            point: point.copyWith(id: 'remote-${point.id}'),
          ),
        )
        .toList();
  }

  @override
  Stream<List<CollectorTrackPoint>> watchTrackPoints({
    required String collectorId,
    required DateTime date,
  }) {
    return const Stream.empty();
  }
}

void main() {
  const locationResult = LocationResult.success(
    DeviceLocation(latitude: 5.0, longitude: -4.0),
  );

  group('CollectorTrackRecorder', () {
    late _RecorderRepositoryFake repository;
    late FakeLocationService locationService;
    late DateTime currentTime;

    CollectorTrackRecorder buildRecorder() {
      return CollectorTrackRecorder(
        repository: repository,
        locationService: locationService,
        collectorId: 'collector-a',
        syncInterval: const Duration(days: 1),
        clock: () => currentTime,
      );
    }

    setUp(() {
      repository = _RecorderRepositoryFake();
      locationService = FakeLocationService(initialResult: locationResult);
      currentTime = DateTime(2024, 1, 1, 8);
    });

    tearDown(() async {
      await locationService.dispose();
    });

    Future<void> drainMicrotasks() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    test('records points offline and keeps them pending', () async {
      repository.throwOnSync = true;
      final recorder = buildRecorder();
      await drainMicrotasks();

      locationService.emitLocation(
        const DeviceLocation(latitude: 5.2, longitude: -4.2),
      );
      await drainMicrotasks();

      expect(recorder.state.pendingPoints, equals(1));
      expect(recorder.state.hasPendingSync, isTrue);
      expect(recorder.state.errorMessage, isNull);
      recorder.dispose();
    });

    test('syncNow flushes pending points on success', () async {
      final recorder = buildRecorder();
      await drainMicrotasks();

      locationService.emitLocation(
        const DeviceLocation(latitude: 5.4, longitude: -4.2),
      );
      await drainMicrotasks();

      currentTime = DateTime(2024, 1, 1, 9);
      await recorder.syncNow();
      await drainMicrotasks();

      expect(recorder.state.pendingPoints, equals(0));
      expect(recorder.state.lastSyncAt, equals(currentTime));
      recorder.dispose();
    });

    test('sync error updates recorder state', () async {
      repository.throwOnSync = true;
      final recorder = buildRecorder();
      await drainMicrotasks();

      await recorder.syncNow();
      await drainMicrotasks();

      expect(recorder.state.errorMessage, contains('Erreur reseau'));
      expect(recorder.state.isSyncing, isFalse);
      recorder.dispose();
    });
  });
}
