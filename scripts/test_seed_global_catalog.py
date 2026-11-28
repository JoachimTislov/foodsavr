#!/usr/bin/env python3
import io
import json
import os
import re
import sys
import unittest
import urllib.error
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import seed_global_catalog as seeder  # noqa: E402

PRODUCT = {"id": "global-a", "name": "A", "description": "d", "category": "dairy", "barcode": "4006381333931"}


def dart(entries: str) -> str:
    return "static List<Map<String, dynamic>> getProducts() {\n    return [\n" + entries + "\n    ];\n  }"


class ParseTest(unittest.TestCase):
    def test_reads_comments_wrapped_values_and_escapes(self):
        source = dart("""      // Group {not an entry}
      {
        'id': 'global-a',
        'description':
            'Kari\\'s {best}, 1 \\$',
      },""")
        self.assertEqual(seeder.parse_catalog(source), [{"id": "global-a", "description": "Kari's {best}, 1 $"}])

    def test_unsupported_syntax_fails_instead_of_dropping_entries(self):
        for entries in (
            "{'id': 1001},",
            "{'id': \"global-a\"},",
            "{'id': 'global-a' 'b'},",
            "{'id': 'global-$a'},",
            "{'id': 'global-a\\n'},",
            "{'id': 'a', 'id': 'b'},",
            "{'id': 'a'},\n      extraProduct,",
            "{'id': 'a'} {'id': 'b'},",
        ):
            with self.subTest(entries=entries), self.assertRaises(ValueError):
                seeder.parse_catalog(dart(entries))
        with self.assertRaises(ValueError):
            seeder.parse_catalog("class Nothing {}")


class CatalogTest(unittest.TestCase):
    def test_dart_catalog_is_valid_and_completely_parsed(self):
        products = seeder.load_catalog()
        source = seeder.CATALOG.read_text(encoding="utf-8")
        self.assertEqual(len(products), len(re.findall(r"'id':", source)))
        self.assertTrue(25 <= len(products) <= 30)
        self.assertEqual({p["category"] for p in products},
                         seeder.category_keys(seeder.CATEGORIES.read_text(encoding="utf-8")))

    def test_check_digit_matches_published_examples(self):
        self.assertTrue(seeder.is_ean13("4006381333931"))
        self.assertTrue(seeder.is_ean13("5901234123457"))
        for bad in ("4006381333932", "400638133393", "40063813339310", "400638133393a", ""):
            self.assertFalse(seeder.is_ean13(bad), bad)

    def test_validation_rejects_bad_entries(self):
        seeder.validate([PRODUCT], {"dairy"})
        for products, message in (
            ([], "empty"),
            ([{**PRODUCT, "barcode": "4006381333932"}], "invalid EAN-13"),
            ([{**PRODUCT, "category": "frozen"}], "unknown category"),
            ([{**PRODUCT, "id": "a/b"}], "id must look like"),
            ([{**PRODUCT, "name": " "}], "non-empty fields"),
            ([{k: v for k, v in PRODUCT.items() if k != "barcode"}], "non-empty fields"),
            ([PRODUCT, {**PRODUCT, "barcode": "5901234123457"}], "duplicate id"),
            ([PRODUCT, {**PRODUCT, "id": "global-b"}], "duplicate barcode"),
        ):
            with self.subTest(message=message), self.assertRaisesRegex(ValueError, message):
                seeder.validate(products, {"dairy"})

    def test_fields_match_the_dart_rest_schema(self):
        model = (seeder.ROOT / "lib/models/product_model.dart").read_text(encoding="utf-8")
        product_class = model[model.index("abstract class Product with"):]
        method = product_class[product_class.index("toFirestoreRest() {"):]
        expected = re.findall(r"(?m)^      '(\w+)': \{\s*'(\w+Value)'", method)
        actual = [(key, next(iter(value))) for key, value in seeder.firestore_fields(PRODUCT).items()]
        self.assertEqual(actual, expected)


class MainTest(unittest.TestCase):
    def run_main(self, *args):
        output = io.StringIO()
        with redirect_stdout(output), redirect_stderr(output):
            code = seeder.main(list(args))
        return code, output.getvalue()

    def apply(self, *args):
        with patch.object(seeder.urllib.request, "urlopen", return_value=MagicMock()) as urlopen:
            code, output = self.run_main(*args, "--apply")
        self.assertEqual(code, 0)
        return [entry.args[0] for entry in urlopen.call_args_list], output

    def test_dry_run_is_the_default_and_neither_writes_nor_authenticates(self):
        for args in ((), ("--project", "demo-project"), ("--emulator", "localhost:8080", "--dry-run")):
            with self.subTest(args=args), patch.object(seeder.urllib.request, "urlopen") as urlopen, \
                    patch.object(seeder, "access_token") as token:
                code, output = self.run_main(*args)
            self.assertEqual(code, 0)
            self.assertIn("nothing written", output)
            urlopen.assert_not_called()
            token.assert_not_called()

    def test_apply_needs_a_target_and_excludes_dry_run(self):
        for args in (("--apply",), ("--apply", "--dry-run", "--project", "demo-project"),
                     ("--emulator", "http://example.com"), ("--project", "a/b")):
            with self.subTest(args=args), self.assertRaises(SystemExit):
                self.run_main(*args)

    def test_emulator_patches_every_product_without_a_real_token(self):
        with patch.dict(os.environ, {"ACCESS_TOKEN": "real-token"}):
            requests, _ = self.apply("--emulator", "localhost:8080")
        products = seeder.load_catalog()
        self.assertEqual(len(requests), len(products))
        first = requests[0]
        self.assertEqual(first.get_method(), "PATCH")
        self.assertEqual(first.full_url, "http://localhost:8080/v1/projects/demo-project/databases/(default)"
                                         f"/documents/products/{products[0]['id']}")
        self.assertEqual(first.get_header("Authorization"), "Bearer owner")
        self.assertEqual(json.loads(first.data), {"fields": seeder.firestore_fields(products[0])})

    def test_collection_can_be_overridden(self):
        requests, _ = self.apply("--emulator", "localhost:8080", "--collection", "global_products")
        self.assertIn("/documents/global_products/global-", requests[0].full_url)

    def test_reruns_send_identical_requests(self):
        def snapshot():
            return [(r.full_url, r.data) for r in self.apply("--emulator", "localhost:8080")[0]]

        self.assertEqual(snapshot(), snapshot())

    def test_cloud_project_uses_the_access_token_and_never_prints_it(self):
        with patch.dict(os.environ, {"ACCESS_TOKEN": "secret-token"}):
            requests, output = self.apply("--project", "foodsavr-test")
        self.assertTrue(requests[0].full_url.startswith(
            "https://firestore.googleapis.com/v1/projects/foodsavr-test/databases/(default)/documents/products/"))
        self.assertEqual(requests[0].get_header("Authorization"), "Bearer secret-token")
        self.assertNotIn("secret-token", output)

    def test_gcloud_supplies_the_token_and_its_absence_fails(self):
        with patch.dict(os.environ, {"ACCESS_TOKEN": ""}):
            with patch.object(seeder.subprocess, "check_output", return_value="from-gcloud\n"):
                self.assertEqual(seeder.access_token(), "from-gcloud")
            with patch.object(seeder.subprocess, "check_output", side_effect=FileNotFoundError):
                with self.assertRaisesRegex(SystemExit, "gcloud auth login"):
                    seeder.access_token()

    def test_invalid_catalog_writes_nothing(self):
        with patch.object(seeder, "parse_catalog", return_value=[{**PRODUCT, "barcode": "1"}]), \
                patch.object(seeder.urllib.request, "urlopen") as urlopen:
            with self.assertRaisesRegex(SystemExit, "invalid EAN-13"):
                self.run_main("--emulator", "localhost:8080", "--apply")
        urlopen.assert_not_called()

    def test_http_error_stops_and_names_the_document(self):
        error = urllib.error.HTTPError("u", 403, "Forbidden", {}, io.BytesIO(b"denied"))
        with patch.object(seeder.urllib.request, "urlopen", side_effect=error) as urlopen:
            with self.assertRaisesRegex(SystemExit, "error: products/global-.*HTTP 403: denied"):
                self.run_main("--emulator", "localhost:8080", "--apply")
        urlopen.assert_called_once()


if __name__ == "__main__":
    unittest.main()
