import { expect, test } from '@playwright/test';
import { deleteSeededCollections, getDevUserUid, openApp, seedCollection, waitForDashboard } from './helpers';

test.beforeEach(async () => {
  await deleteSeededCollections();
  const uid = await getDevUserUid();
  await seedCollection({ id: 'e2e-inv-fridge', name: 'E2E Fridge', userId: uid, type: 'inventory' });
  await seedCollection({ id: 'e2e-inv-pantry', name: 'E2E Pantry', userId: uid, type: 'inventory' });
});

test.afterEach(async () => {
  await deleteSeededCollections();
});

test('shows the transfer overview card and opens the transfer view with both locations', async ({
  page,
}) => {
  await openApp(page);
  await waitForDashboard(page);

  await page.getByText('Transfer').first().click();
  await expect(page.getByText('From Location')).toBeVisible({ timeout: 15_000 });
  await expect(page.getByText('To Location')).toBeVisible();
  await expect(page.getByText('Select products')).toBeVisible();
});
