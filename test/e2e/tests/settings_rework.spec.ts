import { readFile } from 'node:fs/promises';
import { expect, test, type Download, type Page } from '@playwright/test';
import { openApp, waitForDashboard } from './helpers';

const CSV_HEADER =
  'section,collection_name,collection_type,product_name,category,barcode,' +
  'quantity,expiration_date,notes\r\n';

// Tall viewports keep every settings row on screen, so none is scrolled out of
// the semantics tree. The width decides the platform-adaptive layout.
async function openSettings(page: Page, width: number) {
  await page.setViewportSize({ width, height: 2600 });
  await openApp(page);
  await waitForDashboard(page);
  await page.getByRole('tab', { name: 'Settings' }).click();
  await expect(page.getByText('DATA EXPORT', { exact: true })).toBeVisible({
    timeout: 15_000,
  });
}

async function downloadBy(page: Page, buttonName: string): Promise<Download> {
  const button = page.getByRole('button', { name: buttonName, exact: true });
  // The button is disabled while an earlier export is still finishing.
  await expect(button).toBeEnabled();
  const download = page.waitForEvent('download');
  await button.dispatchEvent('click');
  return download;
}

async function contentOf(download: Download): Promise<string> {
  return readFile(await download.path(), 'utf8');
}

test.describe('Settings rework', () => {
  test('wide windows keep a centered column with account and connections', async ({
    page,
  }) => {
    await openSettings(page, 1280);

    for (const title of ['ACCOUNT', 'CONNECTIONS', 'PERMISSIONS', 'ABOUT']) {
      await expect(page.getByText(title, { exact: true })).toBeVisible();
    }
    const header = await page.getByText('ACCOUNT', { exact: true }).boundingBox();
    expect(header, 'section header should have a bounding box').not.toBeNull();
    // A 680px column centered in a wide window starts far from the left edge.
    expect(header!.x).toBeGreaterThan(250);

    // The seeded account signs in with a password only.
    await expect(
      page.getByRole('button', { name: 'Forgot Password' }),
    ).toBeVisible();
    await expect(page.getByText('Add password')).toHaveCount(0);
    for (const provider of ['Google', 'Facebook']) {
      await expect(
        page.getByRole('button', { name: `Connect ${provider}` }),
      ).toBeVisible();
    }
    await expect(
      page.getByRole('switch', { name: /Camera access/ }),
    ).toBeChecked();
  });

  test('the language pill switches the language in place', async ({ page }) => {
    await openSettings(page, 1280);

    await page
      .getByRole('button', { name: 'Norwegian', exact: true })
      .dispatchEvent('click');
    await expect(page.getByText('TILKOBLINGER', { exact: true })).toBeVisible();
    await expect(page.getByRole('dialog')).toHaveCount(0);

    await page
      .getByRole('button', { name: 'Engelsk', exact: true })
      .dispatchEvent('click');
    await expect(page.getByText('CONNECTIONS', { exact: true })).toBeVisible();
  });

  test('wide export downloads CSV by default and JSON on request', async ({
    page,
  }) => {
    await openSettings(page, 1280);
    await expect(page.getByText(/(\d+) of \1 selected/)).toBeVisible();

    const csv = await downloadBy(page, 'Download');
    expect(csv.suggestedFilename()).toMatch(
      /^foodsavr-export-\d{4}-\d{2}-\d{2}\.csv$/,
    );
    const text = await contentOf(csv);
    expect(text.startsWith(`\uFEFF${CSV_HEADER}`)).toBeTruthy();

    // The confirmation appears once the export has finished.
    await expect(
      page.getByText(`Downloaded ${csv.suggestedFilename()}`).first(),
    ).toBeVisible();

    await page
      .getByRole('button', { name: 'JSON', exact: true })
      .dispatchEvent('click');
    const json = await downloadBy(page, 'Download');
    expect(json.suggestedFilename()).toMatch(/\.json$/);
    const data = JSON.parse(await contentOf(json));
    expect(data.application).toBe('foodsavr');
    expect(Array.isArray(data.collections)).toBeTruthy();
    expect(Array.isArray(data.products)).toBeTruthy();
  });

  test('narrow export downloads everything in one tap', async ({ page }) => {
    await openSettings(page, 390);
    await expect(page.getByRole('checkbox')).toHaveCount(0);

    const csv = await downloadBy(page, 'Export all (CSV)');
    expect(csv.suggestedFilename()).toMatch(/\.csv$/);
    const text = await contentOf(csv);
    expect(text.startsWith(`\uFEFF${CSV_HEADER}`)).toBeTruthy();
  });
});
