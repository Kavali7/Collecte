class Boutique {
  Boutique({
    required this.id,
    required this.nom,
    required this.nomGerantComplet,
    required this.collectorId,
    this.specialite = BoutiqueSpecialite.telephone,
    List<String>? telephones,
    List<String>? photoPaths,
    this.latitude,
    this.longitude,
    this.dateDeVisite,
    this.submittedAt,
    this.syncStatus = SyncStatus.synced,
  })  : telephones = _sanitizeTelephones(telephones ?? const []),
        photoPaths = _sanitizePhotoPaths(photoPaths ?? const []);

  final String id;
  final String nom;
  final String nomGerantComplet;
  final String collectorId;
  final BoutiqueSpecialite specialite;
  final List<String> telephones;
  final List<String> photoPaths;
  final double? latitude;
  final double? longitude;
  final DateTime? dateDeVisite;
  final DateTime? submittedAt;
  final SyncStatus syncStatus;

  String get primaryTelephone =>
      telephones.isNotEmpty ? telephones.first : '';
  String? get primaryPhotoPath =>
      photoPaths.isNotEmpty ? photoPaths.first : null;
  String get specialiteLabel => specialite.displayLabel;

  // Legacy getters used par d'anciens ecrans
  String get telephone => primaryTelephone;
  String? get photoPath => primaryPhotoPath;

  String get coordonneesLabel {
    if (latitude == null || longitude == null) {
      return 'Coordonnees non definies';
    }
    return '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}';
  }

  Boutique copyWith({
    String? id,
    String? nom,
    String? nomGerantComplet,
    String? collectorId,
    BoutiqueSpecialite? specialite,
    List<String>? telephones,
    double? latitude,
    double? longitude,
    List<String>? photoPaths,
    DateTime? dateDeVisite,
    DateTime? submittedAt,
    SyncStatus? syncStatus,
    bool clearLocation = false,
    bool clearPhotos = false,
    bool clearDate = false,
  }) {
    return Boutique(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      nomGerantComplet: nomGerantComplet ?? this.nomGerantComplet,
      collectorId: collectorId ?? this.collectorId,
      specialite: specialite ?? this.specialite,
      telephones: telephones ?? this.telephones,
      latitude: clearLocation ? null : (latitude ?? this.latitude),
      longitude: clearLocation ? null : (longitude ?? this.longitude),
      photoPaths: clearPhotos ? const [] : (photoPaths ?? this.photoPaths),
      dateDeVisite: clearDate ? null : (dateDeVisite ?? this.dateDeVisite),
      submittedAt: submittedAt ?? this.submittedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  static List<String> _sanitizeTelephones(List<String> values) {
    final seen = <String>{};
    final sanitized = <String>[];
    for (final value in values) {
      final normalized = value.trim();
      if (normalized.isEmpty) continue;
      if (seen.add(normalized)) {
        sanitized.add(normalized);
      }
    }
    return List.unmodifiable(sanitized);
  }

  static List<String> _sanitizePhotoPaths(List<String> values) {
    final sanitized = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    return List.unmodifiable(sanitized);
  }
}

enum SyncStatus { synced, pending, error }

enum BoutiqueSpecialite { reparation, telephone }

extension BoutiqueSpecialiteMapper on BoutiqueSpecialite {
  String get storageValue {
    switch (this) {
      case BoutiqueSpecialite.reparation:
        return 'reparation';
      case BoutiqueSpecialite.telephone:
        return 'telephone';
    }
  }

  String get displayLabel {
    switch (this) {
      case BoutiqueSpecialite.reparation:
        return 'Reparation';
      case BoutiqueSpecialite.telephone:
        return 'Telephone';
    }
  }
}

BoutiqueSpecialite boutiqueSpecialiteFromStorage(String? value) {
  switch (value) {
    case 'reparation':
      return BoutiqueSpecialite.reparation;
    case 'telephone':
      return BoutiqueSpecialite.telephone;
    default:
      return BoutiqueSpecialite.telephone;
  }
}
