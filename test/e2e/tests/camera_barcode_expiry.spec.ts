import { expect, test, type Page } from '@playwright/test';
import { getDevUserUid, openApp, waitForDashboard } from './helpers';

const FIRESTORE_HOST = (() => {
  const value = process.env.FIRESTORE_EMULATOR_HOST;
  if (!value) return 'http://localhost:8080';
  return value.startsWith('http') ? value : `http://${value}`;
})();
const PROJECT_ID = process.env.FIREBASE_PROJECT_ID ?? 'demo-project';
const EMULATOR_ADMIN = { Authorization: 'Bearer owner' };
const BARCODE = '7038010009457';

interface ProductDocument {
  name: string;
  fields?: {
    name?: { stringValue?: string };
    barcode?: { stringValue?: string };
    expiries?: { arrayValue?: { values?: unknown[] } };
  };
}

async function listProducts(): Promise<ProductDocument[]> {
  const res = await fetch(
    `${FIRESTORE_HOST}/v1/projects/${PROJECT_ID}/databases/(default)/documents/products?pageSize=300`,
    { headers: EMULATOR_ADMIN },
  );
  expect(res.ok, `listing products failed: ${res.status}`).toBeTruthy();
  return ((await res.json()) as { documents?: ProductDocument[] }).documents ?? [];
}

const testProducts = async () =>
  (await listProducts()).filter((doc) =>
    doc.fields?.name?.stringValue?.startsWith('E2E '),
  );

async function deleteTestProducts(): Promise<void> {
  for (const doc of await testProducts()) {
    const id = doc.name.split('/').pop() as string;
    await fetch(
      `${FIRESTORE_HOST}/v1/projects/${PROJECT_ID}/databases/(default)/documents/products/${id}`,
      { method: 'DELETE', headers: EMULATOR_ADMIN },
    );
  }
}

// Open Food Facts is never reached: no barcode is known, and every search
// returns one candidate.
async function stubOpenFoodFacts(page: Page) {
  await page.route(/openfoodfacts\.org/, (route) => {
    const body = route.request().url().includes('/cgi/search.pl')
      ? {
          count: 1,
          page: 1,
          page_size: 8,
          products: [
            {
              code: BARCODE,
              product_name: 'E2E Lettmelk',
              brands: 'E2E Dairy',
              categories_tags: ['en:dairies', 'en:milks'],
            },
          ],
        }
      : { status: 'failure', result: { id: 'product_not_found' } };
    return route.fulfill({
      status: 200,
      contentType: 'application/json',
      headers: { 'access-control-allow-origin': '*' },
      body: JSON.stringify(body),
    });
  });
}

type CameraStub = { error: string | null; requests: number; stopped: number };

// A browser with one camera whose permission the test decides.
async function stubBrowserCamera(page: Page) {
  await page.addInitScript(() => {
    const camera: CameraStub = {
      error: 'NotAllowedError',
      requests: 0,
      stopped: 0,
    };
    (window as unknown as { cameraStub: CameraStub }).cameraStub = camera;
    const devices = navigator.mediaDevices;
    devices.enumerateDevices = async () => [
      { kind: 'videoinput', deviceId: '', groupId: '', label: '' } as MediaDeviceInfo,
    ];
    devices.getUserMedia = async () => {
      camera.requests += 1;
      if (camera.error) throw new DOMException('stubbed', camera.error);
      return {
        getTracks: () => [{ stop: () => (camera.stopped += 1) }],
      } as unknown as MediaStream;
    };
  });
}

const cameraStub = (page: Page) =>
  page.evaluate(
    () => (window as unknown as { cameraStub: CameraStub }).cameraStub,
  );

// Flutter exposes the card's title and explanation as one group label.
const cameraCard = (page: Page, title: string) =>
  page.getByRole('group', { name: new RegExp(`^${title}`) });

const lookupField = (page: Page) =>
  page.getByRole('textbox', { name: 'Barcode or product name' });

// Flutter replaces the input element when focus moves, so type like a user.
// Erasing key by key works on touch devices, where typing over a selection
// does not.
async function typeInto(page: Page, name: string, text: string) {
  const field = page.getByRole('textbox', { name, exact: true });
  await field.click();
  await expect(field).toBeFocused();
  const current = await field.inputValue();
  await page.keyboard.press('End');
  for (let i = 0; i < current.length; i++) {
    await page.keyboard.press('Backspace');
  }
  await expect(field).toHaveValue('');
  await page.keyboard.type(text, { delay: 30 });
  await expect(field).toHaveValue(text);
}

// Browsers have no live scanning, so no button leads to the scanner route; a
// reload would pass the sign-in splash and lose the path. Navigate in the app.
async function openScanner(page: Page) {
  await openApp(page);
  await waitForDashboard(page);
  await page.evaluate(() => {
    history.pushState(null, '', '/barcode-scan');
    dispatchEvent(new PopStateEvent('popstate'));
  });
}

test.beforeEach(async ({ page }) => {
  await getDevUserUid();
  await deleteTestProducts();
  await stubOpenFoodFacts(page);
});

test.afterEach(deleteTestProducts);

test('without live scanning, Add Product opens a modal with barcode and name lookup', async ({
  page,
}) => {
  await openApp(page);
  await waitForDashboard(page);

  await page.getByText('Add Product').first().click();
  await expect(lookupField(page)).toBeVisible({ timeout: 15_000 });
  await expect(page).toHaveURL(/\/dashboard/);

  // A wrong check digit is flagged, and unknown barcodes can be tried again.
  await typeInto(page, 'Barcode or product name', '7038010009458');
  await expect(page.getByText(/check digit does not match/).first()).toBeVisible();
  await page.keyboard.press('Enter');
  await expect(
    page.getByText(/No product found for 7038010009458/).first(),
  ).toBeVisible({ timeout: 15_000 });

  await typeInto(page, 'Barcode or product name', 'melk');
  await page.keyboard.press('Enter');
  await page.getByRole('button', { name: /E2E Lettmelk/ }).click();
  await expect(
    page.getByRole('group', { name: `Barcode: ${BARCODE}` }),
  ).toBeVisible();
  await expect(
    page.getByRole('button', { name: 'Remove barcode' }),
  ).toBeEnabled();

  await page.getByRole('button', { name: 'Add Product', exact: true }).last().click();

  await expect
    .poll(async () =>
      (await testProducts()).map((doc) => doc.fields?.barcode?.stringValue),
    )
    .toContain(BARCODE);
});

test('the scanner route explains the camera, retries, and falls back', async ({
  page,
}) => {
  await stubBrowserCamera(page);
  await openScanner(page);

  await expect(cameraCard(page, 'Camera scanning is not available')).toBeVisible({
    timeout: 30_000,
  });
  // Nothing asks for the camera before the user does.
  expect((await cameraStub(page)).requests).toBe(0);

  await page.getByRole('button', { name: 'Try Again' }).click();
  await expect(cameraCard(page, 'Camera permission denied')).toBeVisible();

  await page.evaluate(() => {
    (window as unknown as { cameraStub: CameraStub }).cameraStub.error = null;
  });
  await page.getByRole('button', { name: 'Try Again' }).click();
  await expect(
    cameraCard(page, 'Camera scanning is not available'),
  ).toBeVisible();
  // The permission probe releases the camera at once.
  expect(await cameraStub(page)).toMatchObject({ requests: 2, stopped: 1 });

  await expect(lookupField(page)).toBeVisible();
});

test('starts with the expiry date and asks for the details afterwards', async ({
  page,
}) => {
  await openScanner(page);
  await page
    .getByRole('button', { name: 'Start with the expiry date' })
    .click({ timeout: 30_000 });

  await page.getByRole('button', { name: 'OK' }).click();
  await expect(lookupField(page)).toBeVisible({ timeout: 15_000 });
  await typeInto(page, 'Product Name', 'E2E Yoghurt');
  await page.getByRole('button', { name: 'Add Product', exact: true }).last().click();

  await expect
    .poll(async () =>
      (await testProducts()).map(
        (doc) => doc.fields?.expiries?.arrayValue?.values?.length ?? 0,
      ),
    )
    .toEqual([1]);
});
