import '../domain/collector_track_point.dart';
import 'collector_track_sync_result.dart';

abstract class CollectorTrackRepository {
  Stream<List<CollectorTrackPoint>> watchTrackPoints({
    required String collectorId,
    required DateTime date,
  });

  Future<void> enqueuePoint({
    required String collectorId,
    required CollectorTrackPoint point,
  });

  Future<List<CollectorTrackSyncResult>> syncPending({
    required String collectorId,
  });

  Future<void> markSynced({
    required String collectorId,
    required CollectorTrackSyncResult result,
  });

  Future<int> pendingCount({required String collectorId});
}
