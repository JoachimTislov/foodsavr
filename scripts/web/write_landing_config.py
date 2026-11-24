#!/usr/bin/env python3
"""Write runtime config.js for the static landing page under build/web/about/.

Usage: write_landing_config.py [OUTPUT_PATH]
env:
  LEGAL_ENVIRONMENT (or FLAVOR; defaults to "development")
  ANDROID_APK_URL   (optional https:// URL; exposes /android CTA when set)
  CONTACT_EMAIL     (optional; defaults to "legal-contact@placeholder.invalid")
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

DEFAULT_CONTACT_EMAIL = "legal-contact@placeholder.invalid"


def render_config_js(
    environment: str,
    android_url: str,
    contact_email: str,
) -> str:
    cfg = {
        "environment": environment,
        "androidUrl": android_url,
        "contactEmail": contact_email,
    }
    payload = json.dumps(cfg, indent=2)
    return f"""(function () {{
  var cfg = {payload};
  window.__FOODSAVR_LANDING__ = cfg;

  var root = document.documentElement;
  root.dataset.env = cfg.environment || 'production';
  if (cfg.androidUrl) {{
    root.dataset.androidUrl = cfg.androidUrl;
  }} else {{
    delete root.dataset.androidUrl;
  }}

  try {{
    var params = new URLSearchParams(window.location.search);
    var queryLang = params.get('lang');
    var storedLang = window.localStorage.getItem('foodsavr_landing_lang');
    var navLang = (navigator.language || '').toLowerCase();
    var lang =
      queryLang === 'nb' || queryLang === 'en'
        ? queryLang
        : storedLang === 'nb' || storedLang === 'en'
          ? storedLang
          : navLang.startsWith('nb') || navLang.startsWith('nn') || navLang.startsWith('no')
            ? 'nb'
            : 'en';
    root.lang = lang;
    root.dataset.lang = lang;
  }} catch (_) {{
    root.lang = 'en';
    root.dataset.lang = 'en';
  }}
}})();
"""


def build_config_from_env(environ: dict[str, str] | None = None) -> tuple[str, str, str]:
    env = os.environ if environ is None else environ
    environment = (
        env.get("LEGAL_ENVIRONMENT", "").strip()
        or env.get("FLAVOR", "").strip()
        or "development"
    )
    apk_url = env.get("ANDROID_APK_URL", "").strip()
    if apk_url:
        if not apk_url.startswith("https://"):
            raise SystemExit("ANDROID_APK_URL must be an https URL")
        android_url = "/android"
    else:
        android_url = ""
    contact_email = env.get("CONTACT_EMAIL", "").strip() or DEFAULT_CONTACT_EMAIL
    return environment, android_url, contact_email


def main(argv: list[str] | None = None) -> int:
    args = sys.argv[1:] if argv is None else argv
    output = Path(args[0] if args else "build/web/about/config.js")
    environment, android_url, contact_email = build_config_from_env()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        render_config_js(environment, android_url, contact_email),
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
