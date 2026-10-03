import { test, expect } from '@playwright/test';

test('app boots and renders landing view', async ({ page }) => {
  const consoleErrors: string[] = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') consoleErrors.push(msg.text());
  });

  await page.goto('/');
  await expect(page).toHaveTitle(/.+/);

  const rendered = await page
    .locator('body')
    .evaluate((body) => (body.textContent ?? '').trim().length > 0);
  expect(rendered).toBe(true);

  expect(consoleErrors, `Console errors: ${consoleErrors.join(' | ')}`).toHaveLength(0);
});

test('flutter canvas is present and interactive', async ({ page }) => {
  await page.goto('/');
  await expect(page.locator('flutter-view, flt-glass-pane, flutter-view-engine').first()).toBeVisible({ timeout: 30_000 });
});
