import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart';

import '../../../auth/controllers/auth_controller.dart';
import '../../domain/collector_track_point.dart';

enum TrackSyncStatus { pending, synced, error }

class CachedCollectorTrackEntry {
  const CachedCollectorTrackEntry({
    required this.localId,
    required this.collectorId,
    required this.point,
    required this.status,
    this.remoteId,
    this.errorMessage,
  });

  factory CachedCollectorTrackEntry.fromJson(Map<String, dynamic> json) {
    final timestampRaw = json['timestamp'];
    DateTime? timestamp;
    if (timestampRaw is String) {
      timestamp = DateTime.tryParse(timestampRaw);
    } else if (timestampRaw is int) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(timestampRaw);
    }

    final latitudeRaw = json['latitude'];
    final longitudeRaw = json['longitude'];
    final latitude = latitudeRaw is num ? latitudeRaw.toDouble() : null;
    final longitude = longitudeRaw is num ? longitudeRaw.toDouble() : null;
    final pointId = json['pointId'] as String? ?? json['remoteId'] as String?;

    if (timestamp == null || latitude == null || longitude == null) {
      throw const FormatException('Invalid cached track entry');
    }

    final status = _parseStatus(json['status'] as String?);

    final point = CollectorTrackPoint(
      id: pointId ?? json['localId'] as String? ?? '',
      quartier: json['quartier'] as String? ?? 'Quartier inconnu',
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
    );

    return CachedCollectorTrackEntry(
      localId: json['localId'] as String? ?? point.id,
      collectorId: json['collectorId'] as String? ?? '',
      point: point,
      status: status,
      remoteId: json['remoteId'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  CachedCollectorTrackEntry copyWith({
    String? localId,
    String? collectorId,
    CollectorTrackPoint? point,
    TrackSyncStatus? status,
    String? remoteId,
    String? errorMessage,
  }) {
    return CachedCollectorTrackEntry(
      localId: localId ?? this.localId,
      collectorId: collectorId ?? this.collectorId,
      point: point ?? this.point,
      status: status ?? this.status,
      remoteId: remoteId ?? this.remoteId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'localId': localId,
      'remoteId': remoteId,
      'collectorId': collectorId,
      'quartier': point.quartier,
      'latitude': point.latitude,
      'longitude': point.longitude,
      'timestamp': point.timestamp.toIso8601String(),
      'status': status.name,
      'errorMessage': errorMessage,
      'pointId': point.id,
    };
  }

  CollectorTrackPoint toTrackPoint() {
    final resolvedId = remoteId ?? point.id;
    return point.copyWith(id: resolvedId);
  }

  DateTime get timestamp => point.timestamp;

  bool occursOnDay(DateTime day) {
    final normalizedEntry = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return normalizedEntry == normalizedDay;
  }

  bool get isPending =>
      status == TrackSyncStatus.pending || status == TrackSyncStatus.error;

  static TrackSyncStatus _parseStatus(String? raw) {
    switch (raw) {
      case 'synced':
        return TrackSyncStatus.synced;
      case 'error':
        return TrackSyncStatus.error;
      case 'pending':
      default:
        return TrackSyncStatus.pending;
    }
  }

  final String localId;
  final String collectorId;
  final CollectorTrackPoint point;
  final TrackSyncStatus status;
  final String? remoteId;
  final String? errorMessage;
}

class CollectorTrackCacheStore {
  CollectorTrackCacheStore({Directory? baseDirectory, String? collectorId})
    : _baseDirectory = baseDirectory,
      _defaultCollectorId = collectorId;

  static const _fileName = 'collector_track_cache.json';

  final Directory? _baseDirectory;
  final String? _defaultCollectorId;

  Future<void> append(
    CachedCollectorTrackEntry entry, {
    String? collectorId,
  }) async {
    final targetCollector = _resolveCollectorId(
      collectorId ?? entry.collectorId,
    );
    final normalizedEntry = entry.copyWith(
      collectorId: targetCollector,
    );
    final entries = await _loadEntries(targetCollector);
    final index = entries.indexWhere(
      (item) => item.localId == normalizedEntry.localId,
    );
    if (index == -1) {
      entries.add(normalizedEntry);
    } else {
      entries[index] = normalizedEntry;
    }
    await _saveEntries(targetCollector, entries);
  }

  Future<List<CachedCollectorTrackEntry>> loadForDate(
    DateTime day, {
    String? collectorId,
  }) async {
    final targetCollector = _resolveCollectorId(collectorId);
    final entries = await _loadEntries(targetCollector);
    final normalizedDay = _normalizeDay(day);
    final filtered = entries
        .where((entry) => entry.occursOnDay(normalizedDay))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return filtered;
  }

  Future<List<CachedCollectorTrackEntry>> pendingEntries({
    String? collectorId,
  }) async {
    final targetCollector = _resolveCollectorId(collectorId);
    final entries = await _loadEntries(targetCollector);
    return entries
        .where((entry) => entry.isPending)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<int> pendingCount({String? collectorId}) async {
    final pending = await pendingEntries(collectorId: collectorId);
    return pending.length;
  }

  Future<void> replaceRemoteEntries({
    required DateTime day,
    required List<CollectorTrackPoint> remotePoints,
    String? collectorId,
  }) async {
    final targetCollector = _resolveCollectorId(collectorId);
    final entries = await _loadEntries(targetCollector);
    final normalizedDay = _normalizeDay(day);
    final retained = entries.where((entry) {
      if (!entry.occursOnDay(normalizedDay)) return true;
      return entry.status != TrackSyncStatus.synced;
    }).toList();

    final remotes = remotePoints
        .map(
          (point) => CachedCollectorTrackEntry(
            localId: point.id,
            collectorId: targetCollector,
            point: point,
            status: TrackSyncStatus.synced,
            remoteId: point.id,
          ),
        )
        .toList();

    final updated = [...retained, ...remotes]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    await _saveEntries(targetCollector, updated);
  }

  Future<void> markSynced({
    required String localId,
    required String remoteId,
    String? collectorId,
  }) async {
    final targetCollector = _resolveCollectorId(collectorId);
    final entries = await _loadEntries(targetCollector);
    final index = entries.indexWhere((entry) => entry.localId == localId);
    if (index == -1) return;
    final updatedEntry = entries[index].copyWith(
      status: TrackSyncStatus.synced,
      remoteId: remoteId,
      point: entries[index].point.copyWith(id: remoteId),
      errorMessage: null,
    );
    entries[index] = updatedEntry;
    await _saveEntries(targetCollector, entries);
  }

  Future<void> markError({
    required String localId,
    String? message,
    String? collectorId,
  }) async {
    final targetCollector = _resolveCollectorId(collectorId);
    final entries = await _loadEntries(targetCollector);
    final index = entries.indexWhere((entry) => entry.localId == localId);
    if (index == -1) return;
    entries[index] = entries[index].copyWith(
      status: TrackSyncStatus.error,
      errorMessage: message ?? 'Sync failed',
    );
    await _saveEntries(targetCollector, entries);
  }

  Future<List<CachedCollectorTrackEntry>> _loadEntries(
    String collectorId,
  ) async {
    try {
      final file = await _resolveFile(collectorId);
      if (!await file.exists()) return [];
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return [];
      final content = _cipherFor(collectorId).decode(raw);
      final payload = jsonDecode(content);
      if (payload is! List) return [];
      return payload
          .whereType<Map<String, dynamic>>()
          .map(CachedCollectorTrackEntry.fromJson)
          .where((entry) => entry.collectorId == collectorId)
          .toList();
    } catch (error, stack) {
      debugPrint('CollectorTrackCacheStore load error: $error');
      debugPrint('$stack');
      return [];
    }
  }

  Future<void> _saveEntries(
    String collectorId,
    List<CachedCollectorTrackEntry> entries,
  ) async {
    try {
      final file = await _resolveFile(collectorId);
      final payload = entries.map((entry) => entry.toJson()).toList();
      final content = jsonEncode(payload);
      final encoded = _cipherFor(collectorId).encode(content);
      await file.writeAsString(encoded, flush: true);
    } catch (error, stack) {
      debugPrint('CollectorTrackCacheStore save error: $error');
      debugPrint('$stack');
    }
  }

  Future<File> _resolveFile(String collectorId) async {
    final directory = _baseDirectory ?? await getApplicationSupportDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final suffix = collectorId.isEmpty ? _fileName : '${collectorId}_$_fileName';
    return File(p.join(directory.path, suffix));
  }

  String _resolveCollectorId(String? explicit) {
    final candidate = explicit ?? _defaultCollectorId;
    if (candidate != null && candidate.isNotEmpty) {
      return candidate;
    }
    return 'anonymous';
  }

  DateTime _normalizeDay(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  _CacheCipher _cipherFor(String collectorId) =>
      _CacheCipher(collectorId: collectorId);
}

class _CacheCipher {
  _CacheCipher({required String collectorId})
    : _collectorId = collectorId,
      _keyBytes = _deriveKey(collectorId),
      _ivBytes = _deriveIv(collectorId);

  final String _collectorId;
  final Uint8List _keyBytes;
  final Uint8List _ivBytes;

  bool get _hasCipher => _collectorId.isNotEmpty;

  String encode(String input) {
    if (!_hasCipher) return input;
    try {
      final cipher = _createCipher(true);
      final bytes = Uint8List.fromList(utf8.encode(input));
      final encrypted = cipher.process(bytes);
      return base64Encode(encrypted);
    } catch (_) {
      return input;
    }
  }

  String decode(String input) {
    if (!_hasCipher) return input;
    try {
      final cipher = _createCipher(false);
      final decoded = base64Decode(input);
      final decrypted = cipher.process(decoded);
      return utf8.decode(decrypted);
    } catch (_) {
      return input;
    }
  }

  PaddedBlockCipher _createCipher(bool forEncryption) {
    final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      CBCBlockCipher(AESEngine()),
    );
    cipher.init(
      forEncryption,
      PaddedBlockCipherParameters(
        ParametersWithIV(KeyParameter(_keyBytes), _ivBytes),
        null,
      ),
    );
    return cipher;
  }

  static Uint8List _deriveKey(String collectorId) {
    final seed = utf8.encode('collector-track-key|$collectorId');
    final digest = sha256.convert(seed).bytes;
    return Uint8List.fromList(digest);
  }

  static Uint8List _deriveIv(String collectorId) {
    final seed = utf8.encode('collector-track-iv|$collectorId');
    final digest = md5.convert(seed).bytes;
    return Uint8List.fromList(digest);
  }
}

final collectorTrackCacheStoreProvider =
    Provider<CollectorTrackCacheStore>((ref) {
      final authState = ref.watch(authControllerProvider);
      final firebaseAuth = ref.watch(firebaseAuthProvider);
      final collectorId =
          authState.isAuthenticated ? firebaseAuth.currentUser?.uid : null;
      return CollectorTrackCacheStore(collectorId: collectorId);
    });
