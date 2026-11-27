import { test, expect, type Page } from '@playwright/test';
import { openApp, waitForDashboard } from './helpers';

// Development builds sign the test user in automatically, so reach the
// signed-out login screen by logging out.
async function openLogin(page: Page) {
  await openApp(page);
  await waitForDashboard(page);
  await page.getByRole('tab', { name: 'Settings' }).click();
  await page.getByText('bob@example.com').dispatchEvent('click');
  await page.getByText('Log Out', { exact: true }).click();
  // Flutter re-renders semantics nodes during animations, which detaches the
  // element mid-click; dispatch the click event directly instead.
  await page.getByRole('button', { name: 'Continue with Email' }).dispatchEvent('click');
  await expect(page.getByText('Welcome Back')).toBeVisible();
}

const guestButton = (page: Page) =>
  page.getByRole('button', { name: 'Continue as guest' });

test('login and signup show the LettMat brand and implicit agreement', async ({ page }) => {
  await openLogin(page);
  await expect(page.getByText('LettMat', { exact: true })).toBeVisible();
  await expect(page.getByText(/By signing in, you agree to our/)).toBeVisible();
  await expect(guestButton(page)).toBeVisible();
  // Inline text links have no link role, so match the rendered text.
  await page
    .locator('flt-semantics-host')
    .getByText('Privacy Policy', { exact: true })
    .dispatchEvent('click');
  const privacyDialog = page.getByRole('dialog');
  await expect(privacyDialog).toBeVisible();
  await expect(privacyDialog).toContainText('Privacy Notice');
  await privacyDialog
    .getByRole('button', { name: 'Close' })
    .first()
    .dispatchEvent('click');
  await expect(privacyDialog).toBeHidden();

  await page.getByRole('button', { name: 'Sign up' }).dispatchEvent('click');
  await expect(page.getByText(/By creating an account, you agree to our/)).toBeVisible();
  await expect(page.getByRole('checkbox')).toHaveCount(0);
  await expect(guestButton(page)).toHaveCount(0);
  await expect(page.getByText('Delete Account')).toHaveCount(0);
});

test('disabled guest sign-in is explained and leaves the form usable', async ({ page }) => {
  await openLogin(page);
  // What Firebase Auth returns when the anonymous provider is disabled.
  await page.route('**/accounts:signUp**', (route) =>
    route.fulfill({
      status: 400,
      contentType: 'application/json',
      headers: { 'access-control-allow-origin': '*' },
      body: JSON.stringify({ error: { code: 400, message: 'ADMIN_ONLY_OPERATION' } }),
    }),
  );

  await guestButton(page).dispatchEvent('click');

  // Scoped to the page: the live region also announces the message.
  await expect(
    page.locator('flt-semantics-host').getByText(/Guest access is not available here yet/),
  ).toBeVisible();
  await expect(guestButton(page)).toBeEnabled();
});

test('continue as guest on the login screen opens the dashboard', async ({ page }) => {
  await openLogin(page);

  await guestButton(page).dispatchEvent('click');

  await waitForDashboard(page);
});
