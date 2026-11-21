import { expect } from '@playwright/test';
import { getDevUserUid } from './tests/helpers';

// Browser contexts are isolated; the shared Auth emulator is not. Provision
// before any page starts so development auto-login never probes a missing user.
export default async function globalSetup() {
  const host = process.env.FIREBASE_AUTH_EMULATOR_HOST ?? 'localhost:9099';
  const origin = /^https?:\/\//.test(host) ? host : `http://${host}`;
  const response = await fetch(
    `${origin}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo`,
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
  const body = await response.json() as { error?: { message?: string } };
  expect(response.ok || body.error?.message === 'EMAIL_EXISTS',
    `auth fixture creation failed: ${response.status} ${body.error?.message ?? ''}`,
  ).toBeTruthy();
  // An existing account is acceptable only if its credentials still work.
  await getDevUserUid();
}
