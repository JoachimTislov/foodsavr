import { expect, test } from '@playwright/test';
import {
  createInventoryViaDialog,
  deleteSeededCollections,
  getDevUserUid,
  getInventoryNames,
  openApp,
  seedCollection,
  waitForDashboard,
} from './helpers';

test.beforeEach(async () => {
  await deleteSeededCollections();
});

test.afterEach(async () => {
  await deleteSeededCollections();
});

// Every sign-in provisions a default inventory and shopping list (#334), so a
// fresh user never sees the empty collection state.
test('shows the provisioned default inventory for a new user', async ({ page }) => {
  await openApp(page);
  await waitForDashboard(page);

  // A single inventory opens directly in its detail view.
  await page.getByRole('tab', { name: 'My Inventory' }).click();
  await expect(page.getByText('Inventory', { exact: true })).toBeVisible();
  await expect(page.getByText('No products')).toBeVisible();
  await expect(page.getByText('Nothing found')).toHaveCount(0);

  const uid = await getDevUserUid();
  expect(await getInventoryNames(uid)).toEqual(['Inventory']);
});

test('creates an inventory via dialog next to the provisioned default', async ({ page }) => {
  const uid = await getDevUserUid();
  // A second inventory switches the tab from the detail view to the list.
  await seedCollection({ id: 'e2e-inv-fridge', name: 'E2E Fridge', userId: uid, type: 'inventory' });

  await openApp(page);
  await waitForDashboard(page);

  await page.getByRole('tab', { name: 'My Inventory' }).click();
  await expect(page.getByRole('button', { name: /^Inventory Inventory/ })).toBeVisible();
  await expect(page.getByRole('button', { name: /^E2E Fridge / })).toBeVisible();

  await createInventoryViaDialog(page, 'E2E Pantry');
  await expect(page.getByRole('button', { name: /^Inventory Inventory/ })).toBeVisible();
  await expect(page.getByRole('button', { name: /^E2E Fridge / })).toBeVisible();
});

test('creates a shopping list from the dashboard quick action', async ({ page }) => {
  await openApp(page);
  await waitForDashboard(page);

  await page.getByText('New Shopping List').click();
  await page.getByRole('textbox', { name: 'Name' }).fill('E2E Groceries');
  await page.getByRole('button', { name: 'Create' }).click();

  await page.getByRole('tab', { name: 'Shopping List' }).click();
  await expect(page.getByText('E2E Groceries').first()).toBeVisible({ timeout: 15_000 });
});
