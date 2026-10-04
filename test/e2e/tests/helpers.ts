import { expect, type Page } from '@playwright/test';

export async function openApp(page: Page) {
  await page.goto('/');
  await expect(page.locator('flutter-view, flt-glass-pane').first()).toBeVisible({
    timeout: 30_000,
  });
  const enableA11y = page.getByRole('button', { name: 'Enable accessibility' });
  if (await enableA11y.count()) {
    await enableA11y.dispatchEvent('click');
  }
}

export async function expectAppAlive(page: Page) {
  await expect(page.locator('flutter-view, flt-glass-pane').first()).toBeVisible();
}
