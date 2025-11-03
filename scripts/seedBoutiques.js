const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { readFileSync } = require('fs');
const { resolve } = require('path');

function loadServiceAccount() {
  const serviceAccountPath = resolve(__dirname, '../.config/firebase-service-account.json');
  try {
    const raw = readFileSync(serviceAccountPath, 'utf8');
    return JSON.parse(raw);
  } catch (error) {
    console.error('Impossible de lire le fichier de compte de service:', serviceAccountPath);
    throw error;
  }
}

async function seed() {
  const serviceAccount = loadServiceAccount();

  initializeApp({
    credential: cert(serviceAccount),
  });

  const db = getFirestore();

  const boutiques = [
    {
      nom: 'Boutique Démo',
      nomGerantComplet: 'Test Utilisateur',
      telephone: '+225 01 23 45 67',
      adresse: 'Abidjan Plateau',
      latitude: 5.3234,
      longitude: -4.0245,
      photoUrl: null,
      photoStoragePath: null,
      dateDeVisite: new Date(),
      syncStatus: 'synced',
    },
  ];

  const batch = db.batch();

  boutiques.forEach((boutique) => {
    const docRef = db.collection('boutiques').doc();
    batch.set(docRef, {
      ...boutique,
      id: docRef.id,
      createdAt: new Date(),
      updatedAt: new Date(),
    });
  });

  await batch.commit();
  console.log('Seed terminé');
}

seed()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Échec du seed:', error);
    process.exit(1);
  });
