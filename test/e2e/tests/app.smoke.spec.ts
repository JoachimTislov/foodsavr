import { test, expect } from '@playwright/test';

test('app boots and renders the Flutter view', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveTitle(/.+/);
  await expect(page.locator('flutter-view, flt-glass-pane').first()).toBeVisible({
    timeout: 30_000,
  });
});

test('app does not hit uncaught page errors', async ({ page }) => {
  const pageErrors: string[] = [];
  page.on('pageerror', (err) => pageErrors.push(err.message));

  await page.goto('/');
  await expect(page.locator('flutter-view, flt-glass-pane').first()).toBeVisible({
    timeout: 30_000,
  });
  await page.waitForTimeout(3_000);

  expect(pageErrors, `Page errors: ${pageErrors.join(' | ')}`).toHaveLength(0);
});
