import { expect, test } from '@playwright/test';
import {
  deleteSeededCollections,
  deleteUserCollections,
  getDevUserUid,
  openApp,
  seedCollection,
  waitForDashboard,
} from './helpers';

const FIRESTORE_HOST = (() => {
  const value = process.env.FIRESTORE_EMULATOR_HOST;
  if (!value) return 'http://localhost:8080';
  return value.startsWith('http://') || value.startsWith('https://')
    ? value
    : `http://${value}`;
})();
const PROJECT_ID = process.env.FIREBASE_PROJECT_ID ?? 'demo-project';
const EMULATOR_ADMIN = { Authorization: 'Bearer owner' };

async function seedGlobalEssential(product: {
  id: string;
  name: string;
  description: string;
  category: string;
  barcode: string;
}): Promise<void> {
  const res = await fetch(
    `${FIRESTORE_HOST}/v1/projects/${PROJECT_ID}/databases/(default)/documents/products?documentId=${product.id}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...EMULATOR_ADMIN },
      body: JSON.stringify({
        fields: {
          id: { stringValue: product.id },
          name: { stringValue: product.name },
          description: { stringValue: product.description },
          userId: { stringValue: 'system' },
          category: { stringValue: product.category },
          barcode: { stringValue: product.barcode },
          isGlobal: { booleanValue: true },
          registryType: { stringValue: 'global' },
          nonExpiringQuantity: { integerValue: '0' },
          expiries: { arrayValue: {} },
          tags: { arrayValue: {} },
        },
      }),
    },
  );
  expect(res.ok || res.status === 409, `seeding global ${product.id} failed: ${res.status}`).toBeTruthy();
}

async function deleteUserProducts(userId: string): Promise<void> {
  const res = await fetch(
    `${FIRESTORE_HOST}/v1/projects/${PROJECT_ID}/databases/(default)/documents/products?pageSize=200`,
    { headers: EMULATOR_ADMIN },
  );
  expect(res.ok, `listing products failed: ${res.status}`).toBeTruthy();
  const body = (await res.json()) as {
    documents?: { name: string; fields?: { userId?: { stringValue?: string } } }[];
  };
  for (const doc of body.documents ?? []) {
    if (doc.fields?.userId?.stringValue !== userId) continue;
    const id = doc.name.split('/').pop() as string;
    await fetch(
      `${FIRESTORE_HOST}/v1/projects/${PROJECT_ID}/databases/(default)/documents/products/${id}`,
      { method: 'DELETE', headers: EMULATOR_ADMIN },
    );
  }
}

test.beforeEach(async () => {
  const uid = await getDevUserUid();
  await deleteSeededCollections();
  await deleteUserCollections(uid);
  await deleteUserProducts(uid);
  await seedGlobalEssential({
    id: 'global-milk-whole',
    name: 'Whole Milk',
    description: 'Fresh whole milk, 1 l',
    category: 'dairy',
    barcode: '7090000000011',
  });
  await seedGlobalEssential({
    id: 'global-apples',
    name: 'Apples',
    description: 'Fresh apples, 1 kg',
    category: 'fruits',
    barcode: '7090000000103',
  });
});

test.afterEach(async () => {
  const uid = await getDevUserUid();
  await deleteSeededCollections();
  await deleteUserProducts(uid);
});

test('quick imports a pasted shopping list into an empty shopping list', async ({ page }) => {
  const uid = await getDevUserUid();
  await seedCollection({
    id: 'e2e-shop-quick-import',
    name: 'E2E Groceries',
    userId: uid,
    type: 'shoppingList',
  });

  await openApp(page);
  await waitForDashboard(page);

  await page.getByRole('tab', { name: 'Shopping List' }).click();
  await expect(page.getByText('E2E Groceries').first()).toBeVisible({ timeout: 15_000 });

  await page.getByRole('button', { name: 'Quick import' }).first().click();
  await expect(page.getByText('Quick import items')).toBeVisible({ timeout: 10_000 });

  await page.getByRole('textbox').last().fill('2x Whole Milk, Bread\n- Apples');
  await expect(page.getByText('3 items ready to import')).toBeVisible({ timeout: 10_000 });

  await page.getByRole('button', { name: 'Import 3 items' }).click();

  await expect(page.getByText('Whole Milk').first()).toBeVisible({ timeout: 15_000 });
  await expect(page.getByText('Bread').first()).toBeVisible();
  await expect(page.getByText('Apples').first()).toBeVisible();
});

test('browses and adds global essentials into a shopping list', async ({ page }) => {
  const uid = await getDevUserUid();
  await seedCollection({
    id: 'e2e-shop-essentials',
    name: 'E2E Essentials List',
    userId: uid,
    type: 'shoppingList',
  });

  await openApp(page);
  await waitForDashboard(page);

  await page.getByRole('tab', { name: 'Shopping List' }).click();
  await expect(page.getByText('E2E Essentials List').first()).toBeVisible({ timeout: 15_000 });

  await page.getByRole('button', { name: 'Select Products' }).click();
  await expect(page.getByText('Essentials').first()).toBeVisible({ timeout: 10_000 });
  await expect(page.getByText('Whole Milk').first()).toBeVisible({ timeout: 10_000 });

  await page.getByText('Whole Milk').first().click();
  await page.getByRole('button', { name: 'Add 1 item' }).click();

  await expect(page.getByText('Whole Milk').first()).toBeVisible({ timeout: 15_000 });
});
