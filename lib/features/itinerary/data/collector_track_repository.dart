import '../domain/collector_track_point.dart';

abstract class CollectorTrackRepository {
  Stream<List<CollectorTrackPoint>> watchTrackPoints({
    required String collectorId,
    required DateTime date,
  });
}
