import { expect, type Page } from '@playwright/test';

const FIRESTORE_HOST = normalizeHost(
  process.env.FIRESTORE_EMULATOR_HOST,
  'http://localhost:8080',
);
const AUTH_HOST = normalizeHost(
  process.env.FIREBASE_AUTH_EMULATOR_HOST,
  'http://localhost:9099',
);
const PROJECT_ID = process.env.FIREBASE_PROJECT_ID ?? 'demo-project';

// Firebase emulator host variables use the `host:port` form without a scheme.
function normalizeHost(value: string | undefined, fallback: string): string {
  if (!value) return fallback;
  return value.startsWith('http://') || value.startsWith('https://')
    ? value
    : `http://${value}`;
}

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

export async function waitForDashboard(page: Page) {
  await expect(page.getByRole('tab', { name: 'Dashboard' })).toBeVisible({ timeout: 30_000 });
}

export async function getDevUserUid(): Promise<string> {
  const res = await fetch(
    `${AUTH_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'bob@example.com',
        password: 'password123',
        returnSecureToken: true,
      }),
    },
  );
  expect(res.ok, `auth emulator sign-in failed: ${res.status}`).toBeTruthy();
  const body = (await res.json()) as { localId: string };
  return body.localId;
}

export interface SeedCollection {
  id: string;
  name: string;
  userId: string;
  type: 'inventory' | 'shoppingList';
  description?: string;
  productIds?: string[];
}

const seededCollectionIds = new Set<string>();

export async function seedCollection(collection: SeedCollection): Promise<void> {
  const res = await fetch(
    `${FIRESTORE_HOST}/v1/projects/${PROJECT_ID}/databases/(default)/documents/collections?documentId=${collection.id}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        fields: {
          id: { stringValue: collection.id },
          name: { stringValue: collection.name },
          description: { stringValue: collection.description ?? '' },
          userId: { stringValue: collection.userId },
          type: { stringValue: collection.type },
          productIds: {
            arrayValue: {
              values: (collection.productIds ?? []).map((id) => ({ stringValue: id })),
            },
          },
        },
      }),
    },
  );
  expect(
    res.ok || res.status === 409,
    `seeding collection ${collection.id} failed: ${res.status}`,
  ).toBeTruthy();
  seededCollectionIds.add(collection.id);
}

// Deletes only collections this test suite created: explicitly seeded IDs
// plus any document whose name uses the suite's `E2E ` prefix (collections
// created through the UI dialog get random doc IDs). Unrelated emulator data
// from other tests survives cleanup.
export async function deleteSeededCollections(): Promise<void> {
  const listRes = await fetch(
    `${FIRESTORE_HOST}/v1/projects/${PROJECT_ID}/databases/(default)/documents/collections?pageSize=100`,
  );
  expect(
    listRes.ok,
    `listing collections for cleanup failed: ${listRes.status}`,
  ).toBeTruthy();
  const body = (await listRes.json()) as {
    documents?: { name: string; fields?: { name?: { stringValue?: string } } }[];
  };

  const ownedIds = new Set(seededCollectionIds);
  for (const doc of body.documents ?? []) {
    const id = doc.name.split('/').pop() as string;
    const name = doc.fields?.name?.stringValue ?? '';
    if (name.startsWith('E2E ')) ownedIds.add(id);
  }

  for (const id of ownedIds) {
    const res = await fetch(
      `${FIRESTORE_HOST}/v1/projects/${PROJECT_ID}/databases/(default)/documents/collections/${id}`,
      { method: 'DELETE' },
    );
    expect(
      res.ok || res.status === 404,
      `deleting seeded collection ${id} failed: ${res.status}`,
    ).toBeTruthy();
  }
  seededCollectionIds.clear();
}

export async function createInventoryViaDialog(page: Page, name: string): Promise<void> {
  await page.getByRole('button', { name: 'Create Inventory' }).first().click();
  await page.getByRole('textbox', { name: 'Name' }).fill(name);
  await page.getByRole('button', { name: 'Create' }).click();
  await expect(page.getByText(name).first()).toBeVisible({ timeout: 15_000 });
}
