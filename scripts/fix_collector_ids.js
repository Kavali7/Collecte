/**
 * Script to backfill collectorId on boutiques missing it.
 *
 * Usage:
 *   node scripts/fix_collector_ids.js
 */
const path = require('path');
const admin = require('firebase-admin');

const TARGET_COLLECTOR_ID = 'XDY2GBP5Cubc8IKx50tC4nkICYU2';
const SERVICE_ACCOUNT_PATH = path.resolve(
  __dirname,
  '../collecte-9b6e1-firebase-adminsdk-fbsvc-44358eb6da.json',
);

function initializeFirebase() {
  // Require here so the sensitive JSON is not logged accidentally.
  // eslint-disable-next-line import/no-dynamic-require, global-require
  const serviceAccount = require(SERVICE_ACCOUNT_PATH);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  return admin.firestore();
}

function needsCollectorId(value) {
  if (value === null || value === undefined) return true;
  if (typeof value !== 'string') return false;
  return value.trim().length === 0;
}

async function fetchMissingCollectorDocs(collectionRef) {
  const snapshot = await collectionRef.get();
  const toUpdate = [];

  snapshot.forEach((doc) => {
    const collectorId = doc.get('collectorId');
    if (needsCollectorId(collectorId)) {
      toUpdate.push(doc.ref);
    }
  });

  return { total: snapshot.size, toUpdate };
}

async function updateCollectorIds(refs, db) {
  const batchSize = 400;
  for (let i = 0; i < refs.length; i += batchSize) {
    const batch = db.batch();
    const chunk = refs.slice(i, i + batchSize);
    chunk.forEach((ref) => {
      batch.update(ref, {
        collectorId: TARGET_COLLECTOR_ID,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    await batch.commit();
    console.log(`Updated ${Math.min(i + chunk.length, refs.length)} / ${refs.length}`);
  }
}

async function main() {
  const db = initializeFirebase();
  const collectionRef = db.collection('boutiques');

  console.log('Scanning boutiques collection for missing collectorId...');
  const { total, toUpdate } = await fetchMissingCollectorDocs(collectionRef);

  console.log(`Total documents: ${total}`);
  console.log(`Documents needing update: ${toUpdate.length}`);

  if (toUpdate.length === 0) {
    console.log('Nothing to update. Exiting.');
    return;
  }

  await updateCollectorIds(toUpdate, db);
  console.log('All applicable documents updated successfully.');
}

main().catch((error) => {
  console.error('Failed to backfill collector IDs:', error);
  process.exitCode = 1;
});
