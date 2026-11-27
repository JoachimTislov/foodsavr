import { expect, test } from '@playwright/test';
import { openApp, waitForDashboard } from './helpers';

const REAL_CONTACT_EMAIL = 'dev.joachim.tislov@gmail.com';

test.describe('URL-backed legal and delete-account modals', () => {
  for (const route of [
    {
      path: '/#/legal/terms',
      canonical: '/legal/terms',
      title: 'Terms of Service',
      expectContactEmail: true,
    },
    {
      path: '/#/legal/privacy',
      canonical: '/legal/privacy',
      title: 'Privacy Notice',
      expectContactEmail: true,
    },
    {
      path: '/#/account/delete',
      canonical: '/account/delete',
      title: 'Delete Account',
      expectContactEmail: false,
    },
  ]) {
    test(`direct load to ${route.path} renders a small centered modal`, async ({
      page,
    }) => {
      const pageErrors: string[] = [];
      page.on('pageerror', (err) => pageErrors.push(err.message));

      await page.setViewportSize({ width: 1280, height: 800 });
      await openApp(page, route.path);

      await expect(page).toHaveURL(new RegExp(`${route.canonical}$`), {
        timeout: 30_000,
      });
      const dialog = page.getByRole('dialog');
      await expect(dialog).toBeVisible({ timeout: 30_000 });
      await expect(dialog.getByText(route.title).first()).toBeVisible();

      if (route.expectContactEmail) {
        await expect(dialog).toContainText(REAL_CONTACT_EMAIL);
        await expect(dialog).not.toContainText('placeholder.invalid');
        await expect(dialog).not.toContainText('todo@gmail.com');
      }

      const card = page.locator('[flt-semantics-identifier="url-modal-card"]');
      await expect(card).toBeVisible();
      const box = await card.boundingBox();
      expect(box, 'Modal card should have a bounding box').not.toBeNull();
      expect(
        box!.width,
        `Modal card width ${box!.width}px should remain compact on desktop`,
      ).toBeLessThanOrEqual(520);
      expect(box!.width).toBeGreaterThan(280);

      await dialog
        .getByRole('button', { name: 'Close' })
        .first()
        .dispatchEvent('click');
      await expect(dialog).toBeHidden({ timeout: 15_000 });
      expect(pageErrors, `Page errors: ${pageErrors.join(' | ')}`).toHaveLength(
        0,
      );
    });
  }

  for (const alias of [
    { input: '/#/terms', canonical: '/legal/terms', title: 'Terms of Service' },
    {
      input: '/#/privacy',
      canonical: '/legal/privacy',
      title: 'Privacy Notice',
    },
    {
      input: '/#/delete-account',
      canonical: '/account/delete',
      title: 'Delete Account',
    },
  ]) {
    test(`legacy hash URL ${alias.input} resolves to ${alias.canonical}`, async ({
      page,
    }) => {
      await page.setViewportSize({ width: 1280, height: 800 });
      await openApp(page, alias.input);

      await expect(page).toHaveURL(new RegExp(`${alias.canonical}$`), {
        timeout: 30_000,
      });
      const dialog = page.getByRole('dialog');
      await expect(dialog).toBeVisible({ timeout: 30_000 });
      await expect(dialog.getByText(alias.title).first()).toBeVisible();
    });
  }

  test('Settings opens legal and Delete Account routes as modals and closes back to Settings', async ({
    page,
  }) => {
    await page.setViewportSize({ width: 1280, height: 1200 });
    await openApp(page);
    await waitForDashboard(page);

    await page.getByRole('tab', { name: 'Settings' }).click();
    await expect(page.getByText('ACCOUNT', { exact: true })).toBeVisible({ timeout: 15_000 });
    await expect(page.getByText('ABOUT', { exact: true })).toBeVisible();

    await page.getByText('Terms of Service', { exact: true }).dispatchEvent('click');
    await expect(page).toHaveURL(/\/legal\/terms$/);
    const termsDialog = page.getByRole('dialog');
    await expect(termsDialog).toBeVisible();
    await expect(termsDialog).toContainText(REAL_CONTACT_EMAIL);

    // Switch to Privacy Notice from the modal footer.
    await termsDialog
      .getByRole('button', { name: 'Privacy Notice' })
      .dispatchEvent('click');
    await expect(page).toHaveURL(/\/legal\/privacy$/);
    await expect(page.getByRole('dialog')).toContainText(REAL_CONTACT_EMAIL);

    // Closing returns directly to Settings.
    await page
      .getByRole('dialog')
      .getByRole('button', { name: 'Close' })
      .first()
      .dispatchEvent('click');
    await expect(page).toHaveURL(/\/settings$/);
    await expect(page.getByRole('dialog')).toBeHidden();

    // Delete Account under Account section opens the Delete Account modal.
    await page.getByText('Delete Account').dispatchEvent('click');
    await expect(page).toHaveURL(/\/account\/delete$/);
    await expect(page.getByRole('dialog')).toBeVisible();
    await page
      .getByRole('dialog')
      .getByRole('button', { name: 'Close' })
      .first()
      .dispatchEvent('click');
    await expect(page).toHaveURL(/\/settings$/);

    // Runtime hashchange bridge resolves Facebook-style # URLs in place.
    await page.evaluate(() => {
      window.location.hash = '#/privacy';
    });
    await expect(page).toHaveURL(/\/legal\/privacy$/);
    await expect(page.getByRole('dialog')).toBeVisible();
  });
});
