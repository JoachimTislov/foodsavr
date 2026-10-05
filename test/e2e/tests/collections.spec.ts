import { expect, test } from '@playwright/test';
import { createInventoryViaDialog, deleteSeededCollections, openApp, waitForDashboard } from './helpers';

test.beforeEach(async () => {
  await deleteSeededCollections();
});

test.afterEach(async () => {
  await deleteSeededCollections();
});

test('creates an inventory from the empty state via dialog', async ({ page }) => {
  await openApp(page);
  await waitForDashboard(page);

  await page.getByRole('tab', { name: 'My Inventory' }).click();
  await expect(page.getByText('Nothing found')).toBeVisible();

  await createInventoryViaDialog(page, 'E2E Pantry');
  await expect(page.getByText('E2E Pantry').first()).toBeVisible();
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
