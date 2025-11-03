class Boutique {
  const Boutique({
    required this.id,
    required this.nom,
    required this.nomGerantComplet,
    required this.telephone,
    required this.adresse,
    this.latitude,
    this.longitude,
    this.photoPath,
    this.dateDeVisite,
    this.syncStatus = SyncStatus.synced,
  });

  final String id;
  final String nom;
  final String nomGerantComplet;
  final String telephone;
  final String adresse;
  final double? latitude;
  final double? longitude;
  final String? photoPath;
  final DateTime? dateDeVisite;
  final SyncStatus syncStatus;

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
    String? telephone,
    String? adresse,
    double? latitude,
    double? longitude,
    String? photoPath,
    DateTime? dateDeVisite,
    SyncStatus? syncStatus,
    bool clearLocation = false,
    bool clearPhoto = false,
    bool clearDate = false,
  }) {
    return Boutique(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      nomGerantComplet: nomGerantComplet ?? this.nomGerantComplet,
      telephone: telephone ?? this.telephone,
      adresse: adresse ?? this.adresse,
      latitude: clearLocation ? null : (latitude ?? this.latitude),
      longitude: clearLocation ? null : (longitude ?? this.longitude),
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
      dateDeVisite: clearDate ? null : (dateDeVisite ?? this.dateDeVisite),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

enum SyncStatus { synced, pending, error }
