import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'locationiq_reverse_geocoding.dart';

class ReverseGeocodingCache {
  ReverseGeocodingCache({
    LocationIqReverseGeocodingService? service,
    Duration ttl = const Duration(minutes: 5),
    DateTime Function()? clock,
    ReverseGeocodingCacheStore? store,
  }) : _service = service ?? LocationIqReverseGeocodingService(),
       _ttl = ttl,
       _clock = clock ?? DateTime.now,
       _store = store;

  final LocationIqReverseGeocodingService _service;
  final Duration _ttl;
  final DateTime Function() _clock;
  final ReverseGeocodingCacheStore? _store;

  final Map<String, ReverseGeocodingCacheEntry> _entries = {};
  final Map<String, Future<ReverseGeocodingAddress?>> _pending = {};

  Future<void>? _loadFuture;
  Future<void>? _persistChain;

  Future<ReverseGeocodingAddress?> resolve({
    required double latitude,
    required double longitude,
  }) async {
    await _ensureLoaded();
    final key = _cacheKey(latitude, longitude);
    final now = _clock();
    final cached = _entries[key];
    if (cached != null && now.difference(cached.fetchedAt) <= _ttl) {
      return cached.address;
    }

    final inflight = _pending[key];
    if (inflight != null) {
      return inflight;
    }

    final completer = Completer<ReverseGeocodingAddress?>();
    _pending[key] = completer.future;

    try {
      final result = await _service.resolve(
        latitude: latitude,
        longitude: longitude,
      );
      final address = result.address;
      if (result.isSuccess) {
        _entries[key] = ReverseGeocodingCacheEntry(address, now);
        _schedulePersist();
      } else {
        _entries.remove(key);
      }
      completer.complete(address);
      return address;
    } catch (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
      rethrow;
    } finally {
      _pending.remove(key);
    }
  }

  Future<List<ReverseGeocodingAddress?>> resolveBatch(
    List<ReverseGeocodingCoordinate> coordinates,
  ) {
    final futures = coordinates
        .map(
          (coordinate) => resolve(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
          ).catchError((_) => null),
        )
        .toList(growable: false);
    return Future.wait(futures);
  }

  void clear() {
    _entries.clear();
    _pending.clear();
    _schedulePersist();
  }

  Future<void> _ensureLoaded() async {
    final store = _store;
    if (store == null) return;
    if (_loadFuture != null) {
      await _loadFuture;
      return;
    }
    _loadFuture = () async {
      final snapshot = await store.load();
      _entries.addAll(snapshot);
    }();
    await _loadFuture;
  }

  void _schedulePersist() {
    final store = _store;
    if (store == null) return;
    final snapshot = Map<String, ReverseGeocodingCacheEntry>.from(_entries);
    _persistChain = (_persistChain ?? Future.value()).then(
      (_) => store.save(snapshot),
    );
  }

  String _cacheKey(double latitude, double longitude) {
    final latKey = latitude.toStringAsFixed(4);
    final lngKey = longitude.toStringAsFixed(4);
    return '$latKey/$lngKey';
  }
}

class ReverseGeocodingCoordinate {
  const ReverseGeocodingCoordinate({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

class ReverseGeocodingCacheEntry {
  ReverseGeocodingCacheEntry(this.address, this.fetchedAt);

  factory ReverseGeocodingCacheEntry.fromJson(Map<String, dynamic> json) {
    final fetchedAtRaw = json['fetchedAt'] as String?;
    final fetchedAt =
        DateTime.tryParse(fetchedAtRaw ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final addressJson = json['address'];
    ReverseGeocodingAddress? address;
    if (addressJson is Map<String, dynamic>) {
      address = ReverseGeocodingAddress(
        formatted: (addressJson['formatted'] as String?) ?? '',
        city: addressJson['city'] as String?,
        arrondissement: addressJson['arrondissement'] as String?,
        quartier: addressJson['quartier'] as String?,
      );
    }
    return ReverseGeocodingCacheEntry(address, fetchedAt);
  }

  final ReverseGeocodingAddress? address;
  final DateTime fetchedAt;

  Map<String, dynamic> toJson() {
    return {
      'fetchedAt': fetchedAt.toIso8601String(),
      'address': address == null
          ? null
          : {
              'formatted': address!.formatted,
              'city': address!.city,
              'arrondissement': address!.arrondissement,
              'quartier': address!.quartier,
            },
    };
  }
}

class ReverseGeocodingCacheStore {
  ReverseGeocodingCacheStore({Directory? baseDirectory})
    : _baseDirectory = baseDirectory;

  static const _fileName = 'reverse_geocoding_cache.json';

  final Directory? _baseDirectory;

  Future<Map<String, ReverseGeocodingCacheEntry>> load() async {
    try {
      final file = await _resolveFile();
      if (!await file.exists()) return {};
      final content = await file.readAsString();
      if (content.trim().isEmpty) return {};
      final payload = jsonDecode(content);
      if (payload is! Map<String, dynamic>) return {};
      final entries = <String, ReverseGeocodingCacheEntry>{};
      payload.forEach((key, raw) {
        if (raw is Map<String, dynamic>) {
          try {
            entries[key] = ReverseGeocodingCacheEntry.fromJson(raw);
          } catch (_) {
            // ignore malformed entry
          }
        }
      });
      return entries;
    } catch (_) {
      return {};
    }
  }

  Future<void> save(Map<String, ReverseGeocodingCacheEntry> entries) async {
    try {
      final file = await _resolveFile();
      final payload = entries.map(
        (key, entry) => MapEntry(key, entry.toJson()),
      );
      await file.writeAsString(jsonEncode(payload), flush: true);
    } catch (_) {
      // ignore disk errors, cache remains memory-only
    }
  }

  Future<File> _resolveFile() async {
    Directory directory;
    final explicitDirectory = _baseDirectory;
    if (explicitDirectory != null) {
      directory = explicitDirectory;
    } else {
      directory = await _safeSupportDirectory();
    }
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File(p.join(directory.path, _fileName));
  }

  Future<Directory> _safeSupportDirectory() async {
    try {
      return await getApplicationSupportDirectory();
    } catch (_) {
      final fallbackPath = p.join(
        Directory.systemTemp.path,
        'collecte_reverse_geo_cache',
      );
      return Directory(fallbackPath);
    }
  }
}
