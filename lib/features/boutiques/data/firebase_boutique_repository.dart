import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/boutique.dart';
import 'boutique_repository.dart';

final boutiqueRepositoryProvider = Provider<BoutiqueRepository>((ref) {
  return FirebaseBoutiqueRepository(
    firestore: FirebaseFirestore.instance,
    storage: FirebaseStorage.instance,
  );
});

class FirebaseBoutiqueRepository implements BoutiqueRepository {
  FirebaseBoutiqueRepository({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
  }) : _firestore = firestore,
       _storage = storage;

  static const String _collectionName = 'boutiques';

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  @override
  Future<List<Boutique>> loadBoutiques(String collectorId) async {
    if (collectorId.isEmpty) return const [];
    final collection = _firestore.collection(_collectionName);
    final ownedQuery = await collection
        .where('collectorId', isEqualTo: collectorId)
        .orderBy('createdAt', descending: true)
        .get();

    final orphanQuery =
        await collection.where('collectorId', isNull: true).get();
    if (orphanQuery.docs.isNotEmpty) {
      for (final doc in orphanQuery.docs) {
        await doc.reference.update({'collectorId': collectorId});
      }
    }

    final combinedDocs = [...ownedQuery.docs, ...orphanQuery.docs];
    final boutiques = combinedDocs
        .map(
          (doc) => _mapDocument(
            doc,
            doc.id,
            fallbackCollectorId: collectorId,
          ),
        )
        .toList();

    boutiques.sort((a, b) {
      final aDate = a.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return boutiques;
  }

  @override
  Future<Boutique> create(Boutique boutique) async {
    final docRef = _firestore.collection(_collectionName).doc();

    final photos = await _handlePhotos(
      docId: docRef.id,
      newPaths: boutique.photoPaths,
      existingUrls: const [],
      existingStoragePaths: const [],
    );

    final collectorId = boutique.collectorId.isNotEmpty
        ? boutique.collectorId
        : (throw StateError('Identifiant collecteur manquant'));

    final payloadBoutique = boutique.copyWith(
      id: docRef.id,
      collectorId: collectorId,
      photoPaths: photos.downloadUrls,
      clearPhotos: photos.downloadUrls.isEmpty,
      submittedAt: boutique.submittedAt ?? DateTime.now(),
      syncStatus: SyncStatus.synced,
    );

    final data = _buildPayload(
      payloadBoutique,
      photoStoragePaths: photos.storagePaths,
      isUpdate: false,
    );

    await docRef.set(data);

    for (final path in photos.pathsToDelete) {
      await _deleteFromStorage(path);
    }

    return payloadBoutique;
  }

  @override
  Future<Boutique> update(Boutique boutique) async {
    final docRef = _firestore.collection(_collectionName).doc(boutique.id);
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      throw StateError('Boutique introuvable');
    }
    final data = snapshot.data() ?? {};
    final existingUrls = _extractStringList(data['photoUrls']);
    if (existingUrls.isEmpty) {
      final legacy = data['photoUrl'];
      if (legacy is String && legacy.isNotEmpty) {
        existingUrls.add(legacy);
      }
    }
    final existingStoragePaths = _extractStringList(data['photoStoragePaths']);
    if (existingStoragePaths.isEmpty) {
      final legacyStorage = data['photoStoragePath'];
      if (legacyStorage is String && legacyStorage.isNotEmpty) {
        existingStoragePaths.add(legacyStorage);
      }
    }

    final photos = await _handlePhotos(
      docId: docRef.id,
      newPaths: boutique.photoPaths,
      existingUrls: existingUrls,
      existingStoragePaths: existingStoragePaths,
    );

    final collectorId = boutique.collectorId.isNotEmpty
        ? boutique.collectorId
        : (data['collectorId'] as String? ?? '');

    final payloadBoutique = boutique.copyWith(
      collectorId: collectorId,
      photoPaths: photos.downloadUrls,
      clearPhotos: photos.downloadUrls.isEmpty,
      submittedAt: boutique.submittedAt ?? DateTime.now(),
      syncStatus: SyncStatus.synced,
    );

    final updateData = _buildPayload(
      payloadBoutique,
      photoStoragePaths: photos.storagePaths,
      isUpdate: true,
    );

    await docRef.update(updateData);

    for (final path in photos.pathsToDelete) {
      await _deleteFromStorage(path);
    }

    return payloadBoutique;
  }

  static Boutique _mapDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String fallbackId, {
    String? fallbackCollectorId,
  }) {
    final raw = doc.data();
    final timestamp = raw['dateDeVisite'];
    DateTime? visitDate;
    if (timestamp is Timestamp) {
      visitDate = timestamp.toDate();
    }
    final submittedRaw = raw['submittedAt'];
    DateTime? submittedAt;
    if (submittedRaw is Timestamp) {
      submittedAt = submittedRaw.toDate();
    } else if (submittedRaw is DateTime) {
      submittedAt = submittedRaw;
    } else if (submittedRaw is String && submittedRaw.isNotEmpty) {
      submittedAt = DateTime.tryParse(submittedRaw);
    }

    final latitude = raw['latitude'];
    final longitude = raw['longitude'];
    final collectorId = (raw['collectorId'] as String?) ??
        fallbackCollectorId ??
        '';
    final specialiteRaw = raw['specialite'] as String?;

    return Boutique(
      id: raw['id'] as String? ?? fallbackId,
      nom: (raw['nom'] as String?) ?? '',
      nomGerantComplet: (raw['nomGerantComplet'] as String?) ?? '',
      collectorId: collectorId,
      specialite: boutiqueSpecialiteFromStorage(specialiteRaw),
      telephones: _readTelephones(raw),
      latitude: latitude is num ? latitude.toDouble() : null,
      longitude: longitude is num ? longitude.toDouble() : null,
      photoPaths: _readPhotoUrls(raw),
      dateDeVisite: visitDate,
      submittedAt: submittedAt,
      syncStatus: _mapSyncStatus(raw['syncStatus'] as String?),
    );
  }

  static List<String> _readTelephones(Map<String, dynamic> raw) {
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

  static List<String> _readPhotoUrls(Map<String, dynamic> raw) {
    final photos = raw['photoUrls'];
    if (photos is List) {
      return photos
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
    }
    final legacy = raw['photoUrl'];
    if (legacy is String && legacy.trim().isNotEmpty) {
      return [legacy.trim()];
    }
    return const [];
  }

  static List<String> _extractStringList(dynamic raw) {
    if (raw is Iterable) {
      return raw
          .map(
            (value) => value is String ? value.trim() : '',
          )
          .toList();
    }
    return <String>[];
  }

  static SyncStatus _mapSyncStatus(String? value) {
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

  Future<_PhotoHandlingResult> _handlePhotos({
    required String docId,
    required List<String> newPaths,
    required List<String> existingUrls,
    required List<String> existingStoragePaths,
  }) async {
    if (newPaths.isEmpty) {
      return _PhotoHandlingResult(
        downloadUrls: const [],
        storagePaths: const [],
        pathsToDelete: existingStoragePaths
            .where((path) => path.isNotEmpty)
            .toList(growable: false),
      );
    }

    final existingMap = <String, String>{};
    for (var i = 0; i < existingUrls.length; i++) {
      final url = existingUrls[i];
      if (url.isEmpty) continue;
      final storage =
          i < existingStoragePaths.length ? existingStoragePaths[i] : '';
      existingMap[url] = storage;
    }

    final downloadUrls = <String>[];
    final storagePaths = <String>[];

    for (final path in newPaths) {
      if (path.isEmpty) continue;
      if (_isRemotePath(path)) {
        downloadUrls.add(path);
        storagePaths.add(existingMap.remove(path) ?? '');
        continue;
      }

      final upload = await _uploadPhoto(docId, path);
      if (upload == null) continue;
      downloadUrls.add(upload.downloadUrl);
      storagePaths.add(upload.storagePath);
    }

    final pathsToDelete = existingMap.values
        .where((path) => path.isNotEmpty)
        .toList(growable: false);

    return _PhotoHandlingResult(
      downloadUrls: downloadUrls,
      storagePaths: storagePaths,
      pathsToDelete: pathsToDelete,
    );
  }

  Future<_UploadedPhoto?> _uploadPhoto(String docId, String localPath) async {
    final file = File(localPath);
    if (!await file.exists()) {
      return null;
    }

    final storagePath =
        'boutiques/$docId/${DateTime.now().microsecondsSinceEpoch}.jpg';
    final ref = _storage.ref(storagePath);
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    await ref.putFile(file, metadata);

    final downloadUrl = await ref.getDownloadURL();
    return _UploadedPhoto(downloadUrl: downloadUrl, storagePath: storagePath);
  }

  static Map<String, dynamic> _buildPayload(
    Boutique boutique, {
    required List<String> photoStoragePaths,
    required bool isUpdate,
  }) {
    final firstPhoto = boutique.primaryPhotoPath;
    final firstStoragePath =
        photoStoragePaths.isNotEmpty ? photoStoragePaths.first : null;
    final map = <String, dynamic>{
      'id': boutique.id,
      'nom': boutique.nom,
      'nomGerantComplet': boutique.nomGerantComplet,
      'collectorId': boutique.collectorId,
      'specialite': boutique.specialite.storageValue,
      'telephone': boutique.primaryTelephone,
      'telephones': boutique.telephones,
      'latitude': boutique.latitude,
      'longitude': boutique.longitude,
      'photoUrl': firstPhoto,
      'photoUrls': boutique.photoPaths,
      'photoStoragePath':
          firstStoragePath != null && firstStoragePath.isNotEmpty
              ? firstStoragePath
              : null,
      'photoStoragePaths': photoStoragePaths,
      'dateDeVisite': boutique.dateDeVisite != null
          ? Timestamp.fromDate(boutique.dateDeVisite!)
          : null,
      'submittedAt': boutique.submittedAt != null
          ? Timestamp.fromDate(boutique.submittedAt!)
          : FieldValue.serverTimestamp(),
      'syncStatus': 'synced',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!isUpdate) {
      map['createdAt'] = FieldValue.serverTimestamp();
    }

    return map;
  }

  @override
  Future<bool> isTelephoneAvailable(
    String collectorId,
    String telephone, {
    String? excludeId,
  }) async {
    final normalized = telephone.trim();
    if (normalized.isEmpty) {
      return false;
    }

    final collection = _firestore.collection(_collectionName);
    final results = await Future.wait([
      collection
          .where('collectorId', isEqualTo: collectorId)
          .where('telephones', arrayContains: normalized)
          .limit(5)
          .get(),
      collection
          .where('collectorId', isEqualTo: collectorId)
          .where('telephone', isEqualTo: normalized)
          .limit(5)
          .get(),
    ]);

    final inspected = <String>{};
    for (final snapshot in results) {
      for (final doc in snapshot.docs) {
        if (!inspected.add(doc.id)) continue;
        final data = doc.data();
        final docId = doc.id;
        final storedId = (data['id'] as String?) ?? '';

        final matchesExcluded =
            excludeId != null && (excludeId == docId || excludeId == storedId);
        if (!matchesExcluded) {
          return false;
        }
      }
    }

    return true;
  }

  Future<void> _deleteFromStorage(String storagePath) async {
    try {
      final ref = _storage.ref(storagePath);
      await ref.delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }

  bool _isRemotePath(String path) {
    final normalized = path.toLowerCase();
    return normalized.startsWith('http://') ||
        normalized.startsWith('https://');
  }
}

class _PhotoHandlingResult {
  const _PhotoHandlingResult({
    required this.downloadUrls,
    required this.storagePaths,
    required this.pathsToDelete,
  });

  final List<String> downloadUrls;
  final List<String> storagePaths;
  final List<String> pathsToDelete;
}

class _UploadedPhoto {
  const _UploadedPhoto({
    required this.downloadUrl,
    required this.storagePath,
  });

  final String downloadUrl;
  final String storagePath;
}
