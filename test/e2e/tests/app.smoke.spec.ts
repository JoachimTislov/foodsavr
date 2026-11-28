import { test, expect } from '@playwright/test';
import { openApp, waitForDashboard } from './helpers';

test('app boots and renders the Flutter view', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveTitle(/.+/);
  await expect(page.locator('flutter-view, flt-glass-pane').first()).toBeVisible({
    timeout: 30_000,
  });
});

test('app boots with persisted V3 App Check settings', async ({ page }) => {
  const keys = [
    'FlutterFire-[DEFAULT]-recaptchaType',
    'FlutterFire-[DEFAULT]-recaptchaSiteKey',
  ];
  await page.addInitScript(([typeKey, siteKey]) => {
    for (const storage of [localStorage, sessionStorage]) {
      storage.setItem(typeKey, 'recaptcha-v3');
      storage.setItem(siteKey, 'old-v3-site-key');
    }
  }, keys);
  const errors: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));

  await page.goto('/');
  await expect(page.locator('flutter-view, flt-glass-pane').first()).toBeVisible({
    timeout: 30_000,
  });
  const persisted = await page.evaluate(
    (keys) => [localStorage, sessionStorage].flatMap(
      (storage) => keys.map((key) => storage.getItem(key)),
    ),
    keys,
  );
  expect(persisted).toEqual([null, null, null, null]);
  expect(errors).toEqual([]);
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
  const settings = page.getByRole('tab', { name: 'Settings' });
  await settings.click();
  await expect(settings).toHaveAttribute('aria-selected', 'true');
  // The settings tile groups the account name and email in one semantics node.
  await page.getByText('bob@example.com').dispatchEvent('click');
  await expect(page.getByText('bob@example.com', { exact: true })).toBeVisible();
  await page.getByText('Log Out', { exact: true }).click();
  await expect(page.getByText('Less waste, easier meals.')).toBeVisible();
  // Flutter re-renders semantics nodes during animations, which detaches the
  // element mid-click; dispatch the click event directly instead.
  await page
    .getByRole('button', { name: 'I already have an account' })
    .dispatchEvent('click');
  await expect(page.getByText('Welcome Back')).toBeVisible({ timeout: 15_000 });
});

test('PWA manifest, service worker, and install bridge are configured', async ({
  page,
  request,
}) => {
  await page.goto('/');
  await expect(page.locator('link[rel="manifest"]')).toHaveAttribute(
    'href',
    'manifest.json',
  );

  const manifestRes = await request.get('/manifest.json');
  expect(manifestRes.ok()).toBeTruthy();
  const manifest = (await manifestRes.json()) as {
    name?: string;
    short_name?: string;
    display?: string;
    icons?: { src?: string }[];
  };
  expect(manifest.name).toBe('LettMat');
  expect(manifest.short_name).toBe('LettMat');
  expect(manifest.display).toBe('standalone');
  expect(manifest.icons?.length ?? 0).toBeGreaterThanOrEqual(4);

  const swRes = await request.get('/sw.js');
  expect(swRes.ok()).toBeTruthy();

  const hasBridge = await page.evaluate(() => {
    const pwa = (window as unknown as { foodsavrPwa?: Record<string, unknown> })
      .foodsavrPwa;
    return (
      typeof pwa === 'object' &&
      pwa !== null &&
      typeof pwa.canPrompt === 'function' &&
      typeof pwa.isInstalled === 'function' &&
      typeof pwa.promptInstall === 'function'
    );
  });
  expect(hasBridge).toBe(true);
});
