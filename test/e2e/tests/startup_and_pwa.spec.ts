import { test, expect } from '@playwright/test';

test.describe('LettMat branding, themed first-paint loader, and Firefox PWA', () => {
  test('serves LettMat branding metadata, manifest, and icon assets', async ({
    page,
    request,
  }) => {
    await page.goto('/');
    await expect(page).toHaveTitle('LettMat');
    await expect(page.locator('meta[name="application-name"]')).toHaveAttribute(
      'content',
      'LettMat',
    );
    await expect(
      page.locator('meta[name="apple-mobile-web-app-title"]'),
    ).toHaveAttribute('content', 'LettMat');

    const manifestRes = await request.get('/manifest.json');
    expect(manifestRes.ok()).toBeTruthy();
    const manifest = (await manifestRes.json()) as {
      name?: string;
      short_name?: string;
      theme_color?: string;
      background_color?: string;
      icons?: { src?: string }[];
    };
    expect(manifest.name).toBe('LettMat');
    expect(manifest.short_name).toBe('LettMat');
    expect(manifest.theme_color).toBe('#13c8ec');
    expect(manifest.background_color).toBe('#f6f8f8');

    for (const asset of [
      '/favicon.png',
      '/icons/Icon-192.png',
      '/icons/Icon-512.png',
      '/icons/Icon-maskable-192.png',
      '/icons/Icon-maskable-512.png',
    ]) {
      const res = await request.get(asset);
      expect(res.ok(), `Expected ${asset} to return 200`).toBeTruthy();
      expect(res.headers()['content-type']).toContain('image/png');
    }
  });

  test('paints dark first-paint loader from persisted app_theme_mode and removes it after Flutter boots', async ({
    page,
  }) => {
    await page.addInitScript(() => {
      window.localStorage.setItem('app_theme_mode', JSON.stringify('dark'));
    });

    // Hold flutter_bootstrap.js so we can assert the exact pre-boot first paint.
    let releaseBootstrap!: () => void;
    const bootstrapHeld = new Promise<void>((resolve) => {
      releaseBootstrap = resolve;
    });
    await page.route('**/flutter_bootstrap.js', async (route) => {
      await bootstrapHeld;
      await route.continue();
    });

    await page.goto('/', { waitUntil: 'domcontentloaded' });

    const preBoot = await page.evaluate(() => {
      const root = document.documentElement;
      const loader = document.getElementById('lettmat-startup-loader');
      return {
        hasDarkClass: root.classList.contains('dark'),
        dataTheme: root.dataset.theme,
        rootBg: getComputedStyle(root).backgroundColor,
        loaderVisible: loader !== null,
        loaderBg: loader ? getComputedStyle(loader).backgroundColor : null,
        loaderText: loader ? loader.textContent?.trim() : null,
      };
    });

    expect(preBoot.hasDarkClass).toBe(true);
    expect(preBoot.dataTheme).toBe('dark');
    expect(preBoot.rootBg).toBe('rgb(16, 31, 34)');
    expect(preBoot.loaderVisible).toBe(true);
    expect(preBoot.loaderBg).toBe('rgb(16, 31, 34)');
    expect(preBoot.loaderText).toContain('LettMat');

    // Release Flutter bootstrap and confirm the pre-boot overlay hands off cleanly.
    releaseBootstrap();
    await expect(page.locator('flutter-view, flt-glass-pane').first()).toBeVisible({
      timeout: 30_000,
    });
    await expect(page.locator('#lettmat-startup-loader')).toHaveCount(0, {
      timeout: 5_000,
    });
  });

  test('paints light first-paint loader when persisted app_theme_mode is light even if OS prefers dark', async ({
    page,
  }) => {
    await page.emulateMedia({ colorScheme: 'dark' });
    await page.addInitScript(() => {
      window.localStorage.setItem('app_theme_mode', JSON.stringify('light'));
    });
    await page.route('**/flutter_bootstrap.js', (route) => route.abort());

    await page.goto('/', { waitUntil: 'domcontentloaded' });

    const state = await page.evaluate(() => ({
      hasDarkClass: document.documentElement.classList.contains('dark'),
      dataTheme: document.documentElement.dataset.theme,
      rootBg: getComputedStyle(document.documentElement).backgroundColor,
    }));

    expect(state.hasDarkClass).toBe(false);
    expect(state.dataTheme).toBe('light');
    expect(state.rootBg).toBe('rgb(246, 248, 248)');
  });

  test('falls back to prefers-color-scheme when no persisted theme exists', async ({
    page,
  }) => {
    await page.emulateMedia({ colorScheme: 'dark' });
    await page.route('**/flutter_bootstrap.js', (route) => route.abort());

    await page.goto('/', { waitUntil: 'domcontentloaded' });

    const state = await page.evaluate(() => ({
      hasDarkClass: document.documentElement.classList.contains('dark'),
      dataTheme: document.documentElement.dataset.theme,
      rootBg: getComputedStyle(document.documentElement).backgroundColor,
    }));

    expect(state.hasDarkClass).toBe(true);
    expect(state.dataTheme).toBe('dark');
    expect(state.rootBg).toBe('rgb(16, 31, 34)');
  });

  test('detects Firefox Android, Firefox Desktop, iOS, Safari, and standard browsers in foodsavrPwa', async ({
    page,
  }) => {
    await page.route('**/flutter_bootstrap.js', (route) => route.abort());
    await page.goto('/', { waitUntil: 'domcontentloaded' });

    const results = await page.evaluate(() => {
      const pwa = (
        window as unknown as {
          foodsavrPwa: {
            detectPlatformHint: (
              ua: string,
              platform?: string,
              touchPoints?: number,
            ) => string;
          };
        }
      ).foodsavrPwa;

      return {
        firefoxAndroid: pwa.detectPlatformHint(
          'Mozilla/5.0 (Android 14; Mobile; rv:132.0) Gecko/132.0 Firefox/132.0',
          'Linux armv8l',
          5,
        ),
        firefoxDesktop: pwa.detectPlatformHint(
          'Mozilla/5.0 (X11; Linux x86_64; rv:132.0) Gecko/20100101 Firefox/132.0',
          'Linux x86_64',
          0,
        ),
        iosSafari: pwa.detectPlatformHint(
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
          'iPhone',
          5,
        ),
        macosSafari: pwa.detectPlatformHint(
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15',
          'MacIntel',
          0,
        ),
        chromeDesktop: pwa.detectPlatformHint(
          'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
          'Linux x86_64',
          0,
        ),
      };
    });

    expect(results).toEqual({
      firefoxAndroid: 'firefox-android',
      firefoxDesktop: 'firefox-desktop',
      iosSafari: 'ios',
      macosSafari: 'macos-safari',
      chromeDesktop: 'standard',
    });
  });
});
