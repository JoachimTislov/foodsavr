import { test, expect } from '@playwright/test';

test('landing view loads and stays alive', async ({ page }) => {
  await page.goto('/');
  await expect(page.locator('flutter-view, flt-glass-pane').first()).toBeVisible({
    timeout: 30_000,
  });
  await page.waitForTimeout(3_000);
  await expect(page.locator('flutter-view, flt-glass-pane').first()).toBeVisible();
});

test.fixme('no uncaught exceptions during initial navigation', async ({ page }) => {
  const pageErrors: string[] = [];
  page.on('pageerror', (err) => pageErrors.push(err.message));

  await page.goto('/');
  await expect(page.locator('flutter-view, flt-glass-pane').first()).toBeVisible({
    timeout: 30_000,
  });

  expect(pageErrors, `Page errors: ${pageErrors.join(' | ')}`).toHaveLength(0);
});
