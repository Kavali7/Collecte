import 'dart:async';

import 'package:collecte_revendeurs/core/location/location_constants.dart';
import 'package:collecte_revendeurs/core/location/quartier_resolver.dart';
import 'package:collecte_revendeurs/core/location/reverse_geocoding_cache.dart';
import 'package:collecte_revendeurs/features/itinerary/application/agent_itinerary_controller.dart';
import 'package:collecte_revendeurs/features/itinerary/data/collector_track_repository.dart';
import 'package:collecte_revendeurs/features/itinerary/data/collector_track_sync_result.dart';
import 'package:collecte_revendeurs/features/itinerary/domain/collector_track_point.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCollectorTrackRepository implements CollectorTrackRepository {
  StreamController<List<CollectorTrackPoint>>? _controller;
  String? lastCollectorId;
  DateTime? lastDate;
  List<CollectorTrackPoint> enqueued = [];
  final Map<String, String> updatedQuartiers = {};

  @override
  Stream<List<CollectorTrackPoint>> watchTrackPoints({
    required String collectorId,
    required DateTime date,
  }) {
    _controller?.close();
    _controller = StreamController<List<CollectorTrackPoint>>();
    lastCollectorId = collectorId;
    lastDate = date;
    return _controller!.stream;
  }

  @override
  Future<void> enqueuePoint({
    required String collectorId,
    required CollectorTrackPoint point,
  }) async {
    enqueued.add(point);
  }

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
  Future<void> updateQuartier({
    required String collectorId,
    required String localId,
    required String quartier,
  }) async {
    updatedQuartiers[localId] = quartier;
  }

  void emit(List<CollectorTrackPoint> points) {
    _controller?.add(points);
  }

  void emitError(Object error) {
    _controller?.addError(error);
  }

  Future<void> dispose() async {
    await _controller?.close();
  }
}

void main() {
  group('AgentItineraryController', () {
    late _FakeCollectorTrackRepository repository;
    late _MapQuartierResolverFake quartierResolver;
    late AgentItineraryController controller;

    setUp(() {
      repository = _FakeCollectorTrackRepository();
      controller = AgentItineraryController(
        repository: repository,
        quartierResolver: quartierResolver = _MapQuartierResolverFake(),
        collectorId: 'agent-a',
      );
    });

    tearDown(() async {
      controller.dispose();
      await repository.dispose();
    });

    test('normalizes selected date and loads data in order', () async {
      final dateTime = DateTime(2024, 5, 12, 14, 30);
      await controller.loadForDate(dateTime);

      repository.emit([
        CollectorTrackPoint(
          id: 'second',
          quartier: 'Cocody',
          latitude: 5.32,
          longitude: -4.06,
          timestamp: DateTime(2024, 5, 12, 12, 0),
        ),
        CollectorTrackPoint(
          id: 'first',
          quartier: 'Plateau',
          latitude: 5.34,
          longitude: -4.01,
          timestamp: DateTime(2024, 5, 12, 8, 0),
        ),
      ]);

      await Future.microtask(() {});

      final state = controller.state;
      expect(repository.lastDate, equals(DateTime(2024, 5, 12)));
      expect(state.points.first.id, 'first');
      expect(state.geoPoints.length, 2);
      expect(state.bounds, isNotNull);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('emits location error when GPS coords missing', () async {
      await controller.loadForDate(DateTime(2024, 6, 1));
      repository.emit([
        CollectorTrackPoint(
          id: 'invalid',
          quartier: 'Marcory',
          latitude: double.nan,
          longitude: double.nan,
          timestamp: DateTime(2024, 6, 1, 9),
        ),
      ]);
      await Future.microtask(() {});

      final state = controller.state;
      expect(state.geoPoints, isEmpty);
      expect(state.locationErrorMessage, isNotNull);
    });

    test('handles repository errors', () async {
      await controller.loadForDate(DateTime(2024, 7, 4));
      repository.emitError(Exception('offline'));
      await Future.microtask(() {});

      expect(controller.state.errorMessage, isNotNull);
      expect(controller.state.isLoading, isFalse);
    });

    test('resolves missing quartiers and updates repository cache', () async {
      quartierResolver.setResponse(
        latitude: 5.34,
        longitude: -4.01,
        resolution: QuartierResolution.resolved('Plateau'),
      );
      final date = DateTime(2024, 8, 15, 9);
      await controller.loadForDate(date);

      repository.emit([
        CollectorTrackPoint(
          id: 'unknown',
          quartier: kUnknownQuartierLabel,
          latitude: 5.34,
          longitude: -4.01,
          timestamp: date,
        ),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.state.points.single.quartier, equals('Plateau'));
      expect(repository.updatedQuartiers['unknown'], equals('Plateau'));
    });
  });
}

class _MapQuartierResolverFake implements QuartierResolver {
  final Map<String, QuartierResolution> _responses = {};
  QuartierResolution defaultResult = const QuartierResolution.unknown();

  void setResponse({
    required double latitude,
    required double longitude,
    required QuartierResolution resolution,
  }) {
    _responses[_key(latitude, longitude)] = resolution;
  }

  @override
  Future<QuartierResolution> resolve({
    required double latitude,
    required double longitude,
  }) async {
    return _responses[_key(latitude, longitude)] ?? defaultResult;
  }

  @override
  Future<List<QuartierResolution>> resolveBatch(
    List<ReverseGeocodingCoordinate> coordinates,
  ) async {
    return coordinates
        .map(
          (coordinate) =>
              _responses[_key(coordinate.latitude, coordinate.longitude)] ??
              defaultResult,
        )
        .toList(growable: false);
  }

  String _key(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(4)}/${longitude.toStringAsFixed(4)}';
  }
}
