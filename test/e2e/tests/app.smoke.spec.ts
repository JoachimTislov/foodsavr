import { test, expect } from '@playwright/test';
import { openApp } from './helpers';

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
    // App Check calls reCAPTCHA with the placeholder site key in CI, which
    // always returns 400. Those third-party resource failures are expected.
    const url = msg.location()?.url ?? '';
    if (url.includes('recaptcha')) return;
    consoleErrors.push(msg.text());
  });
  await page.goto('/');
  await expect(page.locator('flutter-view, flt-glass-pane').first()).toBeVisible({
    timeout: 30_000,
  });
  await page.waitForTimeout(3_000);
  expect(pageErrors, `Page errors: ${pageErrors.join(' | ')}`).toHaveLength(0);
  expect(consoleErrors, `Console errors: ${consoleErrors.join(' | ')}`).toHaveLength(0);
});

test('landing renders and auth view is reachable', async ({ page }) => {
  await openApp(page);
  await expect(page.getByText('Inventory Login')).toBeVisible({ timeout: 15_000 });
  await page.getByRole('button', { name: 'Continue with Email' }).click();
  await expect(page.getByText('Welcome Back')).toBeVisible({ timeout: 15_000 });
});
