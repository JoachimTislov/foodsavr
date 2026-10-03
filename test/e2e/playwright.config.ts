import { defineConfig, devices } from '@playwright/test';

const BASE_URL = process.env.BASE_URL ?? 'http://localhost:8080';

export default defineConfig({
  testDir: './tests',
  timeout: 60_000,
  expect: { timeout: 15_000 },
  fullyParallel: false,
  workers: 1,
  retries: process.env.CI ? 1 : 0,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL: BASE_URL,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    { name: 'smoke', testMatch: /.*\.smoke\.spec\.ts/, use: { ...devices['Desktop Chrome'] } },
    { name: 'chromium', testMatch: /.*(?<!\.smoke)\.spec\.ts/, use: { ...devices['Desktop Chrome'] } },
  ],
});
