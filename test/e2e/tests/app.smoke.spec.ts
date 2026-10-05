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
  const login = page.getByText('Inventory Login');
  const dashboard = page.getByRole('tab', { name: 'Dashboard' });
  // Dev builds auto-login bob@example.com against the auth emulator, so the
  // login view may be replaced by the dashboard before we can interact.
  await Promise.race([
    login.waitFor({ timeout: 20_000 }),
    dashboard.waitFor({ timeout: 20_000 }),
  ]);
  if (await dashboard.count()) return;
  await expect(login).toBeVisible();
  // Flutter re-renders semantics nodes during animations, which detaches the
  // element mid-click; dispatch the click event directly instead.
  await page
    .getByRole('button', { name: 'Continue with Email' })
    .dispatchEvent('click');
  await expect(page.getByText('Welcome Back')).toBeVisible({ timeout: 15_000 });
});
