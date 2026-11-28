import { expect, test, type Page } from '@playwright/test';
import {
  createInventoryViaDialog,
  deleteSeededCollections,
  deleteUserCollections,
  deleteUserProducts,
  getCollectionNames,
  getDevUserUid,
  openApp,
  seedCollection,
  waitForDashboard,
} from './helpers';

const NO_INVENTORY = "You don't have an inventory yet";
const NO_SHOPPING_LIST = "You don't have a shopping list yet";

test.beforeEach(async () => {
  const uid = await getDevUserUid();
  await deleteSeededCollections();
  await deleteUserCollections(uid);
  await deleteUserProducts(uid);
});

test.afterEach(async () => {
  await deleteSeededCollections();
});

async function createFromKickstart(page: Page, button: string, name: string): Promise<void> {
  const action = page.getByRole('button', { name: button, exact: true });
  await expect(action).toBeVisible({ timeout: 15_000 });
  await action.scrollIntoViewIfNeeded();
  await action.click();
  const field = page.getByRole('textbox', { name: 'Name' });
  await expect(field).toBeVisible({ timeout: 10_000 });
  await field.click();
  await expect(field).toBeFocused();
  await page.keyboard.type(name, { delay: 20 });
  await expect(field).toHaveValue(name);
  await page.getByRole('button', { name: 'Create', exact: true }).click();
}

test('provisions nothing for a new user and shows the kickstarts', async ({ page }) => {
  await openApp(page);
  await waitForDashboard(page);
  await expect(page.getByText("Let's get you started")).toBeVisible();

  await page.getByRole('tab', { name: 'My Inventory' }).click();
  await expect(page.getByText(NO_INVENTORY)).toBeVisible();

  await page.getByRole('tab', { name: 'Shopping List' }).click();
  await expect(page.getByText(NO_SHOPPING_LIST)).toBeVisible();

  const uid = await getDevUserUid();
  expect(await getCollectionNames(uid, 'inventory')).toEqual([]);
  expect(await getCollectionNames(uid, 'shoppingList')).toEqual([]);
});

test('creates the first inventory and deletes it again', async ({ page, browser }) => {
  const uid = await getDevUserUid();
  await openApp(page);
  await waitForDashboard(page);

  await page.getByRole('tab', { name: 'My Inventory' }).click();
  await createFromKickstart(page, 'Create Inventory', 'E2E Cellar');
  const card = page.getByRole('button', { name: /^E2E Cellar / });
  await expect(card).toBeVisible({ timeout: 15_000 });
  await expect
    .poll(() => getCollectionNames(uid, 'inventory'))
    .toEqual(['E2E Cellar']);

  await card.click();
  await page.getByRole('button', { name: 'Delete collection' }).click();
  // An empty inventory has a single confirm action.
  await page.getByRole('button', { name: 'Delete', exact: true }).click();

  await expect(page.getByText(NO_INVENTORY)).toBeVisible({ timeout: 15_000 });
  await expect.poll(() => getCollectionNames(uid, 'inventory')).toEqual([]);

  // The next sign-in must not put a default back.
  const nextSession = await browser.newContext();
  const nextPage = await nextSession.newPage();
  await openApp(nextPage);
  await waitForDashboard(nextPage);
  await nextPage.getByRole('tab', { name: 'My Inventory' }).click();
  await expect(nextPage.getByText(NO_INVENTORY)).toBeVisible();
  await nextSession.close();
  expect(await getCollectionNames(uid, 'inventory')).toEqual([]);
});

test('creates a shopping list from the empty state', async ({ page }) => {
  const uid = await getDevUserUid();
  await openApp(page);
  await waitForDashboard(page);

  await page.getByRole('tab', { name: 'Shopping List' }).click();
  await createFromKickstart(page, 'Create Shopping List', 'E2E Weekend');

  await expect(page.getByRole('button', { name: /^E2E Weekend / })).toBeVisible({
    timeout: 15_000,
  });
  await expect
    .poll(() => getCollectionNames(uid, 'shoppingList'))
    .toEqual(['E2E Weekend']);
  expect(await getCollectionNames(uid, 'inventory')).toEqual([]);
});

test('adds an inventory from the list of several', async ({ page }) => {
  const uid = await getDevUserUid();
  // Two inventories keep the tab on the list instead of a detail view.
  await seedCollection({ id: 'e2e-inv-fridge', name: 'E2E Fridge', userId: uid, type: 'inventory' });
  await seedCollection({ id: 'e2e-inv-freezer', name: 'E2E Freezer', userId: uid, type: 'inventory' });

  await openApp(page);
  await waitForDashboard(page);

  await page.getByRole('tab', { name: 'My Inventory' }).click();
  await expect(page.getByRole('button', { name: /^E2E Fridge / })).toBeVisible();

  await createInventoryViaDialog(page, 'E2E Pantry');
  await expect(page.getByRole('button', { name: /^E2E Fridge / })).toBeVisible();
  await expect(page.getByRole('button', { name: /^E2E Freezer / })).toBeVisible();
});

test('creates a shopping list from the dashboard quick action', async ({ page }) => {
  await openApp(page);
  await waitForDashboard(page);

  await createFromKickstart(page, 'New Shopping List', 'E2E Groceries');

  await page.getByRole('tab', { name: 'Shopping List' }).click();
  await expect(page.getByText('E2E Groceries').first()).toBeVisible({ timeout: 15_000 });
});
