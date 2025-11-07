import 'package:collecte_revendeurs/core/location/location_constants.dart';
import 'package:collecte_revendeurs/core/location/location_service.dart';
import 'package:collecte_revendeurs/core/location/locationiq_reverse_geocoding.dart';
import 'package:collecte_revendeurs/core/location/reverse_geocoding_cache.dart';
import 'package:collecte_revendeurs/features/itinerary/application/collector_track_recorder.dart';
import 'package:collecte_revendeurs/features/itinerary/data/collector_track_repository.dart';
import 'package:collecte_revendeurs/features/itinerary/data/collector_track_sync_result.dart';
import 'package:collecte_revendeurs/features/itinerary/domain/collector_track_point.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils/fake_location_service.dart';

class _RecorderRepositoryFake implements CollectorTrackRepository {
  final List<CollectorTrackPoint> _pending = [];
  bool throwOnSync = false;
  final Map<String, String> updatedQuartiers = {};

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

  @override
  Future<void> updateQuartier({
    required String collectorId,
    required String localId,
    required String quartier,
  }) async {
    updatedQuartiers[localId] = quartier;
    final index = _pending.indexWhere((point) => point.id == localId);
    if (index != -1) {
      _pending[index] = _pending[index].copyWith(quartier: quartier);
    }
  }
}

class _StubReverseGeocodingService extends LocationIqReverseGeocodingService {
  _StubReverseGeocodingService(this._result) : super();

  ReverseGeocodingResult _result;
  int invocationCount = 0;
  double? lastLatitude;
  double? lastLongitude;

  void setResult(ReverseGeocodingResult result) {
    _result = result;
  }

  @override
  Future<ReverseGeocodingResult> resolve({
    required double latitude,
    required double longitude,
  }) async {
    invocationCount += 1;
    lastLatitude = latitude;
    lastLongitude = longitude;
    return _result;
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
    late _StubReverseGeocodingService reverseGeoService;
    late ReverseGeocodingCache reverseGeocodingCache;

    CollectorTrackRecorder buildRecorder() {
      return CollectorTrackRecorder(
        repository: repository,
        locationService: locationService,
        reverseGeocodingCache: reverseGeocodingCache,
        collectorId: 'collector-a',
        syncInterval: const Duration(days: 1),
        clock: () => currentTime,
      );
    }

    setUp(() {
      repository = _RecorderRepositoryFake();
      locationService = FakeLocationService(initialResult: locationResult);
      currentTime = DateTime(2024, 1, 1, 8);
      reverseGeoService = _StubReverseGeocodingService(
        const ReverseGeocodingResult.success(
          ReverseGeocodingAddress(
            formatted: 'Abidjan / Arr: Plateau / Plateau',
            city: 'Abidjan',
            arrondissement: 'Plateau',
            quartier: 'Plateau',
          ),
        ),
      );
      reverseGeocodingCache = ReverseGeocodingCache(
        service: reverseGeoService,
        ttl: const Duration(minutes: 30),
      );
    });

    tearDown(() async {
      await locationService.dispose();
    });

    Future<void> drainMicrotasks() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    Future<void> emitStableStop(DeviceLocation location) async {
      locationService.emitLocation(location);
      await drainMicrotasks();
      currentTime = currentTime.add(const Duration(minutes: 4));
      locationService.emitLocation(location);
      await drainMicrotasks();
    }

    test('records points offline and keeps them pending', () async {
      repository.throwOnSync = true;
      final recorder = buildRecorder();
      await drainMicrotasks();

      await emitStableStop(
        const DeviceLocation(latitude: 5.2, longitude: -4.2),
      );

      expect(recorder.state.pendingPoints, equals(1));
      expect(recorder.state.hasPendingSync, isTrue);
      expect(recorder.state.errorMessage, isNull);
      recorder.dispose();
    });

    test('syncNow flushes pending points on success', () async {
      final recorder = buildRecorder();
      await drainMicrotasks();

      await emitStableStop(
        const DeviceLocation(latitude: 5.4, longitude: -4.2),
      );

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

    test('applies reverse geocoded quartier to recorded points', () async {
      final recorder = buildRecorder();
      await drainMicrotasks();

      await emitStableStop(
        const DeviceLocation(latitude: 5.11111, longitude: -4.22222),
      );

      expect(repository._pending, isNotEmpty);
      expect(repository._pending.single.quartier, equals('Plateau'));
      expect(reverseGeoService.invocationCount, equals(1));
      expect(reverseGeoService.lastLatitude, closeTo(5.11111, 0.00001));
      expect(reverseGeoService.lastLongitude, closeTo(-4.22222, 0.00001));
      recorder.dispose();
    });

    test(
      'retries reverse geocoding asynchronously when initial lookup fails',
      () async {
        reverseGeoService.setResult(
          const ReverseGeocodingResult.failure('quota'),
        );
        final recorder = CollectorTrackRecorder(
          repository: repository,
          locationService: locationService,
          reverseGeocodingCache: reverseGeocodingCache,
          collectorId: 'collector-a',
          syncInterval: const Duration(days: 1),
          clock: () => currentTime,
          reverseGeocodeRetryDelay: const Duration(milliseconds: 10),
          reverseGeocodeMaxAttempts: 2,
          reverseGeocodeBatchSize: 1,
        );
        await drainMicrotasks();

        await emitStableStop(
          const DeviceLocation(latitude: 5.5, longitude: -4.5),
        );

        expect(
          repository._pending.single.quartier,
          equals(kUnknownQuartierLabel),
        );

        reverseGeoService.setResult(
          const ReverseGeocodingResult.success(
            ReverseGeocodingAddress(
              formatted: 'Abidjan / Arr: Plateau / Plateau',
              city: 'Abidjan',
              arrondissement: 'Plateau',
              quartier: 'Plateau',
            ),
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 80));
        await drainMicrotasks();

        expect(repository._pending.single.quartier, equals('Plateau'));
        expect(repository.updatedQuartiers.values, contains('Plateau'));
        recorder.dispose();
      },
    );
  });
}
