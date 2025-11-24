/**
 * Create or update an admin Firebase Authentication user and assign the
 * `role: 'admin'` custom claim expected by the Firestore security rules.
 *
 * Usage:
 *   node scripts/create_admin_user.js <email> <password> [displayName]
 */
const path = require('path');
const admin = require('firebase-admin');

const SERVICE_ACCOUNT_PATH = process.env.FIREBASE_SERVICE_ACCOUNT || path.resolve(
  __dirname,
  '../collecte-9b6e1-firebase-adminsdk-fbsvc-44358eb6da.json',
);

function loadServiceAccount() {
  try {
    // eslint-disable-next-line global-require, import/no-dynamic-require
    return require(SERVICE_ACCOUNT_PATH);
  } catch (error) {
    if (error.code === 'MODULE_NOT_FOUND') {
      console.error(`Service account file not found at ${SERVICE_ACCOUNT_PATH}`);
    } else {
      console.error('Unable to load service account JSON:', error.message);
    }
    process.exit(1);
  }
  return null;
}

function initializeFirebase() {
  const serviceAccount = loadServiceAccount();
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  return admin.auth();
}

function parseArgs() {
  const [email, password, displayName] = process.argv.slice(2);
  if (!email || !password) {
    console.error('Usage: node scripts/create_admin_user.js <email> <password> [displayName]');
    process.exit(1);
  }
  return { email, password, displayName };
}

async function createOrUpdateUser(auth, { email, password, displayName }) {
  try {
    const existingUser = await auth.getUserByEmail(email);
    const updatePayload = { password };
    if (displayName) {
      updatePayload.displayName = displayName;
    }
    const updatedUser = await auth.updateUser(existingUser.uid, updatePayload);
    console.log(`User ${email} already existed. Password${displayName ? ' and display name' : ''} updated.`);
    return updatedUser;
  } catch (error) {
    if (error.code !== 'auth/user-not-found') {
      throw error;
    }
  }

  const payload = { email, password };
  if (displayName) {
    payload.displayName = displayName;
  }
  const newUser = await auth.createUser(payload);
  console.log(`Created user ${email} (${newUser.uid}).`);
  return newUser;
}

async function ensureAdminClaim(auth, user) {
  const currentClaims = user.customClaims || {};
  if (currentClaims.role === 'admin') {
    console.log('User already has role=admin custom claim.');
    return;
  }
  const updatedClaims = { ...currentClaims, role: 'admin' };
  await auth.setCustomUserClaims(user.uid, updatedClaims);
  console.log('Assigned role=admin custom claim.');
}

async function main() {
  const args = parseArgs();
  const auth = initializeFirebase();
  const user = await createOrUpdateUser(auth, args);
  await ensureAdminClaim(auth, user);
  console.log('Admin user ready. Have them reauthenticate to receive the new claim.');
}

main().catch((error) => {
  console.error('Failed to provision admin user:', error);
  process.exitCode = 1;
});
