import { test, expect } from '@playwright/test';

test('landing view shows authentication entry point', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveTitle(/.+/);
  const body = (await page.locator('body').textContent()) ?? '';
  const hasAuthEntry = /sign|log|auth/i.test(body);
  expect(hasAuthEntry, 'Expected a sign-in/auth entry point on the landing view').toBe(true);
});

test('navigation does not produce console errors', async ({ page }) => {
  const consoleErrors: string[] = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') consoleErrors.push(msg.text());
  });

  await page.goto('/');
  await page.waitForTimeout(3_000);

  expect(consoleErrors, `Console errors: ${consoleErrors.join(' | ')}`).toHaveLength(0);
});
