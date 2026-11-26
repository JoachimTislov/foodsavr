#!/usr/bin/env node
/**
 * Lightweight synthetic web probe using Playwright (reusing test/e2e's dependency).
 *
 * Captures uncaught pageerror, console.error, HTTP >= 500 responses, and verifies
 * that Flutter mounts (flutter-view / flt-glass-pane) within the timeout.
 * Outputs structured JSON suitable for fault_intake.py and verify_and_close.py.
 */

import { createHash } from 'node:crypto';
import fs from 'node:fs';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, '../..');
const RECAPTCHA_STORAGE_ACCESS_ERROR = 'requestStorageAccess: Permission denied.';

function isRecaptchaStorageAccessNoise(message, sourceUrl) {
  if (message !== RECAPTCHA_STORAGE_ACCESS_ERROR && message?.trim() !== RECAPTCHA_STORAGE_ACCESS_ERROR) {
    return false;
  }
  try {
    const source = new URL(sourceUrl);
    if (source.protocol !== 'https:' && source.protocol !== 'http:') return false;
    const isGoogleDomain = ['google.com', 'gstatic.com'].some(
      (domain) => source.hostname === domain || source.hostname.endsWith(`.${domain}`)
    );
    if (!isGoogleDomain) return false;
    // Path prefix only: a query such as ?continue=/recaptcha/... must not match.
    return source.pathname.toLowerCase().startsWith('/recaptcha/');
  } catch (_) {
    return false;
  }
}

function loadPlaywright() {
  const candidates = [
    path.join(repoRoot, 'test/e2e/package.json'),
    path.join(process.cwd(), 'package.json'),
  ];
  for (const pkgPath of candidates) {
    if (fs.existsSync(pkgPath)) {
      try {
        const req = createRequire(pkgPath);
        return req('@playwright/test');
      } catch (_) {}
      try {
        const req = createRequire(pkgPath);
        return req('playwright');
      } catch (_) {}
    }
  }
  throw new Error(
    'Playwright not found. Install dependencies in test/e2e (`npm --prefix test/e2e ci`).',
  );
}

function parseArgs(argv) {
  const opts = {
    url: process.env.TARGET_URL || 'https://foodsavr-test.web.app',
    output: '',
    timeoutMs: Number(process.env.PROBE_TIMEOUT_MS || 25000),
    settleMs: Number(process.env.PROBE_SETTLE_MS || 2000),
    noFail: false,
    releaseSha: process.env.RELEASE_SHA || '',
    environment: process.env.ENVIRONMENT || 'production',
    deploymentLevel: process.env.DEPLOYMENT_LEVEL || 'firebase-spark',
  };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--url' && argv[i + 1]) opts.url = argv[++i];
    else if (arg === '--output' && argv[i + 1]) opts.output = argv[++i];
    else if (arg === '--timeout-ms' && argv[i + 1]) opts.timeoutMs = Number(argv[++i]);
    else if (arg === '--settle-ms' && argv[i + 1]) opts.settleMs = Number(argv[++i]);
    else if (arg === '--release-sha' && argv[i + 1]) opts.releaseSha = argv[++i];
    else if (arg === '--environment' && argv[i + 1]) opts.environment = argv[++i];
    else if (arg === '--deployment-level' && argv[i + 1]) opts.deploymentLevel = argv[++i];
    else if (arg === '--no-fail') opts.noFail = true;
  }
  return opts;
}

async function servedRevision(context, target, bundleDigest) {
  if (!bundleDigest) return null;
  try {
    const response = await context.request.get(new URL('/release.json', target).href, {
      headers: { 'Cache-Control': 'no-cache' },
      maxRedirects: 0,
      timeout: 5000,
    });
    if (!response.ok()) return null;
    const metadata = await response.json();
    if (typeof metadata?.revision === 'string' && /^[a-f0-9]{40}$/.test(metadata.revision) &&
        metadata.main_bundle_sha256 === bundleDigest) {
      return metadata.revision;
    }
  } catch (_) {}
  return null;
}

async function runProbe(opts) {
  const { chromium } = loadPlaywright();
  const browser = await chromium.launch({ headless: true });
  const pageErrors = [];
  const consoleErrors = [];
  const http5xx = [];
  const requestFailures = [];
  let rootMounted = false;
  let title = '';
  let earlyErrors = [];
  let phase = 'navigation';
  let firstPageErrorPhase = null;
  let mainBundleResponse;
  const target = new URL(opts.url);

  let mainBundleSha256 = null;
  let revision = null;
  try {
    const context = await browser.newContext();
    const page = await context.newPage();

    page.on('pageerror', (err) => {
      firstPageErrorPhase ??= phase;
      pageErrors.push({
        name: err?.name || 'PageError',
        message: err?.message || String(err),
        stack: err?.stack ? String(err.stack).split('\n').slice(0, 12) : [],
      });
    });

    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        const loc = msg.location();
        if (isRecaptchaStorageAccessNoise(msg.text(), loc?.url || '')) return;
        consoleErrors.push({
          text: msg.text(),
          location: loc?.url ? `${loc.url}:${loc.lineNumber ?? 0}:${loc.columnNumber ?? 0}` : '',
        });
      }
    });

    page.on('response', (res) => {
      if (res.status() >= 500) {
        http5xx.push({
          url: res.url(),
          status: res.status(),
        });
      }
    });

    page.on('requestfinished', (req) => {
      const url = new URL(req.url());
      if (req.resourceType() === 'script' &&
          url.origin === target.origin && url.pathname === '/main.dart.js') {
        mainBundleResponse = req.response().catch(() => null);
      }
    });

    page.on('requestfailed', (req) => {
      if (req.isNavigationRequest()) {
        requestFailures.push({
          url: req.url(),
          method: req.method(),
          failure: req.failure()?.errorText || 'failed',
        });
      }
    });

    await page.goto(opts.url, { waitUntil: 'domcontentloaded', timeout: opts.timeoutMs });
    phase = 'mount';
    title = await page.title().catch(() => '');

    try {
      await page
        .locator('flutter-view, flt-glass-pane')
        .first()
        .waitFor({ state: 'visible', timeout: opts.timeoutMs });
      rootMounted = true;
    } catch (_) {
      rootMounted = false;
    }

    phase = rootMounted ? 'after_mount' : 'after_mount_timeout';
    if (opts.settleMs > 0) {
      await page.waitForTimeout(opts.settleMs);
    }

    earlyErrors = await page
      .evaluate(() => {
        const list = window.__foodsavrEarlyErrors;
        return Array.isArray(list) ? list.slice(0, 20) : [];
      })
      .catch(() => []);
    page.removeAllListeners('pageerror');
    page.removeAllListeners('console');
    page.removeAllListeners('response');
    page.removeAllListeners('requestfailed');
    page.removeAllListeners('requestfinished');
    const bundle = await mainBundleResponse;
    if (bundle?.ok()) {
      const body = await bundle.body().catch(() => null);
      if (body) {
        mainBundleSha256 = createHash('sha256').update(body).digest('hex');
      }
    }
    revision = await servedRevision(context, target, mainBundleSha256);
  } finally {
    await browser.close();
  }

  const ok =
    rootMounted &&
    pageErrors.length === 0 &&
    consoleErrors.length === 0 &&
    http5xx.length === 0;

  return {
    source: 'github/playwright-probe',
    target_url: opts.url,
    checked_at: new Date().toISOString(),
    release_sha: opts.releaseSha,
    served_revision: revision,
    environment: opts.environment,
    deployment_level: opts.deploymentLevel,
    ok,
    root_mounted: rootMounted,
    title,
    diagnostics: {
      main_bundle_sha256: mainBundleSha256,
      first_page_error_phase: firstPageErrorPhase,
    },
    raw_findings: {
      page_errors: pageErrors,
      console_errors: consoleErrors,
      http_5xx: http5xx,
      request_failures: requestFailures,
      early_errors: earlyErrors,
    },
  };
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  const report = await runProbe(opts);
  const json = JSON.stringify(report, null, 2);
  if (opts.output) {
    fs.writeFileSync(opts.output, json + '\n', 'utf8');
  } else {
    process.stdout.write(json + '\n');
  }
  if (!report.ok && !opts.noFail) {
    process.exitCode = 1;
  }
}

main().catch((err) => {
  process.stderr.write(`probe_web failed: ${err?.stack || err}\n`);
  process.exit(2);
});
