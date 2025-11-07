import '../domain/collector_track_point.dart';

class CollectorTrackSyncResult {
  const CollectorTrackSyncResult.success({
    required this.localId,
    required this.remoteId,
    required this.point,
  })  : error = null,
        isRecoverable = true;

  const CollectorTrackSyncResult.failure({
    required this.localId,
    required this.point,
    this.error,
    this.isRecoverable = true,
  }) : remoteId = null;

  final String localId;
  final String? remoteId;
  final CollectorTrackPoint point;
  final Object? error;
  final bool isRecoverable;

  bool get isSuccess => remoteId != null && error == null;
}
