const fs = require('fs');
const path = require('path');
const {
  assertSucceeds,
  assertFails,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');

const PROJECT_ID = 'demo-project';
const ALICE = 'alice';
const BOB = 'bob';
const ADMIN = 'admin-user';

function rulesPath() {
  const override = process.env.FIRESTORE_RULES_PATH;
  if (override) return override;
  return path.join(__dirname, '..', '..', 'firestore.rules');
}

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(rulesPath(), 'utf8'),
      host: 'localhost',
      port: 8080,
    },
  });
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

async function seedAdmin() {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .doc('roles/admins')
      .set({ [ADMIN]: true });
  });
}

async function seedProduct(id, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`products/${id}`).set(data);
  });
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

describe('user_products shelves', () => {
  test('owner has full access to their shelf', async () => {
    const db = aliceDb();
    await assertSucceeds(
      db.collection('user_products').doc(ALICE).collection('items').doc('i1').set({
        name: 'Shelf item',
        userId: ALICE,
      }),
    );
    await assertSucceeds(
      db.collection('user_products').doc(ALICE).collection('items').doc('i1').get(),
    );
  });

  test('other users cannot read or write a shelf', async () => {
    const db = bobDb();
    await assertFails(
      db.collection('user_products').doc(ALICE).collection('items').get(),
    );
    await assertFails(
      db
        .collection('user_products')
        .doc(ALICE)
        .collection('items')
        .doc('i2')
        .set({ name: 'Injected' }),
    );
  });
});

describe('global_products catalog', () => {
  test('signed-in users can read the catalog', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc('global_products/g1').set({ name: 'Catalog item' });
    });
    await assertSucceeds(aliceDb().collection('global_products').doc('g1').get());
  });

  test('non-admins cannot write the catalog', async () => {
    const db = aliceDb();
    await assertFails(db.collection('global_products').doc('g2').set({ name: 'X' }));
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
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc('collections/c2').set({
        id: 'c2',
        name: 'Bob Pantry',
        userId: BOB,
        productIds: [],
        type: 'inventory',
      });
    });
    const db = aliceDb();
    await assertFails(db.collection('collections').doc('c2').get());
    await assertFails(
      db.collection('collections').doc('c2').update({ name: 'Stolen' }),
    );
  });

  test('an owner cannot re-assign userId on update', async () => {
    const db = aliceDb();
    await db.collection('collections').doc('c3').set({
      id: 'c3',
      name: 'Pantry',
      userId: ALICE,
      productIds: [],
      type: 'inventory',
    });
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
