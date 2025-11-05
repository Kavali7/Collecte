import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/collector_track_point.dart';
import 'collector_track_repository.dart';

final collectorTrackRepositoryProvider =
    Provider<CollectorTrackRepository>((ref) {
      return FirestoreCollectorTrackRepository(
        firestore: FirebaseFirestore.instance,
      );
    });

class FirestoreCollectorTrackRepository implements CollectorTrackRepository {
  FirestoreCollectorTrackRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  static const _collectionName = 'collector_track_points';

  final FirebaseFirestore _firestore;

  @override
  Stream<List<CollectorTrackPoint>> watchTrackPoints({
    required String collectorId,
    required DateTime date,
  }) {
    if (collectorId.isEmpty) {
      return Stream.value(const <CollectorTrackPoint>[]);
    }

    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final query = _firestore
        .collection(_collectionName)
        .where('collectorId', isEqualTo: collectorId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('timestamp', isLessThan: Timestamp.fromDate(dayEnd))
        .orderBy('timestamp');

    return query.snapshots().map((snapshot) {
      final points = <CollectorTrackPoint>[];
      for (final doc in snapshot.docs) {
        try {
          points.add(CollectorTrackPoint.fromMap(doc.id, doc.data()));
        } catch (error) {
          debugPrint('CollectorTrackPoint ignore (${doc.id}): $error');
        }
      }
      return points;
    });
  }
}
