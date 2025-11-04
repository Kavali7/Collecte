import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../auth/controllers/auth_controller.dart';
import '../../domain/boutique.dart';

class BoutiqueCacheStore {
  BoutiqueCacheStore({Directory? baseDirectory, String? collectorId})
    : _baseDirectory = baseDirectory,
      _collectorId = collectorId;

  static const _fileName = 'boutiques_cache.json';

  final Directory? _baseDirectory;
  final String? _collectorId;

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
    final collectorId = _collectorId;
    final resolvedName = collectorId == null || collectorId.isEmpty
        ? _fileName
        : '${collectorId}_$_fileName';
    final filePath = p.join(directory.path, resolvedName);
    return File(filePath);
  }

  Map<String, dynamic> _toJson(Boutique boutique) {
    return {
      'id': boutique.id,
      'nom': boutique.nom,
      'nomGerantComplet': boutique.nomGerantComplet,
      'collectorId': boutique.collectorId,
      'specialite': boutique.specialite.storageValue,
      'telephone': boutique.primaryTelephone,
      'telephones': boutique.telephones,
      'latitude': boutique.latitude,
      'longitude': boutique.longitude,
      'photoPath': boutique.primaryPhotoPath,
      'photoPaths': boutique.photoPaths,
      'dateDeVisite': boutique.dateDeVisite?.toIso8601String(),
      'submittedAt': boutique.submittedAt?.toIso8601String(),
      'syncStatus': boutique.syncStatus.name,
    };
  }

  Boutique _fromJson(Map<String, dynamic> raw) {
    final latitude = raw['latitude'];
    final longitude = raw['longitude'];
    final date = raw['dateDeVisite'];
    final submitted = raw['submittedAt'];
    final collectorId = raw['collectorId'] as String? ?? '';
    final specialiteRaw = raw['specialite'] as String?;
    DateTime? submittedAt;
    if (submitted is String && submitted.isNotEmpty) {
      submittedAt = DateTime.tryParse(submitted);
    } else if (submitted is int) {
      submittedAt = DateTime.fromMillisecondsSinceEpoch(submitted);
    }
    return Boutique(
      id: raw['id'] as String? ?? '',
      nom: raw['nom'] as String? ?? '',
      nomGerantComplet: raw['nomGerantComplet'] as String? ?? '',
      collectorId: collectorId,
      specialite: boutiqueSpecialiteFromStorage(specialiteRaw),
      telephones: _readTelephones(raw),
      latitude: latitude is num ? latitude.toDouble() : null,
      longitude: longitude is num ? longitude.toDouble() : null,
      photoPaths: _readPhotoPaths(raw),
      dateDeVisite: date is String && date.isNotEmpty
          ? DateTime.tryParse(date)
          : null,
      submittedAt: submittedAt,
      syncStatus: _mapSyncStatus(raw['syncStatus'] as String?),
    );
  }

  List<String> _readTelephones(Map<String, dynamic> raw) {
    final telephones = raw['telephones'];
    if (telephones is List) {
      return telephones
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
    }

    final legacy = raw['telephone'];
    if (legacy is String && legacy.trim().isNotEmpty) {
      return [legacy.trim()];
    }

    return const [];
  }

  List<String> _readPhotoPaths(Map<String, dynamic> raw) {
    final photos = raw['photoPaths'];
    if (photos is List) {
      return photos
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
    }
    final legacy = raw['photoPath'];
    if (legacy is String && legacy.trim().isNotEmpty) {
      return [legacy.trim()];
    }
    return const [];
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
  final authState = ref.watch(authControllerProvider);
  final auth = ref.watch(firebaseAuthProvider);
  final collectorId =
      authState.isAuthenticated ? auth.currentUser?.uid : null;
  return BoutiqueCacheStore(collectorId: collectorId);
});
