import '../../../core/location/location_service.dart';

class CollectorTrackRecorderState {
  const CollectorTrackRecorderState({
    this.isTracking = false,
    this.pendingPoints = 0,
    this.isSyncing = false,
    this.lastSyncAt,
    this.errorMessage,
    this.locationFailure,
  });

  final bool isTracking;
  final int pendingPoints;
  final bool isSyncing;
  final DateTime? lastSyncAt;
  final String? errorMessage;
  final LocationFailureType? locationFailure;

  bool get hasPendingSync => pendingPoints > 0;
  bool get hasError => errorMessage != null || locationFailure != null;
  bool get hasPermissionIssue =>
      locationFailure == LocationFailureType.permissionDenied ||
      locationFailure == LocationFailureType.permissionPermanentlyDenied;

  CollectorTrackRecorderState copyWith({
    bool? isTracking,
    int? pendingPoints,
    bool? isSyncing,
    DateTime? lastSyncAt,
    String? errorMessage,
    bool resetError = false,
    LocationFailureType? locationFailure,
    bool resetLocationFailure = false,
  }) {
    return CollectorTrackRecorderState(
      isTracking: isTracking ?? this.isTracking,
      pendingPoints: pendingPoints ?? this.pendingPoints,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      errorMessage: resetError ? null : (errorMessage ?? this.errorMessage),
      locationFailure: resetLocationFailure
          ? null
          : (locationFailure ?? this.locationFailure),
    );
  }
}
