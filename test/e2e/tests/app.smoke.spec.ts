import { test, expect } from '@playwright/test';
import { openApp, waitForDashboard } from './helpers';

test('app boots and renders the Flutter view', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveTitle(/.+/);
  await expect(page.locator('flutter-view, flt-glass-pane').first()).toBeVisible({
    timeout: 30_000,
  });
});

test('app does not hit uncaught page errors or console errors', async ({ page }) => {
  const pageErrors: string[] = [];
  const consoleErrors: string[] = [];
  page.on('pageerror', (err) => pageErrors.push(err.message));
  page.on('console', (msg) => {
    if (msg.type() !== 'error') return;
    consoleErrors.push(msg.text());
  });
  await openApp(page);
  await waitForDashboard(page);
  await expect(page.getByText('Quick Actions', { exact: true })).toBeVisible();
  expect(pageErrors, `Page errors: ${pageErrors.join(' | ')}`).toHaveLength(0);
  expect(consoleErrors, `Console errors: ${consoleErrors.join(' | ')}`).toHaveLength(0);
});

test('landing renders and auth view is reachable', async ({ page }) => {
  await openApp(page);
  await waitForDashboard(page);
  // Open the profile route directly: Flutter's tab transition can leave
  // inactive branch semantics in place while the destination is mounting.
  await openApp(page, '/#/settings/profile');
  await expect(page.getByText('bob@example.com', { exact: true })).toBeVisible();
  await page.getByText('Log Out', { exact: true }).click();
  await expect(page.getByText('Inventory Login')).toBeVisible();
  // Flutter re-renders semantics nodes during animations, which detaches the
  // element mid-click; dispatch the click event directly instead.
  await page
    .getByRole('button', { name: 'Continue with Email' })
    .dispatchEvent('click');
  await expect(page.getByText('Welcome Back')).toBeVisible({ timeout: 15_000 });
});
