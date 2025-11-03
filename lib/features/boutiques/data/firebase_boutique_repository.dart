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
  })  : _firestore = firestore,
        _storage = storage;

  static const String _collectionName = 'boutiques';

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  @override
  Future<List<Boutique>> loadBoutiques() async {
    final query = await _firestore
        .collection(_collectionName)
        .orderBy('createdAt', descending: true)
        .get();
    return query.docs.map((doc) => _mapDocument(doc, doc.id)).toList();
  }

  @override
  Future<Boutique> create(Boutique boutique) async {
    final docRef = _firestore.collection(_collectionName).doc();

    final photo = await _handlePhoto(
      docId: docRef.id,
      newPath: boutique.photoPath,
      existingUrl: null,
      existingStoragePath: null,
    );

    final payloadBoutique = boutique.copyWith(
      id: docRef.id,
      photoPath: photo.downloadUrl,
      clearPhoto: photo.downloadUrl == null,
      syncStatus: SyncStatus.synced,
    );

    final data = _buildPayload(
      payloadBoutique,
      photoStoragePath: photo.storagePath,
      isUpdate: false,
    );

    await docRef.set(data);

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
    final existingUrl = data['photoUrl'] as String?;
    final existingStoragePath = data['photoStoragePath'] as String?;

    final photo = await _handlePhoto(
      docId: docRef.id,
      newPath: boutique.photoPath,
      existingUrl: existingUrl,
      existingStoragePath: existingStoragePath,
    );

    final payloadBoutique = boutique.copyWith(
      photoPath: photo.downloadUrl,
      clearPhoto: photo.downloadUrl == null,
      syncStatus: SyncStatus.synced,
    );

    final updateData = _buildPayload(
      payloadBoutique,
      photoStoragePath: photo.storagePath,
      isUpdate: true,
    );

    await docRef.update(updateData);

    if (photo.pathToDelete != null) {
      await _deleteFromStorage(photo.pathToDelete!);
    }

    return payloadBoutique;
  }

  @override
  Future<void> delete(String id) async {
    final docRef = _firestore.collection(_collectionName).doc(id);
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      return;
    }
    final data = snapshot.data() ?? {};
    final storagePath = data['photoStoragePath'] as String?;

    await docRef.delete();

    if (storagePath != null && storagePath.isNotEmpty) {
      await _deleteFromStorage(storagePath);
    }
  }

  static Boutique _mapDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String fallbackId,
  ) {
    final raw = doc.data();
    final timestamp = raw['dateDeVisite'];
    DateTime? visitDate;
    if (timestamp is Timestamp) {
      visitDate = timestamp.toDate();
    }

    final latitude = raw['latitude'];
    final longitude = raw['longitude'];

    return Boutique(
      id: raw['id'] as String? ?? fallbackId,
      nom: (raw['nom'] as String?) ?? '',
      nomGerantComplet: (raw['nomGerantComplet'] as String?) ?? '',
      telephone: (raw['telephone'] as String?) ?? '',
      adresse: (raw['adresse'] as String?) ?? '',
      latitude: latitude is num ? latitude.toDouble() : null,
      longitude: longitude is num ? longitude.toDouble() : null,
      photoPath: raw['photoUrl'] as String?,
      dateDeVisite: visitDate,
      syncStatus: _mapSyncStatus(raw['syncStatus'] as String?),
    );
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

  Future<_PhotoHandlingResult> _handlePhoto({
    required String docId,
    required String? newPath,
    required String? existingUrl,
    required String? existingStoragePath,
  }) async {
    if (newPath == null || newPath.isEmpty) {
      return _PhotoHandlingResult(
        downloadUrl: null,
        storagePath: null,
        pathToDelete: existingStoragePath,
      );
    }

    if (_isRemotePath(newPath)) {
      return _PhotoHandlingResult(
        downloadUrl: newPath,
        storagePath: existingStoragePath,
        pathToDelete: null,
      );
    }

    final file = File(newPath);
    if (!await file.exists()) {
      return _PhotoHandlingResult(
        downloadUrl: existingUrl,
        storagePath: existingStoragePath,
        pathToDelete: null,
      );
    }

    final storagePath =
        'boutiques/$docId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref(storagePath);
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    await ref.putFile(file, metadata);

    final downloadUrl = await ref.getDownloadURL();

    return _PhotoHandlingResult(
      downloadUrl: downloadUrl,
      storagePath: storagePath,
      pathToDelete: existingStoragePath != null &&
              existingStoragePath.isNotEmpty &&
              existingStoragePath != storagePath
          ? existingStoragePath
          : null,
    );
  }

  static Map<String, dynamic> _buildPayload(
    Boutique boutique, {
    required String? photoStoragePath,
    required bool isUpdate,
  }) {
    final map = <String, dynamic>{
      'id': boutique.id,
      'nom': boutique.nom,
      'nomGerantComplet': boutique.nomGerantComplet,
      'telephone': boutique.telephone,
      'adresse': boutique.adresse,
      'latitude': boutique.latitude,
      'longitude': boutique.longitude,
      'photoUrl': boutique.photoPath,
      'photoStoragePath': photoStoragePath,
      'dateDeVisite': boutique.dateDeVisite != null
          ? Timestamp.fromDate(boutique.dateDeVisite!)
          : null,
      'syncStatus': 'synced',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!isUpdate) {
      map['createdAt'] = FieldValue.serverTimestamp();
    }

    return map;
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
    required this.downloadUrl,
    required this.storagePath,
    required this.pathToDelete,
  });

  final String? downloadUrl;
  final String? storagePath;
  final String? pathToDelete;
}
