import { expect, test } from '@playwright/test';
import { openApp, waitForDashboard } from './helpers';

test('shows all main tabs and supports navigation between them', async ({ page }) => {
  await openApp(page);
  await waitForDashboard(page);

  const tabs = ['Dashboard', 'My Inventory', 'Shopping List', 'Settings'];
  for (const tab of tabs) {
    await expect(page.getByRole('tab', { name: tab })).toBeVisible();
  }

  await page.getByRole('tab', { name: 'My Inventory' }).click();
  await expect(page.getByRole('tab', { name: 'My Inventory' })).toHaveAttribute('aria-selected', 'true');

  await page.getByRole('tab', { name: 'Shopping List' }).click();
  await expect(page.getByRole('tab', { name: 'Shopping List' })).toHaveAttribute('aria-selected', 'true');

  await page.getByRole('tab', { name: 'Settings' }).click();
  await expect(page.getByRole('tab', { name: 'Settings' })).toHaveAttribute('aria-selected', 'true');

  await page.getByRole('tab', { name: 'Dashboard' }).click();
  await expect(page.getByRole('tab', { name: 'Dashboard' })).toHaveAttribute('aria-selected', 'true');
  await expect(page.getByText('Quick Actions')).toBeVisible();
});

test('dashboard renders quick actions and overview sections', async ({ page }) => {
  await openApp(page);
  await waitForDashboard(page);

  await expect(page.getByText('Quick Actions')).toBeVisible();
  await expect(page.getByText('Create Product')).toBeVisible();
  await expect(page.getByText('New Shopping List')).toBeVisible();
  await expect(page.getByText('Overview')).toBeVisible();
});
