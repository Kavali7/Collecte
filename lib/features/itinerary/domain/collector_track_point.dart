import 'package:cloud_firestore/cloud_firestore.dart';

class CollectorTrackPoint {
  const CollectorTrackPoint({
    required this.id,
    required this.quartier,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory CollectorTrackPoint.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    final quartier = (data['quartier'] as String?) ?? 'Quartier inconnu';
    final latitudeRaw = data['latitude'];
    final longitudeRaw = data['longitude'];
    final timestampRaw = data['timestamp'];

    final latitude = _toDouble(latitudeRaw);
    final longitude = _toDouble(longitudeRaw);
    final timestamp = _toDateTime(timestampRaw);

    if (latitude == null || longitude == null || timestamp == null) {
      throw ArgumentError('CollectorTrackPoint incomplet pour $id');
    }

    return CollectorTrackPoint(
      id: id,
      quartier: quartier,
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'quartier': quartier,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp,
    };
  }

  CollectorTrackPoint copyWith({
    String? id,
    String? quartier,
    double? latitude,
    double? longitude,
    DateTime? timestamp,
  }) {
    return CollectorTrackPoint(
      id: id ?? this.id,
      quartier: quartier ?? this.quartier,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  final String id;
  final String quartier;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  static double? _toDouble(dynamic input) {
    if (input is num) return input.toDouble();
    if (input is String) return double.tryParse(input);
    return null;
  }

  static DateTime? _toDateTime(dynamic input) {
    if (input is DateTime) return input;
    if (input is Timestamp) return input.toDate();
    if (input is int) {
      return DateTime.fromMillisecondsSinceEpoch(input);
    }
    if (input is String) {
      return DateTime.tryParse(input);
    }
    return null;
  }
}
