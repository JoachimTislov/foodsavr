import { expect, type Page } from '@playwright/test';

const FIRESTORE_HOST = process.env.FIRESTORE_EMULATOR_HOST ?? 'http://localhost:8080';
const AUTH_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST ?? 'http://localhost:9099';
const PROJECT_ID = process.env.FIREBASE_PROJECT_ID ?? 'demo-project';

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
}

export async function deleteSeededCollections(): Promise<void> {
  const res = await fetch(
    `${FIRESTORE_HOST}/v1/projects/${PROJECT_ID}/databases/(default)/documents/collections?pageSize=100`,
  );
  if (!res.ok) return;
  const body = (await res.json()) as { documents?: { name: string }[] };
  for (const doc of body.documents ?? []) {
    await fetch(`${FIRESTORE_HOST}/v1/${doc.name}`, { method: 'DELETE' });
  }
}

export async function createInventoryViaDialog(page: Page, name: string): Promise<void> {
  await page.getByRole('button', { name: 'Create Inventory' }).first().click();
  await page.getByRole('textbox', { name: 'Name' }).fill(name);
  await page.getByRole('button', { name: 'Create' }).click();
  await expect(page.getByText(name).first()).toBeVisible({ timeout: 15_000 });
}
