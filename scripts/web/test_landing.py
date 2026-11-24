#!/usr/bin/env python3
"""Tests for the static landing page, links, localization parity, and config generator."""

from __future__ import annotations

import os
import re
import sys
import tempfile
import unittest
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[2]
WEB_DIR = ROOT / "web"
ABOUT_DIR = WEB_DIR / "about"

sys.path.insert(0, str(Path(__file__).resolve().parent))
import write_landing_config as wlc  # noqa: E402

VOID_TAGS = {
    "area",
    "base",
    "br",
    "col",
    "embed",
    "hr",
    "img",
    "input",
    "link",
    "meta",
    "param",
    "source",
    "track",
    "wbr",
}


class LandingHtmlParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.stack: list[str] = []
        self.unclosed_errors: list[str] = []
        self.headings: list[int] = []
        self.links: list[tuple[str, str]] = []
        self.assets: list[str] = []
        self.i18n_keys: set[str] = set()
        self.has_title = False
        self.has_viewport = False
        self.has_description = False
        self.landmarks: set[str] = set()

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attr_map = dict(attrs)
        if tag not in VOID_TAGS:
            self.stack.append(tag)
        if tag in ("header", "main", "footer", "nav"):
            self.landmarks.add(tag)
        if tag == "title":
            self.has_title = True
        if tag == "meta":
            name = (attr_map.get("name") or "").lower()
            if name == "viewport":
                self.has_viewport = True
            if name == "description" and attr_map.get("content"):
                self.has_description = True
        if tag in ("h1", "h2", "h3", "h4", "h5", "h6"):
            self.headings.append(int(tag[1]))
        if tag == "a" and attr_map.get("href"):
            self.links.append((tag, attr_map["href"] or ""))
        if tag == "link" and attr_map.get("href"):
            self.assets.append(attr_map["href"] or "")
        if tag == "script" and attr_map.get("src"):
            self.assets.append(attr_map["src"] or "")
        if tag == "img" and attr_map.get("src"):
            self.assets.append(attr_map["src"] or "")
        for key in ("data-i18n", "data-i18n-aria-label"):
            if attr_map.get(key):
                self.i18n_keys.add(attr_map[key] or "")

    def handle_endtag(self, tag: str) -> None:
        if tag in VOID_TAGS:
            return
        if not self.stack or self.stack[-1] != tag:
            self.unclosed_errors.append(
                f"Mismatched closing </{tag}>; stack={self.stack[-5:]}"
            )
            return
        self.stack.pop()


def extract_js_locale_keys(js_text: str) -> dict[str, set[str]]:
    """Extract top-level string keys inside TRANSLATIONS.en and TRANSLATIONS.nb."""
    result: dict[str, set[str]] = {}
    for locale in ("en", "nb"):
        marker = f"\n    {locale}: {{"
        start = js_text.index(marker) + len(marker)
        # Match until the matching closing brace at 4-space indent
        end = js_text.index("\n    },", start)
        block = js_text[start:end]
        keys = set(re.findall(r"^\s*'([^']+)'\s*:", block, flags=re.MULTILINE))
        result[locale] = keys
    return result


class LandingPageTest(unittest.TestCase):
    def test_html_structure_accessibility_and_local_assets(self) -> None:
        html_path = ABOUT_DIR / "index.html"
        self.assertTrue(html_path.is_file(), "web/about/index.html missing")
        parser = LandingHtmlParser()
        parser.feed(html_path.read_text(encoding="utf-8"))
        parser.close()

        self.assertEqual(parser.unclosed_errors, [])
        self.assertEqual(parser.stack, [])
        self.assertTrue(parser.has_title)
        self.assertTrue(parser.has_viewport)
        self.assertTrue(parser.has_description)
        self.assertEqual(parser.landmarks, {"header", "main", "footer", "nav"})

        # Exactly one <h1> and no skipped heading levels (e.g. h1 -> h3)
        self.assertEqual(parser.headings.count(1), 1)
        for prev, curr in zip(parser.headings, parser.headings[1:]):
            self.assertLessEqual(curr - prev, 1, f"Heading jump {prev} -> {curr}")

        # Verify every local asset referenced in <link>, <script>, <img> exists under web/
        for asset in parser.assets:
            parsed = urlsplit(asset)
            if parsed.scheme or parsed.netloc:
                continue
            rel = parsed.path.lstrip("/")
            self.assertTrue(
                (WEB_DIR / rel).is_file(),
                f"Missing referenced web asset: {asset}",
            )

        # Verify required deep links and CTAs exist
        hrefs = {href for _, href in parser.links}
        for required in ("/", "/privacy", "/terms", "/delete-account", "/android"):
            self.assertIn(required, hrefs, f"Missing required link {required}")

        # Verify no Flutter bundle scripts are pulled into the landing page
        self.assertNotIn("flutter_bootstrap.js", parser.assets)

    def test_translations_have_full_en_nb_parity_and_cover_dom_keys(self) -> None:
        html_path = ABOUT_DIR / "index.html"
        js_path = ABOUT_DIR / "landing.js"

        parser = LandingHtmlParser()
        parser.feed(html_path.read_text(encoding="utf-8"))

        js_text = js_path.read_text(encoding="utf-8")
        locales = extract_js_locale_keys(js_text)
        self.assertEqual(
            locales["en"],
            locales["nb"],
            f"en/nb key mismatch: {locales['en'] ^ locales['nb']}",
        )
        missing = parser.i18n_keys - locales["en"]
        self.assertEqual(missing, set(), f"Missing i18n keys in landing.js: {missing}")

        # Verify ADR 0008 plan limits and coming-soon copy exist in both languages
        for token in ("3 inventories", "200 items", "199 NOK", "349 NOK", "499 NOK", "Coming soon", "Kommer snart"):
            self.assertIn(token, js_text)

    def test_write_landing_config_handles_environments_and_android_url(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "about" / "config.js"
            old_env = os.environ.copy()
            try:
                os.environ["LEGAL_ENVIRONMENT"] = "production"
                os.environ["ANDROID_APK_URL"] = "https://example.com/foodsavr.apk"
                os.environ["CONTACT_EMAIL"] = "privacy@foodsavr.example"
                self.assertEqual(wlc.main([str(out)]), 0)
            finally:
                os.environ.clear()
                os.environ.update(old_env)

            content = out.read_text(encoding="utf-8")
            self.assertIn('"environment": "production"', content)
            self.assertIn('"androidUrl": "/android"', content)
            self.assertIn('"contactEmail": "privacy@foodsavr.example"', content)

    def test_write_landing_config_omits_android_url_when_unset_and_rejects_http(self) -> None:
        env, android_url, email = wlc.build_config_from_env({"FLAVOR": "staging"})
        self.assertEqual(env, "staging")
        self.assertEqual(android_url, "")
        self.assertEqual(email, wlc.DEFAULT_CONTACT_EMAIL)

        with self.assertRaises(SystemExit):
            wlc.build_config_from_env({"ANDROID_APK_URL": "http://insecure.example/app.apk"})


if __name__ == "__main__":
    unittest.main()
