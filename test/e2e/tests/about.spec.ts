import { expect, test } from '@playwright/test';

const VIEWPORTS = [
  { name: 'small-mobile', width: 320, height: 568 },
  { name: 'mobile', width: 375, height: 812 },
  { name: 'desktop', width: 1280, height: 800 },
];

for (const vp of VIEWPORTS) {
  test(`landing page renders cleanly without overflow at ${vp.name} (${vp.width}x${vp.height})`, async ({
    page,
  }) => {
    const pageErrors: string[] = [];
    const consoleErrors: string[] = [];
    const failedResponses: string[] = [];
    page.on('pageerror', (err) => pageErrors.push(err.message));
    page.on('console', (msg) => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });
    page.on('response', (res) => {
      if (res.status() >= 400) failedResponses.push(`${res.status()} ${res.url()}`);
    });

    await page.setViewportSize({ width: vp.width, height: vp.height });
    await page.goto('/about/');

    await expect(page.locator('h1')).toHaveCount(1);
    await expect(page.locator('h1')).toBeVisible();
    await expect(page.locator('flutter-view, flt-glass-pane')).toHaveCount(0);

    const hasOverflow = await page.evaluate(
      () => document.documentElement.scrollWidth > window.innerWidth,
    );
    expect(hasOverflow, `Horizontal overflow at ${vp.width}px`).toBe(false);

    expect(pageErrors, `Page errors: ${pageErrors.join(' | ')}`).toHaveLength(0);
    expect(consoleErrors, `Console errors: ${consoleErrors.join(' | ')}`).toHaveLength(0);
    expect(failedResponses, `HTTP errors: ${failedResponses.join(' | ')}`).toHaveLength(0);
  });
}

test('landing page exposes content, plans, legal links, and switches between en and nb', async ({
  page,
}) => {
  await page.setViewportSize({ width: 1280, height: 800 });
  await page.goto('/about/?lang=en');

  await expect(page.locator('html')).toHaveAttribute('lang', 'en');
  await expect(page.getByRole('link', { name: 'Open the app' }).first()).toHaveAttribute('href', '/');
  await expect(page.getByRole('link', { name: /View Privacy Notice/i })).toHaveAttribute('href', '/privacy');
  await expect(page.getByRole('link', { name: /View Terms of Service/i })).toHaveAttribute('href', '/terms');
  await expect(page.getByRole('link', { name: /Go to Delete Account/i })).toHaveAttribute('href', '/delete-account');
  await expect(page.locator('[data-contact-email]')).toHaveAttribute(
    'href',
    'mailto:dev.joachim.tislov@gmail.com',
  );

  await expect(page.getByText('Up to 3 inventories, 200 items per inventory')).toBeVisible();
  await expect(page.getByText('199 NOK')).toBeVisible();

  await page.getByRole('button', { name: 'Monthly' }).click();
  await expect(page.getByText('25 NOK')).toBeVisible();

  await page.getByRole('button', { name: 'NB' }).click();
  await expect(page.locator('html')).toHaveAttribute('lang', 'nb');
  await expect(page.getByRole('heading', { level: 1 })).toContainText(
    'Hold oversikt over kjøkkenet før maten går ut på dato.',
  );
  await expect(page.getByRole('link', { name: /Les personvernerklæring/i })).toBeVisible();
  await expect(page.getByRole('link', { name: /Gå til slett konto/i })).toBeVisible();
});

test('landing page respects ANDROID_APK_URL and production environment config', async ({
  page,
}) => {
  await page.goto('/about/?lang=en');
  await expect(page.locator('.android-cta').first()).toBeHidden();
  await expect(page.locator('.env-banner')).toBeVisible();

  await page.route('**/about/config.js', async (route) => {
    await route.fulfill({
      contentType: 'application/javascript',
      body: `
        window.__FOODSAVR_LANDING__ = {
          environment: 'production',
          androidUrl: '/android',
          contactEmail: 'privacy@foodsavr.example'
        };
        document.documentElement.dataset.env = 'production';
        document.documentElement.dataset.androidUrl = '/android';
      `,
    });
  });

  await page.goto('/about/?lang=en');
  await expect(page.locator('.env-banner')).toBeHidden();
  await expect(page.getByRole('link', { name: 'Download for Android' }).first()).toBeVisible();
  await expect(page.getByRole('link', { name: 'Download for Android' }).first()).toHaveAttribute('href', '/android');
  await expect(page.locator('[data-contact-email]')).toHaveAttribute('href', 'mailto:privacy@foodsavr.example');
});
