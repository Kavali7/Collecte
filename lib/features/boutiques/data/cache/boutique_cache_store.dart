import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/boutique.dart';

class BoutiqueCacheStore {
  BoutiqueCacheStore({Directory? baseDirectory})
    : _baseDirectory = baseDirectory;

  static const _fileName = 'boutiques_cache.json';

  final Directory? _baseDirectory;

  Future<void> saveAll(List<Boutique> boutiques) async {
    try {
      final file = await _resolveFile();
      final payload = boutiques.map(_toJson).toList();
      await file.writeAsString(jsonEncode(payload));
    } catch (_) {
      // ignore cache write errors to avoid impacting the main flow
    }
  }

  Future<List<Boutique>> load() async {
    try {
      final file = await _resolveFile();
      if (!await file.exists()) return const [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return const [];
      final raw = jsonDecode(content);
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(_fromJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<File> _resolveFile() async {
    final directory = _baseDirectory ?? await getApplicationSupportDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final filePath = p.join(directory.path, _fileName);
    return File(filePath);
  }

  Map<String, dynamic> _toJson(Boutique boutique) {
    return {
      'id': boutique.id,
      'nom': boutique.nom,
      'nomGerantComplet': boutique.nomGerantComplet,
      'telephone': boutique.telephone,
      'latitude': boutique.latitude,
      'longitude': boutique.longitude,
      'photoPath': boutique.photoPath,
      'dateDeVisite': boutique.dateDeVisite?.toIso8601String(),
      'syncStatus': boutique.syncStatus.name,
    };
  }

  Boutique _fromJson(Map<String, dynamic> raw) {
    final latitude = raw['latitude'];
    final longitude = raw['longitude'];
    final date = raw['dateDeVisite'];
    return Boutique(
      id: raw['id'] as String? ?? '',
      nom: raw['nom'] as String? ?? '',
      nomGerantComplet: raw['nomGerantComplet'] as String? ?? '',
      telephone: raw['telephone'] as String? ?? '',
      latitude: latitude is num ? latitude.toDouble() : null,
      longitude: longitude is num ? longitude.toDouble() : null,
      photoPath: raw['photoPath'] as String?,
      dateDeVisite: date is String && date.isNotEmpty
          ? DateTime.tryParse(date)
          : null,
      syncStatus: _mapSyncStatus(raw['syncStatus'] as String?),
    );
  }

  SyncStatus _mapSyncStatus(String? value) {
    switch (value) {
      case 'pending':
        return SyncStatus.pending;
      case 'error':
        return SyncStatus.error;
      case 'synced':
      default:
        return SyncStatus.synced;
    }
  }
}

final boutiqueCacheStoreProvider = Provider<BoutiqueCacheStore>((ref) {
  return BoutiqueCacheStore();
});
