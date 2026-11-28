import { expect, test, type Page } from '@playwright/test';
import {
  deleteSeededCollections,
  deleteUserCollections,
  deleteUserProducts,
  getCollectionNames,
  getDevUserUid,
  openApp,
  seedCollection,
  waitForDashboard,
} from './helpers';

// An account without products or collections is the empty one.
test.beforeEach(async () => {
  const userId = await getDevUserUid();
  await deleteSeededCollections();
  await deleteUserCollections(userId);
  await deleteUserProducts(userId);
});

test.afterEach(async () => {
  await deleteSeededCollections();
});

const button = (page: Page, name: string | RegExp) =>
  page.getByRole('button', { name, exact: true });

async function openDashboard(page: Page, width: number) {
  // Tall enough to keep every section in the semantics tree and clickable.
  await page.setViewportSize({ width, height: 2200 });
  await openApp(page);
  await waitForDashboard(page);
  await expect(page.getByText('Quick Actions', { exact: true })).toBeVisible();
}

// Phones keep their own width; a wide window is only emulated on desktop.
const wideUnlessMobile = (isMobile: boolean) => (isMobile ? 390 : 1280);

test.describe('Dashboard as the home of the app (#532)', () => {
  for (const width of [390, 1280]) {
    test(`shows inventory and shopping list sections at ${width}px`, async ({
      page,
      isMobile,
    }) => {
      test.skip(isMobile && width > 390, 'desktop layout');
      const userId = await getDevUserUid();
      await seedCollection({ id: 'e2e-home-fridge', name: 'E2E Fridge', userId, type: 'inventory' });
      await seedCollection({ id: 'e2e-home-weekend', name: 'E2E Weekend', userId, type: 'shoppingList' });
      await openDashboard(page, width);

      await expect(button(page, /^E2E Weekend /)).toBeVisible();
      await expect(button(page, 'Add Inventory')).toBeVisible();
      await expect(button(page, 'Add Shopping List')).toBeVisible();
      await expect(page.getByText('View All')).toHaveCount(0);

      await button(page, /^E2E Fridge /).click();
      await expect(button(page, 'Delete collection')).toBeVisible();
    });
  }

  test('empty sections offer to create, and the new inventory appears in place', async ({
    page,
    isMobile,
  }) => {
    const userId = await getDevUserUid();
    await openDashboard(page, wideUnlessMobile(isMobile));

    await expect(page.getByText("You don't have an inventory yet")).toBeVisible();
    await expect(page.getByText("You don't have a shopping list yet")).toBeVisible();

    await button(page, 'New Inventory').click();
    await page.getByRole('textbox', { name: 'Name' }).fill('E2E Pantry');
    await button(page, 'Create').click();

    await expect(button(page, /^E2E Pantry /)).toBeVisible();
    await expect(page.getByText("You don't have an inventory yet")).toHaveCount(0);
    await expect
      .poll(() => getCollectionNames(userId, 'inventory'))
      .toEqual(['E2E Pantry']);
  });

  test('import and export open as modals on the dashboard', async ({
    page,
    isMobile,
  }) => {
    await openDashboard(page, wideUnlessMobile(isMobile));

    await button(page, 'Import').click();
    await expect(button(page, 'Import items')).toBeVisible();
    await expect(page).toHaveURL(/\/dashboard$/);
    await button(page, 'Close').click();
    await expect(button(page, 'Import items')).toHaveCount(0);

    await button(page, 'Export').click();
    await expect(page.getByText('DATA EXPORT', { exact: true })).toBeVisible();
    const download = page.waitForEvent('download');
    await button(page, isMobile ? 'Export all (CSV)' : 'Download').dispatchEvent(
      'click',
    );
    expect((await download).suggestedFilename()).toMatch(/\.csv$/);
    await expect(page).toHaveURL(/\/dashboard$/);
  });

  test('receipt scanning is disabled without a camera, and integrations stay hidden', async ({
    page,
    isMobile,
  }) => {
    await openDashboard(page, wideUnlessMobile(isMobile));

    // The web app has no live receipt scanning, camera or not.
    const scan = page.getByRole('button', { name: /Scan Receipt/ });
    await expect(scan).toBeDisabled();
    await expect(scan).toContainText('No camera available');
    await expect(button(page, 'Integrations')).toHaveCount(0);
  });

  test('the task bar language toggle retranslates the whole screen', async ({
    page,
    isMobile,
  }) => {
    test.skip(isMobile, 'desktop affordance');
    await openDashboard(page, 1280);
    await expect(page.getByText("Let's get you started")).toBeVisible();

    await button(page, 'Norwegian').click();

    await expect(button(page, 'Logg ut')).toBeVisible();
    await expect(page.getByRole('tab', { name: 'Mitt lager' })).toBeVisible();
    await expect(page.getByText('La oss komme i gang')).toBeVisible();
    await expect(button(page, 'Registrer utløpsdato')).toBeVisible();

    await button(page, 'Engelsk').click();
    await expect(button(page, 'Sign Out')).toBeVisible();
  });

  test('desktop has a task bar whose logout signs out', async ({
    page,
    isMobile,
  }) => {
    test.skip(isMobile, 'desktop affordance');
    await openDashboard(page, 1280);

    for (const control of ['Norwegian', 'English', 'Light', 'Dark']) {
      await expect(button(page, control)).toBeVisible();
    }
    await button(page, 'Sign Out').click();

    await expect(
      page.getByRole('button', { name: 'I already have an account' }),
    ).toBeVisible({ timeout: 15_000 });
  });

  test('compact windows keep logout and the toggles out of the shell', async ({
    page,
  }) => {
    await openDashboard(page, 390);

    for (const control of ['Sign Out', 'Norwegian', 'Dark']) {
      await expect(button(page, control)).toHaveCount(0);
    }
  });
});
