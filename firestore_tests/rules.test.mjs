import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  runTransaction,
  serverTimestamp,
  setDoc,
} from 'firebase/firestore';

const PROJECT_ID = 'demo-chitajlesno';
const prefsPath = (uid) => `users/${uid}/settings/preferences`;

/// Same shape the app writes: synced fields + schemaVersion + updatedAt.
const withMeta = (fields) => ({
  ...fields,
  schemaVersion: 1,
  updatedAt: serverTimestamp(),
});

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

const dbFor = (uid) =>
  uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();

async function seed(uid, data) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), prefsPath(uid)), {
      schemaVersion: 1,
      updatedAt: Timestamp.now(),
      ...data,
    });
  });
}

describe('unauthenticated access', () => {
  it('cannot read preferences', async () => {
    await seed('alice', { fontScale: 1.2 });
    await assertFails(getDoc(doc(dbFor(null), prefsPath('alice'))));
  });

  it('cannot write preferences', async () => {
    await assertFails(setDoc(doc(dbFor(null), prefsPath('alice')), withMeta({ fontScale: 1 })));
  });
});

describe('owner access', () => {
  it('can read a missing document (first sync check)', async () => {
    await assertSucceeds(getDoc(doc(dbFor('alice'), prefsPath('alice'))));
  });

  it('can create with every synced key at valid values', async () => {
    await assertSucceeds(
      setDoc(
        doc(dbFor('alice'), prefsPath('alice')),
        withMeta({
          fontScale: 1.2,
          dyslexiaFont: true,
          focusMode: false,
          highContrastMode: true,
          speechRate: 0.5,
          readingRulerHeight: 76,
          readingRulerDimOpacity: 0.5,
        }),
      ),
    );
  });

  it('can merge-update a single field (app write path)', async () => {
    await seed('alice', { fontScale: 1.2, speechRate: 0.5 });
    await assertSucceeds(
      setDoc(doc(dbFor('alice'), prefsPath('alice')), withMeta({ speechRate: 0.8 }), {
        merge: true,
      }),
    );
  });

  it('can create-if-absent in a transaction (app init path)', async () => {
    const db = dbFor('alice');
    const ref = doc(db, prefsPath('alice'));
    await assertSucceeds(
      runTransaction(db, async (tx) => {
        const snap = await tx.get(ref);
        if (snap.exists()) return false;
        tx.set(ref, withMeta({ fontScale: 1.2 }));
        return true;
      }),
    );
  });

  it('accepts the exact UI boundaries', async () => {
    const db = dbFor('alice');
    for (const fields of [
      { fontScale: 14 / 17, speechRate: 0.3, readingRulerHeight: 48, readingRulerDimOpacity: 0.2 },
      { fontScale: 26 / 17, speechRate: 0.8, readingRulerHeight: 120, readingRulerDimOpacity: 0.75 },
    ]) {
      await assertSucceeds(setDoc(doc(db, prefsPath('alice')), withMeta(fields)));
    }
  });

  it('cannot delete', async () => {
    await seed('alice', { fontScale: 1.2 });
    await assertFails(deleteDoc(doc(dbFor('alice'), prefsPath('alice'))));
  });

  it('cannot list the settings collection', async () => {
    await seed('alice', { fontScale: 1.2 });
    await assertFails(getDocs(collection(dbFor('alice'), 'users/alice/settings')));
  });
});

describe('cross-user access', () => {
  it('cannot read another user\'s preferences', async () => {
    await seed('alice', { fontScale: 1.2 });
    await assertFails(getDoc(doc(dbFor('bob'), prefsPath('alice'))));
  });

  it('cannot create or update another user\'s preferences', async () => {
    await assertFails(setDoc(doc(dbFor('bob'), prefsPath('alice')), withMeta({ fontScale: 1 })));
    await seed('alice', { fontScale: 1.2 });
    await assertFails(
      setDoc(doc(dbFor('bob'), prefsPath('alice')), withMeta({ fontScale: 1 }), { merge: true }),
    );
  });
});

describe('invalid values', () => {
  const invalid = {
    'device-only darkMode': { darkMode: true },
    'device-only readingRulerEnabled': { readingRulerEnabled: true },
    'retired wordFocusEnabled': { wordFocusEnabled: true },
    'unknown key': { theme: 'pink' },
    'fontScale as string': { fontScale: '1.2' },
    'fontScale too small': { fontScale: 0.5 },
    'fontScale too large': { fontScale: 2 },
    'speechRate too fast': { speechRate: 1 },
    'speechRate too slow': { speechRate: 0.1 },
    'rulerHeight too large': { readingRulerHeight: 200 },
    'rulerHeight too small': { readingRulerHeight: 10 },
    'dim opacity too high': { readingRulerDimOpacity: 0.9 },
    'dim opacity too low': { readingRulerDimOpacity: 0.1 },
    'dyslexiaFont as string': { dyslexiaFont: 'true' },
    'focusMode as number': { focusMode: 1 },
    'highContrastMode null': { highContrastMode: null },
  };

  for (const [name, fields] of Object.entries(invalid)) {
    it(`rejects ${name}`, async () => {
      await assertFails(setDoc(doc(dbFor('alice'), prefsPath('alice')), withMeta(fields)));
    });
  }

  it('rejects a wrong schemaVersion', async () => {
    await assertFails(
      setDoc(doc(dbFor('alice'), prefsPath('alice')), {
        fontScale: 1,
        schemaVersion: 2,
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('rejects a missing or client-chosen updatedAt', async () => {
    const ref = doc(dbFor('alice'), prefsPath('alice'));
    await assertFails(setDoc(ref, { fontScale: 1, schemaVersion: 1 }));
    await assertFails(
      setDoc(ref, { fontScale: 1, schemaVersion: 1, updatedAt: Timestamp.fromMillis(0) }),
    );
  });

  it('rejects a merge that adds an invalid field to a valid document', async () => {
    await seed('alice', { fontScale: 1.2 });
    await assertFails(
      setDoc(doc(dbFor('alice'), prefsPath('alice')), withMeta({ speechRate: 5 }), {
        merge: true,
      }),
    );
  });
});

describe('everything outside the synced paths is denied', () => {
  const paths = [
    'users/alice',
    'users/alice/settings/other',
    'users/alice/texts/abcdefgh12/extra/x',
    'users/alice/stats/s1',
    'preferences/alice',
  ];

  for (const path of paths) {
    it(`owner cannot read or write ${path}`, async () => {
      const ref = doc(dbFor('alice'), path);
      await assertFails(getDoc(ref));
      await assertFails(setDoc(ref, withMeta({ fontScale: 1 })));
    });
  }
});
