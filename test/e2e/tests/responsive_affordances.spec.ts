import { expect, test } from '@playwright/test';
import {
  deleteUserCollections,
  getDevUserUid,
  openApp,
  waitForDashboard,
} from './helpers';

test.describe('Responsive design system and platform affordances (#532)', () => {
  test('desktop renders clickable breadcrumbs for nested routes and navigates back', async ({
    page,
    isMobile,
  }) => {
    // Mobile browsers never get breadcrumbs, whatever the window width.
    test.skip(isMobile, 'desktop affordance');
    await page.setViewportSize({ width: 1280, height: 800 });
    await openApp(page);
    await waitForDashboard(page);

    await page.getByRole('tab', { name: 'Settings' }).click();
    await expect(page.getByRole('tab', { name: 'Settings' })).toHaveAttribute(
      'aria-selected',
      'true',
    );

    await page.getByText('bob@example.com').dispatchEvent('click');
    await expect(page.getByText('bob@example.com', { exact: true })).toBeVisible({
      timeout: 15_000,
    });

    const settingsCrumb = page.getByRole('button', { name: 'Settings', exact: true });
    await expect(settingsCrumb).toBeVisible();
    await settingsCrumb.click();

    await expect(page.getByText('ACCOUNT', { exact: true })).toBeVisible({
      timeout: 15_000,
    });
  });

  test('narrow windows rely on the page back button instead of breadcrumbs', async ({
    page,
  }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await openApp(page);
    await waitForDashboard(page);

    await page.getByRole('tab', { name: 'Settings' }).click();
    await page.getByText('bob@example.com').dispatchEvent('click');

    await expect(page.getByRole('button', { name: 'Back' })).toHaveCount(1);
    await expect(
      page.getByRole('button', { name: 'Settings', exact: true }),
    ).toHaveCount(0);
  });

  for (const width of [390, 1280]) {
    test(`empty-state actions stay centered under the text at ${width}px`, async ({
      page,
    }) => {
      await deleteUserCollections(await getDevUserUid());
      await page.setViewportSize({ width, height: 800 });
      await openApp(page);
      await waitForDashboard(page);

      await page.getByRole('tab', { name: 'My Inventory' }).click();
      const title = page.getByText("You don't have an inventory yet");
      await expect(title).toBeVisible({ timeout: 15_000 });

      const titleBox = (await title.boundingBox())!;
      const actionBox = (await page
        .getByRole('button', { name: 'Create Inventory' })
        .boundingBox())!;
      const offset =
        titleBox.x + titleBox.width / 2 - (actionBox.x + actionBox.width / 2);
      expect(Math.abs(offset)).toBeLessThan(2);
    });
  }

  test('desktop keyboard shortcuts Ctrl+=, Ctrl+-, and Ctrl+0 control app zoom', async ({
    page,
  }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await openApp(page);
    await waitForDashboard(page);

    await expect(page.getByRole('button', { name: '110%' })).toHaveCount(0);

    await page.keyboard.press('Control+Equal');
    await expect(page.getByRole('button', { name: '110%' })).toBeVisible({
      timeout: 10_000,
    });

    await page.keyboard.press('Control+Equal');
    await expect(page.getByRole('button', { name: '120%' })).toBeVisible();

    await page.keyboard.press('Control+Minus');
    await expect(page.getByRole('button', { name: '110%' })).toBeVisible();

    await page.keyboard.press('Control+Digit0');
    await expect(page.getByRole('button', { name: '110%' })).toHaveCount(0);
  });
});
