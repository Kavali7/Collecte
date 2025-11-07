import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cache/collector_track_cache_store.dart';
import '../domain/collector_track_point.dart';
import 'collector_track_repository.dart';
import 'collector_track_sync_result.dart';

final collectorTrackRepositoryProvider = Provider<CollectorTrackRepository>((
  ref,
) {
  final cacheStore = ref.watch(collectorTrackCacheStoreProvider);
  return FirestoreCollectorTrackRepository(
    firestore: FirebaseFirestore.instance,
    cacheStore: cacheStore,
  );
});

class FirestoreCollectorTrackRepository implements CollectorTrackRepository {
  FirestoreCollectorTrackRepository({
    required FirebaseFirestore firestore,
    required CollectorTrackCacheStore cacheStore,
  }) : _firestore = firestore,
       _cacheStore = cacheStore;

  static const _collectionName = 'collector_track_points';

  final FirebaseFirestore _firestore;
  final CollectorTrackCacheStore _cacheStore;

  @override
  Stream<List<CollectorTrackPoint>> watchTrackPoints({
    required String collectorId,
    required DateTime date,
  }) {
    if (collectorId.isEmpty) {
      return Stream.value(const <CollectorTrackPoint>[]);
    }

    final normalizedDay = DateTime(date.year, date.month, date.day);
    final controller = StreamController<List<CollectorTrackPoint>>();
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subscription;
    var isClosed = false;

    Future<void>(() async {
      final cached = await _cacheStore.loadForDate(
        normalizedDay,
        collectorId: collectorId,
      );
      if (!isClosed) {
        controller.add(
          cached.map((entry) => entry.toTrackPoint()).toList(growable: false),
        );
      }

      subscription = _buildDayQuery(collectorId, normalizedDay).listen(
        (snapshot) async {
          final remotePoints = <CollectorTrackPoint>[];
          for (final doc in snapshot.docs) {
            try {
              remotePoints.add(CollectorTrackPoint.fromMap(doc.id, doc.data()));
            } catch (error) {
              debugPrint('CollectorTrackPoint ignore (${doc.id}): $error');
            }
          }

          await _cacheStore.replaceRemoteEntries(
            day: normalizedDay,
            remotePoints: remotePoints,
            collectorId: collectorId,
          );

          final merged = await _cacheStore.loadForDate(
            normalizedDay,
            collectorId: collectorId,
          );

          if (!isClosed) {
            controller.add(
              merged.map((entry) => entry.toTrackPoint()).toList(),
            );
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!isClosed) {
            controller.addError(error, stackTrace);
          }
        },
      );
    });

    controller.onCancel = () async {
      isClosed = true;
      await subscription?.cancel();
    };

    return controller.stream;
  }

  @override
  Future<void> enqueuePoint({
    required String collectorId,
    required CollectorTrackPoint point,
  }) async {
    if (collectorId.isEmpty) return;
    final entry = CachedCollectorTrackEntry(
      localId: point.id,
      collectorId: collectorId,
      point: point,
      status: TrackSyncStatus.pending,
    );
    await _cacheStore.append(entry, collectorId: collectorId);
  }

  @override
  Future<List<CollectorTrackSyncResult>> syncPending({
    required String collectorId,
  }) async {
    if (collectorId.isEmpty) return const [];
    final pendingEntries = await _cacheStore.pendingEntries(
      collectorId: collectorId,
    );
    if (pendingEntries.isEmpty) return const [];

    final collection = _firestore.collection(_collectionName);
    final results = <CollectorTrackSyncResult>[];

    for (final entry in pendingEntries) {
      try {
        final payload = {
          'collectorId': collectorId,
          'quartier': entry.point.quartier,
          'latitude': entry.point.latitude,
          'longitude': entry.point.longitude,
          'timestamp': Timestamp.fromDate(entry.point.timestamp),
        };
        final doc = await collection.add(payload);
        results.add(
          CollectorTrackSyncResult.success(
            localId: entry.localId,
            remoteId: doc.id,
            point: entry.point.copyWith(id: doc.id),
          ),
        );
      } catch (error) {
        results.add(
          CollectorTrackSyncResult.failure(
            localId: entry.localId,
            point: entry.point,
            error: error,
          ),
        );
      }
    }

    return results;
  }

  @override
  Future<void> markSynced({
    required String collectorId,
    required CollectorTrackSyncResult result,
  }) async {
    if (collectorId.isEmpty) return;
    if (result.isSuccess && result.remoteId != null) {
      await _cacheStore.markSynced(
        localId: result.localId,
        remoteId: result.remoteId!,
        collectorId: collectorId,
      );
    } else {
      await _cacheStore.markError(
        localId: result.localId,
        collectorId: collectorId,
        message: result.error?.toString(),
      );
    }
  }

  @override
  Future<int> pendingCount({required String collectorId}) {
    if (collectorId.isEmpty) return Future.value(0);
    return _cacheStore.pendingCount(collectorId: collectorId);
  }

  @override
  Future<void> updateQuartier({
    required String collectorId,
    required String localId,
    required String quartier,
  }) async {
    if (collectorId.isEmpty) return;
    final entry = await _cacheStore.updateQuartier(
      localId: localId,
      quartier: quartier,
      collectorId: collectorId,
    );
    final remoteId =
        entry?.remoteId ??
        (entry?.status == TrackSyncStatus.synced ? entry?.point.id : null);
    if (remoteId == null) return;
    await _firestore.collection(_collectionName).doc(remoteId).update({
      'quartier': quartier,
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildDayQuery(
    String collectorId,
    DateTime day,
  ) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    return _firestore
        .collection(_collectionName)
        .where('collectorId', isEqualTo: collectorId)
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart),
        )
        .where('timestamp', isLessThan: Timestamp.fromDate(dayEnd))
        .orderBy('timestamp')
        .snapshots();
  }
}
