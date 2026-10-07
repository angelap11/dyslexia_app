// Verifies (instead of assuming) what happens to a write queued offline by
// user A when A signs out and B signs in on the same client.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, it } from 'node:test';

import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { deleteApp, initializeApp } from 'firebase/app';
import {
  connectAuthEmulator,
  createUserWithEmailAndPassword,
  inMemoryPersistence,
  initializeAuth,
  signInWithEmailAndPassword,
  signOut,
} from 'firebase/auth';
import {
  connectFirestoreEmulator,
  disableNetwork,
  doc,
  enableNetwork,
  getDoc,
  initializeFirestore,
  serverTimestamp,
  setDoc,
  terminate,
} from 'firebase/firestore';

const PROJECT_ID = 'demo-chitajlesno';
const PASSWORD = 'test-password-123';
const prefsPath = (uid) => `users/${uid}/settings/preferences`;
const withMeta = (fields) => ({ ...fields, schemaVersion: 1, updatedAt: serverTimestamp() });
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

let env;
let app;
let auth;
let db;
const uids = {};

async function serverCopy(uid) {
  let data;
  await env.withSecurityRulesDisabled(async (ctx) => {
    data = (await getDoc(doc(ctx.firestore(), prefsPath(uid)))).data();
  });
  return data;
}

async function signInAs(name) {
  if (auth.currentUser) await signOut(auth);
  await signInWithEmailAndPassword(auth, `${name}@example.com`, PASSWORD);
  assert.equal(auth.currentUser.uid, uids[name]);
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
  await env.clearFirestore();

  app = initializeApp({ projectId: PROJECT_ID, apiKey: 'demo-api-key' }, 'queue-test');
  auth = initializeAuth(app, { persistence: inMemoryPersistence });
  connectAuthEmulator(auth, `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}`, {
    disableWarnings: true,
  });
  db = initializeFirestore(app, {});
  const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
  connectFirestoreEmulator(db, host, Number(port));

  // Each emulators:exec run starts with an empty Auth emulator.
  for (const name of ['alice', 'bob']) {
    const cred = await createUserWithEmailAndPassword(auth, `${name}@example.com`, PASSWORD);
    uids[name] = cred.user.uid;
    await signOut(auth);
  }
});

after(async () => {
  if (db) await terminate(db);
  if (app) await deleteApp(app);
  await env?.cleanup();
});

it('A\'s offline write stays with A across B\'s session and is sent when A returns', async () => {
  const { alice, bob } = uids;

  await signInAs('alice');
  await setDoc(doc(db, prefsPath(alice)), withMeta({ fontScale: 1 }));
  await signInAs('bob');
  await setDoc(doc(db, prefsPath(bob)), withMeta({ fontScale: 1 }));
  await signInAs('alice');

  // A edits while offline; the SDK queues the write.
  await disableNetwork(db);
  let aliceWrite = 'pending';
  const aliceWritePromise = setDoc(doc(db, prefsPath(alice)), withMeta({ fontScale: 1.4 }), {
    merge: true,
  }).then(
    () => {
      aliceWrite = 'acknowledged';
    },
    (error) => {
      aliceWrite = `rejected: ${error.code}`;
    },
  );

  // A signs out offline, B signs in, and the device reconnects.
  await signInAs('bob');
  await enableNetwork(db);
  await setDoc(doc(db, prefsPath(bob)), withMeta({ speechRate: 0.3 }), { merge: true });
  await sleep(1500);

  assert.equal(aliceWrite, 'pending', 'A\'s write must not settle during B\'s session');
  assert.equal((await serverCopy(alice)).fontScale, 1, 'A\'s write must not be sent as B');
  const bobDoc = await serverCopy(bob);
  assert.equal(bobDoc.fontScale, 1, 'A\'s value must never land in B\'s document');
  assert.equal(bobDoc.speechRate, 0.3);

  // A signs in again on this client: the queued write is sent for A.
  await signInAs('alice');
  await Promise.race([
    aliceWritePromise,
    sleep(10000).then(() => assert.fail('A\'s queued write was not sent after A returned')),
  ]);

  assert.equal(aliceWrite, 'acknowledged');
  assert.equal((await serverCopy(alice)).fontScale, 1.4);
  assert.equal((await serverCopy(bob)).fontScale, 1);
});
