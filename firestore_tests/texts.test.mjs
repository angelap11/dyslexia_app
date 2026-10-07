import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
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
  documentId,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  startAfter,
  updateDoc,
} from 'firebase/firestore';

const PROJECT_ID = 'demo-chitajlesno';
const MAX_BYTES = 200 * 1024;
const ID = 'AbCdEfGh1234567890xy';
const textPath = (uid, id = ID) => `users/${uid}/texts/${id}`;

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

const created = Timestamp.fromDate(new Date('2026-05-01T10:00:00Z'));

/// The live document shape FirestoreSavedTextsRemote writes.
const live = (fields = {}) => ({
  schemaVersion: 1,
  deleted: false,
  title: 'Мојот текст',
  source: 'listen',
  originalText: 'Добар ден, како си?',
  createdAt: created,
  updatedAt: serverTimestamp(),
  revision: 1,
  ...fields,
});

const tombstone = (fields = {}) => ({
  schemaVersion: 1,
  deleted: true,
  deletedAt: serverTimestamp(),
  createdAt: created,
  updatedAt: serverTimestamp(),
  revision: 2,
  ...fields,
});

async function seed(uid, data, id = ID) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), textPath(uid, id)), {
      ...data,
      updatedAt: Timestamp.now(),
      ...(data.deleted ? { deletedAt: Timestamp.now() } : {}),
    });
  });
}

/// Mirrors FirestoreSavedTextsRemote.commit: read, refuse tombstones,
/// bump the revision, keep createdAt and source from the server.
async function commitLikeApp(db, uid, change) {
  const ref = doc(db, textPath(uid, change.id));
  return runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    const current = snap.data();
    const serverRevision = current?.revision ?? 0;
    if (current?.deleted === true) {
      return { revision: serverRevision, alreadyDeleted: true };
    }
    const revision = Math.max(serverRevision, change.knownRevision) + 1;
    const createdAt = current?.createdAt ?? change.createdAt;
    if (change.delete) {
      tx.set(ref, {
        schemaVersion: 1,
        deleted: true,
        deletedAt: serverTimestamp(),
        createdAt,
        updatedAt: serverTimestamp(),
        revision,
      });
    } else {
      tx.set(ref, {
        schemaVersion: 1,
        deleted: false,
        title: change.title,
        source: current?.source ?? change.source,
        originalText: change.originalText,
        ...(change.simplifiedText != null ? { simplifiedText: change.simplifiedText } : {}),
        favorite: change.favorite,
        createdAt,
        updatedAt: serverTimestamp(),
        revision,
      });
    }
    return { revision, alreadyDeleted: false };
  });
}

const change = (fields = {}) => ({
  id: ID,
  delete: false,
  title: 'Мојот текст',
  source: 'listen',
  originalText: 'Добар ден',
  simplifiedText: null,
  favorite: false,
  createdAt: created,
  knownRevision: 0,
  ...fields,
});

const pageQuery = (db, uid, size = 50) =>
  query(
    collection(db, `users/${uid}/texts`),
    orderBy('updatedAt'),
    orderBy(documentId()),
    limit(size),
  );

describe('unauthenticated access', () => {
  it('cannot read, list or write texts', async () => {
    await seed('alice', live());
    const db = dbFor(null);
    await assertFails(getDoc(doc(db, textPath('alice'))));
    await assertFails(getDocs(pageQuery(db, 'alice')));
    await assertFails(setDoc(doc(db, textPath('alice', 'Other1234567')), live()));
  });
});

describe('owner access', () => {
  it('can create via the app transaction and read it back', async () => {
    const db = dbFor('alice');
    const result = await assertSucceeds(
      commitLikeApp(db, 'alice', change({ simplifiedText: 'Здраво' })),
    );
    assert.equal(result.revision, 1);
    const snap = await assertSucceeds(getDoc(doc(db, textPath('alice'))));
    assert.equal(snap.data().simplifiedText, 'Здраво');
    assert.equal(snap.data().source, 'listen');
  });

  it('can read a missing document (first upload check)', async () => {
    await assertSucceeds(getDoc(doc(dbFor('alice'), textPath('alice'))));
  });

  it('can list changes in bounded pages with a cursor', async () => {
    await seed('alice', live(), 'Text00000001');
    await seed('alice', live(), 'Text00000002');
    const db = dbFor('alice');
    const first = await assertSucceeds(getDocs(pageQuery(db, 'alice', 1)));
    assert.equal(first.size, 1);
    const last = first.docs[0];
    const next = await assertSucceeds(
      getDocs(
        query(
          collection(db, 'users/alice/texts'),
          orderBy('updatedAt'),
          orderBy(documentId()),
          startAfter(last.data().updatedAt, last.id),
          limit(50),
        ),
      ),
    );
    assert.equal(next.size, 1);
    assert.notEqual(next.docs[0].id, last.id);
  });

  it('cannot list without a limit or above 100', async () => {
    const db = dbFor('alice');
    await assertFails(getDocs(collection(db, 'users/alice/texts')));
    await assertFails(getDocs(pageQuery(db, 'alice', 101)));
  });

  it('can update with a higher revision, keeping createdAt and source', async () => {
    await seed('alice', live());
    const db = dbFor('alice');
    const result = await assertSucceeds(
      commitLikeApp(db, 'alice', change({ originalText: 'Нов текст', knownRevision: 1 })),
    );
    assert.equal(result.revision, 2);
  });

  it('can delete by writing a tombstone', async () => {
    await seed('alice', live());
    const db = dbFor('alice');
    await assertSucceeds(commitLikeApp(db, 'alice', change({ delete: true, knownRevision: 1 })));
    const snap = await getDoc(doc(db, textPath('alice')));
    assert.equal(snap.data().deleted, true);
    assert.equal(snap.data().originalText, undefined);
  });

  it('can write a tombstone for an item the server never received', async () => {
    await assertSucceeds(setDoc(doc(dbFor('alice'), textPath('alice')), tombstone({ revision: 1 })));
  });

  it('cannot hard-delete a text or a tombstone', async () => {
    await seed('alice', live());
    await assertFails(deleteDoc(doc(dbFor('alice'), textPath('alice'))));
    await seed('alice', tombstone());
    await assertFails(deleteDoc(doc(dbFor('alice'), textPath('alice'))));
  });
});

describe('cross-account access', () => {
  it('cannot read, list, create, update or delete another account\'s texts', async () => {
    await seed('alice', live());
    const bob = dbFor('bob');
    await assertFails(getDoc(doc(bob, textPath('alice'))));
    await assertFails(getDocs(pageQuery(bob, 'alice')));
    await assertFails(setDoc(doc(bob, textPath('alice', 'Bobs12345678')), live()));
    await assertFails(setDoc(doc(bob, textPath('alice')), live({ revision: 5 })));
    await assertFails(setDoc(doc(bob, textPath('alice')), tombstone({ revision: 5 })));
    await assertFails(deleteDoc(doc(bob, textPath('alice'))));
  });
});

describe('malformed documents', () => {
  const invalid = {
    'unknown field': { color: 'pink' },
    'device file path': { attachmentPath: '/data/user/0/app/x.jpg' },
    'missing title': { title: undefined },
    'empty title': { title: '' },
    'title too long': { title: 'а'.repeat(121) },
    'title not a string': { title: 5 },
    'unknown source': { source: 'web' },
    'missing originalText': { originalText: undefined },
    'empty originalText': { originalText: '' },
    'originalText not a string': { originalText: ['a'] },
    'empty simplifiedText': { simplifiedText: '' },
    'simplifiedText not a string': { simplifiedText: 3 },
    'null simplifiedText': { simplifiedText: null },
    'wrong schemaVersion': { schemaVersion: 2 },
    'missing deleted': { deleted: undefined },
    'deleted as string': { deleted: 'false' },
    'revision zero': { revision: 0 },
    'revision as string': { revision: '1' },
    'missing revision': { revision: undefined },
    'client updatedAt': { updatedAt: Timestamp.now() },
    'createdAt as string': { createdAt: '2026-05-01' },
    'createdAt far in the future': {
      createdAt: Timestamp.fromDate(new Date(Date.now() + 3 * 86400000)),
    },
    'live text with deletedAt': { deletedAt: serverTimestamp() },
    'favorite as string': { favorite: 'true' },
    'favorite as number': { favorite: 1 },
    'null favorite': { favorite: null },
  };

  for (const [name, fields] of Object.entries(invalid)) {
    it(`rejects ${name}`, async () => {
      const data = live(fields);
      for (const key of Object.keys(data)) if (data[key] === undefined) delete data[key];
      await assertFails(setDoc(doc(dbFor('alice'), textPath('alice')), data));
    });
  }

  it('accepts a 120-character title and an old createdAt', async () => {
    await assertSucceeds(
      setDoc(
        doc(dbFor('alice'), textPath('alice')),
        live({ title: 'а'.repeat(120), createdAt: Timestamp.fromDate(new Date('2024-01-01')) }),
      ),
    );
  });

  for (const badId of ['short', 'has space1234', 'x'.repeat(65), 'dots.are.bad1']) {
    it(`rejects text id "${badId.slice(0, 20)}"`, async () => {
      await assertFails(setDoc(doc(dbFor('alice'), textPath('alice', badId)), live()));
    });
  }

  it('rejects malformed tombstones', async () => {
    const ref = doc(dbFor('alice'), textPath('alice'));
    await assertFails(setDoc(ref, tombstone({ originalText: 'kept' })));
    await assertFails(setDoc(ref, tombstone({ deletedAt: Timestamp.now() })));
    const missing = tombstone();
    delete missing.deletedAt;
    await assertFails(setDoc(ref, missing));
    await assertFails(setDoc(ref, tombstone({ favorite: true })));
  });
});

describe('favourites', () => {
  it('accepts a boolean star, or none (older app versions)', async () => {
    const ref = doc(dbFor('alice'), textPath('alice'));
    await assertSucceeds(setDoc(ref, live({ favorite: true })));
    await assertSucceeds(setDoc(ref, live({ favorite: false, revision: 2 })));
    await assertSucceeds(setDoc(ref, live({ revision: 3 })));
  });

  it('starring syncs through the app transaction as a new revision', async () => {
    const db = dbFor('alice');
    await assertSucceeds(commitLikeApp(db, 'alice', change()));
    const result = await assertSucceeds(
      commitLikeApp(db, 'alice', change({ favorite: true, knownRevision: 1 })),
    );
    assert.equal(result.revision, 2);
    const snap = await getDoc(doc(db, textPath('alice')));
    assert.equal(snap.data().favorite, true);
  });

  it('another account cannot star or unstar a text', async () => {
    await seed('alice', live({ favorite: true }));
    await assertFails(
      setDoc(doc(dbFor('bob'), textPath('alice')), live({ favorite: false, revision: 2 })),
    );
    await assertFails(
      updateDoc(doc(dbFor('bob'), textPath('alice')), { favorite: false, revision: 2 }),
    );
  });
});

describe('payload limits (UTF-8 bytes)', () => {
  // Cyrillic letters take two bytes in UTF-8.
  const exact = 'а'.repeat(MAX_BYTES / 2);

  it('accepts both text fields at exactly the limit', async () => {
    await assertSucceeds(
      setDoc(
        doc(dbFor('alice'), textPath('alice')),
        live({ originalText: exact, simplifiedText: exact }),
      ),
    );
  });

  it('rejects one byte over the limit in either field', async () => {
    const ref = doc(dbFor('alice'), textPath('alice'));
    await assertFails(setDoc(ref, live({ originalText: `${exact}x` })));
    await assertFails(setDoc(ref, live({ simplifiedText: `${exact}x` })));
  });
});

describe('updates', () => {
  it('requires a higher revision', async () => {
    await seed('alice', live({ revision: 3 }));
    const ref = doc(dbFor('alice'), textPath('alice'));
    await assertFails(setDoc(ref, live({ revision: 3 })));
    await assertFails(setDoc(ref, live({ revision: 2 })));
    await assertSucceeds(setDoc(ref, live({ revision: 4 })));
  });

  it('keeps createdAt and source immutable', async () => {
    await seed('alice', live());
    const ref = doc(dbFor('alice'), textPath('alice'));
    await assertFails(setDoc(ref, live({ revision: 2, createdAt: Timestamp.now() })));
    await assertFails(setDoc(ref, live({ revision: 2, source: 'camera' })));
  });

  it('rejects a partial update that breaks the schema', async () => {
    await seed('alice', live());
    await assertFails(
      updateDoc(doc(dbFor('alice'), textPath('alice')), { originalText: '', revision: 2 }),
    );
  });
});

describe('deletion is final', () => {
  it('denies any write to a tombstone', async () => {
    await seed('alice', tombstone({ revision: 2 }));
    const ref = doc(dbFor('alice'), textPath('alice'));
    await assertFails(setDoc(ref, live({ revision: 3 })));
    await assertFails(setDoc(ref, tombstone({ revision: 3 })));
  });

  it('a stale offline device cannot resurrect a deleted item', async () => {
    // Device A and device B both have revision 1.
    await seed('alice', live({ revision: 1 }));
    const deviceA = dbFor('alice');
    const deviceB = env.authenticatedContext('alice').firestore();

    await commitLikeApp(deviceA, 'alice', change({ delete: true, knownRevision: 1 }));

    // B comes back online and retries its old pending edit.
    const result = await commitLikeApp(
      deviceB,
      'alice',
      change({ originalText: 'Стара измена', knownRevision: 1 }),
    );
    assert.equal(result.alreadyDeleted, true);

    // A client that skips the check is rejected by the rules.
    await assertFails(
      setDoc(doc(deviceB, textPath('alice')), live({ originalText: 'Стара', revision: 9 })),
    );
    const snap = await getDoc(doc(deviceA, textPath('alice')));
    assert.equal(snap.data().deleted, true);
  });

  it('«Избриши сè»: stale edits and stars cannot restore any item', async () => {
    const ids = ['DelAll000001', 'DelAll000002', 'DelAll000003'];
    for (const id of ids) await seed('alice', live({ revision: 1 }), id);
    await seed('bob', live({ revision: 1 }), ids[0]);
    const deviceA = dbFor('alice');
    const deviceB = env.authenticatedContext('alice').firestore();

    // Device A deletes everything (queued offline, sent later).
    for (const id of ids) {
      await assertSucceeds(
        commitLikeApp(deviceA, 'alice', change({ id, delete: true, knownRevision: 1 })),
      );
    }

    // Device B was offline with an edit and a star.
    const edit = await commitLikeApp(
      deviceB,
      'alice',
      change({ id: ids[0], originalText: 'Стара измена', knownRevision: 1 }),
    );
    const star = await commitLikeApp(
      deviceB,
      'alice',
      change({ id: ids[1], favorite: true, knownRevision: 1 }),
    );
    assert.equal(edit.alreadyDeleted, true);
    assert.equal(star.alreadyDeleted, true);
    for (const id of ids) {
      await assertFails(
        setDoc(doc(deviceB, textPath('alice', id)), live({ favorite: true, revision: 9 })),
      );
      const snap = await getDoc(doc(deviceA, textPath('alice', id)));
      assert.equal(snap.data().deleted, true);
    }

    // Another account's text with the same id is unaffected.
    const bobs = await getDoc(doc(dbFor('bob'), textPath('bob', ids[0])));
    assert.equal(bobs.data().deleted, false);
  });

  it('concurrent edits: the last acknowledged upload wins', async () => {
    const a = dbFor('alice');
    const b = env.authenticatedContext('alice').firestore();
    await commitLikeApp(a, 'alice', change({ originalText: 'A1' }));
    const fromB = await commitLikeApp(b, 'alice', change({ originalText: 'B1', knownRevision: 1 }));
    const fromA = await commitLikeApp(a, 'alice', change({ originalText: 'A2', knownRevision: 1 }));
    assert.equal(fromB.revision, 2);
    assert.equal(fromA.revision, 3);
    const snap = await getDoc(doc(a, textPath('alice')));
    assert.equal(snap.data().originalText, 'A2');
  });
});
