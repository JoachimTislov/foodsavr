import { expect, test } from '@playwright/test';
import {
  deleteSeededCollections,
  deleteUserCollections,
  deleteUserProducts,
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

test.beforeEach(async () => {
  const uid = await getDevUserUid();
  await deleteSeededCollections();
  await deleteUserCollections(uid);
  await deleteUserProducts(uid);
  await seedGlobalEssential({
    id: 'global-milk-whole',
    name: 'Helmelk',
    description: 'Fersk helmelk, 1 l',
    category: 'dairy',
    barcode: '7090000000011',
  });
  await seedGlobalEssential({
    id: 'global-apples',
    name: 'Epler',
    description: 'Friske epler, 1 kg',
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

  // AdaptiveSheet renders a Dialog on desktop (where Flutter Web exposes the
  // interactive controls inside role="dialog" rather than static Text children)
  // and a modal bottom sheet on mobile. Verify the modal's input and initial
  // disabled submit state on both layouts.
  const input = page.getByRole('textbox', { name: /Milk/ });
  await expect(input).toBeVisible({ timeout: 10_000 });
  await expect(page.getByRole('button', { name: 'Import items' })).toBeDisabled();

  // Flutter replaces its text-editing host when focus moves, so click and type
  // like a user rather than calling .fill() on the multiline textarea.
  await input.click();
  await expect(input).toBeFocused();
  await page.keyboard.type('2x Helmelk, Grovbrød', { delay: 20 });
  await page.keyboard.press('Enter');
  await page.keyboard.type('- Epler', { delay: 20 });

  const importButton = page.getByRole('button', { name: 'Import 3 items' });
  await expect(importButton).toBeVisible({ timeout: 10_000 });
  await expect(importButton).toBeEnabled();
  await importButton.click();

  await expect(page.getByText('Helmelk').first()).toBeVisible({ timeout: 15_000 });
  await expect(page.getByText('Grovbrød').first()).toBeVisible();
  await expect(page.getByText('Epler').first()).toBeVisible();
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
  await expect(page.getByText('Helmelk').first()).toBeVisible({ timeout: 10_000 });

  await page.getByText('Helmelk').first().click();
  await page.getByRole('button', { name: 'Add 1 item' }).click();

  await expect(page.getByText('Helmelk').first()).toBeVisible({ timeout: 15_000 });
});
