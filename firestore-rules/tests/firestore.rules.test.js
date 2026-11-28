const fs = require('fs');
const path = require('path');
const {
  assertSucceeds,
  assertFails,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const firebase = require('firebase/compat/app');
require('firebase/compat/firestore');

const { FieldValue, Timestamp } = firebase.firestore;

const PROJECT_ID = 'demo-rules-test';
const ALICE = 'alice';
const BOB = 'bob';
const ADMIN = 'admin-user';

function rulesPath() {
  const override = process.env.FIRESTORE_RULES_PATH;
  if (override) return override;
  return path.join(__dirname, '..', '..', 'firestore.rules');
}

// FIRESTORE_EMULATOR_HOST is host:port, as set by the Firebase CLI.
function emulatorAddress() {
  const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST || 'localhost:8080').split(':');
  return { host, port: Number(port) };
}

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(rulesPath(), 'utf8'),
      ...emulatorAddress(),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

afterAll(async () => {
  if (testEnv) await testEnv.cleanup();
});

function aliceDb() {
  return testEnv.authenticatedContext(ALICE).firestore();
}

function bobDb() {
  return testEnv.authenticatedContext(BOB).firestore();
}

function adminDb() {
  return testEnv.authenticatedContext(ADMIN).firestore();
}

function unauthDb() {
  return testEnv.unauthenticatedContext().firestore();
}

function seedAdmin() {
  return seedDoc('roles/admins', { [ADMIN]: true });
}

async function seedDoc(docPath, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(docPath).set(data);
  });
}

function seedProduct(id, data) {
  return seedDoc(`products/${id}`, data);
}

function ownedCollection(userId, id, extra = {}) {
  return { id, name: 'Pantry', userId, productIds: [], type: 'inventory', ...extra };
}

function ownedProduct(userId, extra = {}) {
  return {
    name: 'Test Product',
    userId,
    isGlobal: false,
    productIds: [],
    ...extra,
  };
}

describe('products', () => {
  test('owner can read, write and delete their own product', async () => {
    const db = aliceDb();
    await assertSucceeds(db.collection('products').doc('p1').set(ownedProduct(ALICE)));
    await assertSucceeds(db.collection('products').doc('p1').get());
    await assertSucceeds(
      db.collection('products').doc('p1').update({ name: 'Renamed' }),
    );
    await assertSucceeds(db.collection('products').doc('p1').delete());
  });

  test('non-owner cannot read or write a personal product', async () => {
    await seedProduct('p2', ownedProduct(ALICE));
    const db = bobDb();
    await assertFails(db.collection('products').doc('p2').get());
    await assertFails(
      db.collection('products').doc('p2').update({ name: 'Hacked' }),
    );
    await assertFails(db.collection('products').doc('p2').delete());
  });

  test('a user cannot create a product owned by someone else', async () => {
    const db = bobDb();
    await assertFails(db.collection('products').doc('p3').set(ownedProduct(ALICE)));
  });

  test('a non-admin cannot create or set isGlobal on a product', async () => {
    const db = aliceDb();
    await assertFails(
      db.collection('products').doc('p6').set(ownedProduct(ALICE, { isGlobal: true })),
    );
    await seedProduct('p7', ownedProduct(ALICE));
    await assertFails(
      db.collection('products').doc('p7').update({ isGlobal: true }),
    );
  });

  test('an owner cannot re-assign userId on update', async () => {
    await seedProduct('p8', ownedProduct(ALICE));
    const db = aliceDb();
    await assertFails(
      db.collection('products').doc('p8').update({ userId: BOB }),
    );
  });

  test('signed-in users can read global products', async () => {
    await seedProduct('p4', ownedProduct('global', { isGlobal: true }));
    await assertSucceeds(bobDb().collection('products').doc('p4').get());
  });

  test('unauthenticated access is denied', async () => {
    await seedProduct('p5', ownedProduct(ALICE));
    const db = unauthDb();
    await assertFails(db.collection('products').doc('p5').get());
    await assertFails(db.collection('products').doc('p5').set(ownedProduct(BOB)));
  });
});

describe('products: admin', () => {
  beforeEach(seedAdmin);

  test('admin can create, update and delete a global product', async () => {
    const db = adminDb();
    const global = ownedProduct('global', { isGlobal: true });
    await assertSucceeds(db.collection('products').doc('g1').set(global));
    await assertSucceeds(
      db.collection('products').doc('g1').update({ name: 'Renamed' }),
    );
    await assertSucceeds(db.collection('products').doc('g1').delete());
  });

  test('admin cannot write another user\'s personal product', async () => {
    await seedProduct('p1', ownedProduct(ALICE));
    const db = adminDb();
    await assertFails(db.collection('products').doc('p1').get());
    await assertFails(db.collection('products').doc('p1').update({ name: 'x' }));
    await assertFails(db.collection('products').doc('p1').delete());
  });

  test('admin cannot set a non-global userId on a global product', async () => {
    await seedProduct('g2', ownedProduct('global', { isGlobal: true }));
    const db = adminDb();
    await assertFails(
      db.collection('products').doc('g3').set(ownedProduct(ADMIN, { isGlobal: true })),
    );
    await assertFails(
      db.collection('products').doc('g2').update({ userId: ADMIN }),
    );
  });
});

describe('collections', () => {
  test('owner can read and write their collection', async () => {
    const db = aliceDb();
    await assertSucceeds(
      db.collection('collections').doc('c1').set({
        id: 'c1',
        name: 'Pantry',
        userId: ALICE,
        productIds: [],
        type: 'inventory',
      }),
    );
    await assertSucceeds(db.collection('collections').doc('c1').get());
    await assertSucceeds(db.collection('collections').doc('c1').delete());
  });

  test('another user cannot read or write it', async () => {
    await seedDoc('collections/c2', ownedCollection(BOB, 'c2', { name: 'Bob Pantry' }));
    const db = aliceDb();
    await assertFails(db.collection('collections').doc('c2').get());
    await assertFails(
      db.collection('collections').doc('c2').update({ name: 'Stolen' }),
    );
  });

  test('an owner cannot re-assign userId on update', async () => {
    const db = aliceDb();
    await assertSucceeds(
      db.collection('collections').doc('c3').set(ownedCollection(ALICE, 'c3')),
    );
    await assertFails(
      db.collection('collections').doc('c3').update({ userId: BOB }),
    );
  });
});

describe('roles', () => {
  test('non-admins cannot read or write the admin registry', async () => {
    await seedAdmin();
    const db = aliceDb();
    await assertFails(db.collection('roles').doc('admins').get());
    await assertFails(db.collection('roles').doc('admins').set({ [ALICE]: true }));
  });

  test('admins can read but not write the admin registry', async () => {
    await seedAdmin();
    await assertSucceeds(adminDb().collection('roles').doc('admins').get());
    await assertFails(
      adminDb().collection('roles').doc('admins').update({ [BOB]: true }),
    );
  });
});

describe('queries used by the app', () => {
  beforeEach(async () => {
    await seedAdmin();
    await seedProduct('g1', ownedProduct('global', { isGlobal: true }));
    await seedProduct('a1', ownedProduct(ALICE, { registryType: 'current' }));
    await seedProduct('a2', ownedProduct(ALICE, { registryType: 'personal' }));
    await seedProduct('b1', ownedProduct(BOB, { registryType: 'current' }));
    await seedDoc('collections/ca', ownedCollection(ALICE, 'ca', { productIds: ['a1'] }));
    await seedDoc('collections/cb', ownedCollection(BOB, 'cb'));
  });

  test('own, personal, global and collection queries succeed', async () => {
    const db = aliceDb();
    const products = db.collection('products');
    await assertSucceeds(
      products.where('userId', '==', ALICE).where('isGlobal', '==', false).get(),
    );
    await assertSucceeds(
      products.where('userId', '==', ALICE).where('registryType', '==', 'personal').get(),
    );
    await assertSucceeds(products.where('isGlobal', '==', true).get());
    await assertSucceeds(db.collection('collections').where('userId', '==', ALICE).get());
  });

  test('unfiltered and foreign queries are denied', async () => {
    const db = aliceDb();
    await assertFails(db.collection('products').get());
    await assertFails(db.collection('collections').get());
    await assertFails(db.collection('products').where('userId', '==', BOB).get());
    await assertFails(db.collection('collections').where('userId', '==', BOB).get());
  });

  test('anonymous-user cleanup: query and batch delete own documents', async () => {
    const db = aliceDb();
    const snap = await assertSucceeds(
      db.collection('products').where('userId', '==', ALICE).get(),
    );
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await assertSucceeds(batch.commit());
  });
});

describe('collections write patterns', () => {
  beforeEach(() => seedDoc('collections/ca', ownedCollection(ALICE, 'ca')));

  test('arrayUnion and arrayRemove by the owner succeed; foreign denied', async () => {
    const ref = aliceDb().doc('collections/ca');
    await assertSucceeds(ref.update({ productIds: FieldValue.arrayUnion('p9') }));
    await assertSucceeds(ref.update({ productIds: FieldValue.arrayRemove('p9') }));
    await assertFails(
      bobDb().doc('collections/ca').update({ productIds: FieldValue.arrayUnion('x') }),
    );
  });

  test('batch create of own collections succeeds; a foreign one is denied', async () => {
    const db = aliceDb();
    const batch = db.batch();
    batch.set(db.doc('collections/n1'), ownedCollection(ALICE, 'n1'));
    batch.set(db.doc('collections/n2'), ownedCollection(ALICE, 'n2', { type: 'shopping' }));
    await assertSucceeds(batch.commit());
    await assertFails(db.doc('collections/n3').set(ownedCollection(BOB, 'n3')));
  });
});

describe('products: app write shapes', () => {
  test('full toJson-style update and personal registry create by the owner', async () => {
    await seedProduct('a1', ownedProduct(ALICE, { registryType: 'current' }));
    const db = aliceDb();
    await assertSucceeds(
      db.doc('products/a1').update({
        id: 'a1',
        name: 'A2',
        description: 'd',
        userId: ALICE,
        isGlobal: false,
        registryType: 'current',
        expiries: [],
        nonExpiringQuantity: 1,
        tags: [],
      }),
    );
    await assertSucceeds(
      db.doc('products/n1').set(
        ownedProduct(ALICE, { id: 'n1', registryType: 'personal', tags: [] }),
      ),
    );
  });

  test('cannot edit a global product, self-escalate or use an unknown registryType', async () => {
    await seedProduct('g1', ownedProduct('global', { isGlobal: true }));
    await seedProduct('a1', ownedProduct(ALICE, { registryType: 'current' }));
    const db = aliceDb();
    await assertFails(db.doc('products/g1').update({ name: 'x' }));
    await assertFails(db.doc('products/g1').delete());
    await assertFails(db.doc('products/n2').set(ownedProduct('global', { isGlobal: true })));
    await assertFails(db.doc('products/a1').update({ registryType: 'bogus' }));
  });
});

describe('users/{uid}/**', () => {
  test('owner reads and merge-writes preferences; others denied', async () => {
    const prefs = 'users/alice/settings/preferences';
    await assertSucceeds(aliceDb().doc(prefs).set({ expiringSoonDays: 5 }, { merge: true }));
    await assertSucceeds(aliceDb().doc(prefs).get());
    await assertFails(bobDb().doc(prefs).get());
    await assertFails(bobDb().doc(prefs).set({ x: 1 }));
    await assertFails(bobDb().doc('users/alice').get());
    await assertFails(unauthDb().doc(prefs).get());
  });
});

describe('owners/{uid}/rawEvents', () => {
  function rawEvent(id, ownerId, extra = {}) {
    return {
      id,
      ownerId,
      source: 'receipt',
      provider: 'rema',
      externalId: 'abc',
      occurredAt: Timestamp.now(),
      receivedAt: FieldValue.serverTimestamp(),
      payload: { store: 'Rema', productIds: ['1'] },
      schemaVersion: 1,
      ...extra,
    };
  }

  test('owner creates and reads once; update, delete, overwrite and foreign access denied', async () => {
    const id = 'receipt:rema:abc';
    const ref = aliceDb().doc(`owners/${ALICE}/rawEvents/${id}`);
    await assertSucceeds(ref.set(rawEvent(id, ALICE)));
    await assertSucceeds(ref.get());
    await assertFails(ref.set(rawEvent(id, ALICE)));
    await assertFails(ref.update({ payload: {} }));
    await assertFails(ref.delete());
    await assertFails(bobDb().doc(`owners/${ALICE}/rawEvents/${id}`).get());
    await assertFails(bobDb().doc(`owners/${ALICE}/rawEvents/x`).set(rawEvent('x', ALICE)));
  });

  test('owner lists their own receipts; others cannot list them', async () => {
    const id = 'receipt:rema:def';
    await assertSucceeds(aliceDb().doc(`owners/${ALICE}/rawEvents/${id}`).set(rawEvent(id, ALICE)));
    const receipts = aliceDb()
      .collection(`owners/${ALICE}/rawEvents`)
      .where('source', '==', 'receipt');
    await assertSucceeds(receipts.get());
    await assertSucceeds(aliceDb().collection(`owners/${ALICE}/rawEvents`).get());
    await assertFails(bobDb().collection(`owners/${ALICE}/rawEvents`).get());
  });

  test('malformed events are denied', async () => {
    const db = aliceDb();
    const ref = db.doc(`owners/${ALICE}/rawEvents/y`);
    await assertFails(ref.set(rawEvent('other', ALICE)));
    await assertFails(ref.set(rawEvent('y', BOB)));
    await assertFails(ref.set(rawEvent('y', ALICE, { processedSeq: 3 })));
    await assertFails(ref.set(rawEvent('y', ALICE, { receivedAt: Timestamp.fromMillis(1) })));
    await assertFails(ref.set(rawEvent('y', ALICE, { extra: 1 })));
    await assertFails(ref.set(rawEvent('y', ALICE, { source: 'hack' })));
  });
});

describe('runtime_errors', () => {
  function runtimeError(extra = {}) {
    return {
      status: 'new',
      platform: 'web',
      environment: 'prod',
      deployment_level: 'firebase-spark',
      error_type: 'StateError',
      message: 'boom',
      reason: null,
      fatal: false,
      stack_frames: ['#0 a'],
      occurred_at: new Date().toISOString(),
      occurrence_count: 1,
      ...extra,
    };
  }

  test('signed-in create succeeds; read, update, delete and bad shapes are denied', async () => {
    const db = aliceDb();
    const errors = db.collection('runtime_errors');
    const ref = await assertSucceeds(errors.add(runtimeError()));
    await assertSucceeds(errors.add(runtimeError({ reason: 'r' })));
    await assertFails(db.doc(`runtime_errors/${ref.id}`).get());
    await assertFails(db.doc(`runtime_errors/${ref.id}`).update({ status: 'done' }));
    await assertFails(db.doc(`runtime_errors/${ref.id}`).delete());
    await assertFails(errors.get());
    await assertFails(errors.add(runtimeError({ message: 'x'.repeat(501) })));
    await assertFails(errors.add(runtimeError({ status: 'resolved' })));
    await assertFails(errors.add(runtimeError({ junk: 1 })));
    await assertFails(unauthDb().collection('runtime_errors').add(runtimeError()));
  });
});

describe('_migrations and unknown paths', () => {
  test('are denied, even for an admin', async () => {
    await seedAdmin();
    await assertFails(adminDb().doc('_migrations/m1').get());
    await assertFails(adminDb().doc('_migrations/m1').set({ a: 1 }));
    await assertFails(aliceDb().doc('whatever/x').get());
  });
});
