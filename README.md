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

## Provisionner un compte admin

Un script Node (`scripts/create_admin_user.js`) utilise le service account Firebase (`collecte-9b6e1-firebase-adminsdk-fbsvc-44358eb6da.json`) pour créer un utilisateur et lui appliquer le custom claim `role=admin` attendu par les règles Firestore.

```bash
cd scripts
npm install # uniquement la première fois
node create_admin_user.js <email> <mot_de_passe> [Nom complet]
```

Si l’utilisateur existe déjà, le script mettra à jour son mot de passe/nom et positionnera ou conservera les autres custom claims. Demandez au nouvel admin de se déconnecter/reconnecter pour récupérer son token contenant `role=admin`.
