# Collecte Revendeurs

Application Flutter (Riverpod + Flutter Map) permettant de :
- authentifier un collecteur, gérer la liste/carte des boutiques et les formulaires de saisie
- visualiser l'itinéraire journalier du collecteur (points GPS issus de Firestore) dès la connexion
- afficher les statuts réseau, erreurs de localisation/synchronisation et les messages contextuels côté terrain

## Prise en main

```bash
flutter pub get
flutter run
```

## Nouvel écran « Itinéraire du collecteur »

- Disponible automatiquement après authentification via `GoRouter` (`/itineraire`).
- Carte `flutter_map` avec polyligne chronologique, marqueurs départ/arrivée et bannières d'alerte.
- Sélecteur de date (jour courant par défaut), flux Firestore filtré sur l'agent et la journée.
- Tableau scrollable (Quartier, Latitude, Longitude, Heure HH:mm) sous la carte pour auditer les points.
- Accès direct depuis la liste des boutiques (icône Route accolée à la carte) et navigation retour depuis la carte vers l’itinéraire.

## Tests et qualité

```bash
flutter analyze
flutter test
```

Les tests couvrent le repository Firestore (via `FakeFirebaseFirestore`), le contrôleur d’itinéraire et le rendu des entêtes du tableau.
