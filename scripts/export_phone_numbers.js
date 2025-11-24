/**
 * Export all collected phone numbers from Firestore into numero.txt.
 *
 * Usage:
 *   node scripts/export_phone_numbers.js
 */
const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const ROOT_DIR = path.resolve(__dirname, '..');
const SERVICE_ACCOUNT_PATH = path.join(
  ROOT_DIR,
  'collecte-9b6e1-firebase-adminsdk-fbsvc-44358eb6da.json'
);
const OUTPUT_PATH = path.join(ROOT_DIR, 'numero.txt');
const COLLECTION_NAME = 'boutiques';

function initializeFirestore() {
  // eslint-disable-next-line import/no-dynamic-require, global-require
  const serviceAccount = require(SERVICE_ACCOUNT_PATH);
  if (admin.apps.length === 0) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  }
  return admin.firestore();
}

function normalizeTelephone(value) {
  if (typeof value !== 'string') return '';
  return value.replace(/\s+/g, ' ').trim();
}

function collectTelephonesFromDoc(doc) {
  const telephones = new Set();
  const arrayField = doc.get('telephones');
  if (Array.isArray(arrayField)) {
    arrayField.forEach((entry) => {
      const normalized = normalizeTelephone(entry);
      if (normalized) telephones.add(normalized);
    });
  }

  const legacyField = normalizeTelephone(doc.get('telephone'));
  if (legacyField) telephones.add(legacyField);

  return telephones;
}

function normalizeName(value) {
  if (typeof value !== 'string') return '';
  return value.replace(/\s+/g, ' ').trim();
}

function recordTelephoneContact(map, telephone, boutiqueName, gerantName) {
  if (!map.has(telephone)) {
    map.set(telephone, {
      telephone,
      boutiques: new Set(),
      gerants: new Set(),
    });
  }

  const entry = map.get(telephone);
  if (boutiqueName) entry.boutiques.add(boutiqueName);
  if (gerantName) entry.gerants.add(gerantName);
}

async function fetchAllContacts(db) {
  const snapshot = await db.collection(COLLECTION_NAME).get();
  const contacts = new Map();

  snapshot.forEach((doc) => {
    const boutiqueName = normalizeName(doc.get('nom'));
    const gerantName = normalizeName(doc.get('nomGerantComplet'));
    collectTelephonesFromDoc(doc).forEach((phone) => {
      recordTelephoneContact(contacts, phone, boutiqueName, gerantName);
    });
  });

  const asArray = Array.from(contacts.values()).map((entry) => ({
    telephone: entry.telephone,
    boutiques: Array.from(entry.boutiques).sort((a, b) => a.localeCompare(b, 'fr')),
    gerants: Array.from(entry.gerants).sort((a, b) => a.localeCompare(b, 'fr')),
  }));

  asArray.sort((a, b) => {
    const nameA = a.gerants[0] ?? '';
    const nameB = b.gerants[0] ?? '';
    const nameComparison = nameA.localeCompare(nameB, 'fr');
    if (nameComparison !== 0) return nameComparison;
    return a.telephone.localeCompare(b.telephone, 'fr');
  });

  return asArray;
}

function formatList(values, fallback) {
  if (!values || values.length === 0) return fallback;
  return values.join(', ');
}

function csvValue(value) {
  if (value == null) return '';
  const stringValue = String(value);
  if (/[",\n]/.test(stringValue)) {
    return `"${stringValue.replace(/"/g, '""')}"`;
  }
  return stringValue;
}

function serializeContacts(contacts) {
  const header = ['Telephone', 'Nom(s) personne', 'Boutique(s)'];
  const rows = contacts.map((contact) => {
    const gerants = formatList(contact.gerants, 'Nom non renseigne');
    const boutiques = formatList(contact.boutiques, 'Boutique non renseignee');
    return [contact.telephone, gerants, boutiques];
  });

  const serializeRow = (columns) => columns.map(csvValue).join(',');
  return [header, ...rows].map(serializeRow).join('\n').concat('\n');
}

async function main() {
  const db = initializeFirestore();
  const contacts = await fetchAllContacts(db);
  fs.writeFileSync(OUTPUT_PATH, serializeContacts(contacts), 'utf8');
  console.log(`[OK] ${contacts.length} numeros enrichis dans ${OUTPUT_PATH}`);
}

main().catch((error) => {
  console.error('[ERREUR] Impossible de generer la liste des numeros :', error);
  process.exitCode = 1;
});
