#!/usr/bin/env python3
"""Seed the global product catalog into Firestore over its REST API.

The catalog is parsed from lib/mock_data/global_products.dart, its only source.
Every entry, category and EAN-13 check digit is validated before anything is
written. Documents are replaced by id with PATCH, so re-running is safe.

  seed_global_catalog.py                                     # validate and list (dry run)
  seed_global_catalog.py --emulator localhost:8080 --apply   # local emulator
  seed_global_catalog.py --project <project-id> --apply      # cloud project

A cloud project needs ACCESS_TOKEN or a `gcloud auth login`.

The default target, `products`, is where the app reads its global catalog
(lib/repositories/product_repository.dart). `--collection global_products`
selects the legacy path, which firestore.rules denies to clients.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "lib/mock_data/global_products.dart"
CATEGORIES = ROOT / "lib/constants/product_categories.dart"
COLLECTIONS = ("products", "global_products")
EMULATOR_PROJECT = "demo-project"
FIELDS = ("id", "name", "description", "category", "barcode")

STRING = r"'(?:[^'\\\n]|\\.)*'"
PAIR = re.compile(rf"\s*({STRING})\s*:\s*({STRING})\s*(,|(?=\}}))")
OPEN = re.compile(r"\s*\{")
CLOSE = re.compile(r"\s*\}\s*(,|\Z)")


def unquote(literal: str) -> str:
    body = literal[1:-1]
    if re.search(r"(?<!\\)(?:\\\\)*\$", body):
        raise ValueError(f"string interpolation is not supported: {literal}")

    def unescape(match: re.Match) -> str:
        if match.group(1) not in "'\\$\"":
            raise ValueError(f"unsupported escape in {literal}")
        return match.group(1)

    return re.sub(r"\\(.)", unescape, body)


def parse_catalog(source: str) -> list[dict[str, str]]:
    """The maps returned by getProducts. Anything unrecognised is an error, never skipped."""
    found = re.search(r"getProducts\(\)\s*\{\s*return\s*\[(.*?)\n\s*\];", source, re.S)
    if not found:
        raise ValueError("cannot find the list returned by getProducts()")
    body = re.sub(r"(?m)^\s*//.*$", "", found.group(1)).rstrip()
    products, position = [], 0
    while position < len(body):
        opened = OPEN.match(body, position)
        if not opened:
            raise ValueError(f"unsupported catalog syntax near: {body[position:position + 60].strip()!r}")
        position = opened.end()
        product: dict[str, str] = {}
        while pair := PAIR.match(body, position):
            key = unquote(pair.group(1))
            if key in product:
                raise ValueError(f"duplicate key {key!r} in a catalog entry")
            product[key] = unquote(pair.group(2))
            position = pair.end()
        closed = CLOSE.match(body, position)
        if not closed:
            raise ValueError(f"unsupported catalog syntax near: {body[position:position + 60].strip()!r}")
        position = closed.end()
        products.append(product)
    return products


def category_keys(source: str) -> set[str]:
    return set(re.findall(r"ProductCategory\(key:\s*'([^']+)'", source))


def ean13_check_digit(digits: str) -> int:
    """GS1 check digit of the first twelve digits."""
    total = sum(int(digit) * (3 if index % 2 else 1) for index, digit in enumerate(digits[:12]))
    return (10 - total % 10) % 10


def is_ean13(barcode: str) -> bool:
    return bool(re.fullmatch(r"[0-9]{13}", barcode)) and ean13_check_digit(barcode) == int(barcode[12])


def validate(products: list[dict[str, str]], categories: set[str]) -> None:
    if not products:
        raise ValueError("the catalog is empty")
    errors, ids, barcodes = [], set(), set()
    for index, product in enumerate(products):
        label = product.get("id") or f"entry {index + 1}"
        if set(product) != set(FIELDS) or not all(value.strip() for value in product.values()):
            errors.append(f"{label}: needs exactly the non-empty fields {', '.join(FIELDS)}")
            continue
        if not re.fullmatch(r"global-[a-z0-9-]+", product["id"]):
            errors.append(f"{label}: id must look like global-name")
        if product["category"] not in categories:
            errors.append(f"{label}: unknown category {product['category']!r}")
        if not is_ean13(product["barcode"]):
            errors.append(f"{label}: invalid EAN-13 barcode {product['barcode']!r}")
        if product["id"] in ids:
            errors.append(f"{label}: duplicate id")
        if product["barcode"] in barcodes:
            errors.append(f"{label}: duplicate barcode {product['barcode']}")
        ids.add(product["id"])
        barcodes.add(product["barcode"])
    if errors:
        raise ValueError("invalid catalog:\n  " + "\n  ".join(errors))


def load_catalog() -> list[dict[str, str]]:
    products = parse_catalog(CATALOG.read_text(encoding="utf-8"))
    validate(products, category_keys(CATEGORIES.read_text(encoding="utf-8")))
    return products


def firestore_fields(product: dict[str, str]) -> dict:
    """Mirror of Product.toFirestoreRest() for a global product without stock."""

    def string(value: str) -> dict:
        return {"stringValue": value}

    return {
        "id": string(product["id"]),
        "name": string(product["name"]),
        "description": string(product["description"]),
        "userId": string("global"),
        "expiries": {"arrayValue": {"values": []}},
        "nonExpiringQuantity": {"integerValue": "0"},
        "category": string(product["category"]),
        "imageUrl": string(""),
        "barcode": string(product["barcode"]),
        "isGlobal": {"booleanValue": True},
        "tags": {"arrayValue": {"values": []}},
    }


def access_token() -> str:
    token = os.environ.get("ACCESS_TOKEN", "").strip()
    if not token:
        try:
            token = subprocess.check_output(["gcloud", "auth", "print-access-token"], text=True).strip()
        except (OSError, subprocess.CalledProcessError):
            pass
    if not token:
        raise SystemExit("error: no Google Cloud credentials; run `gcloud auth login` or set ACCESS_TOKEN")
    return token


def seed(products: list[dict[str, str]], documents_url: str, collection: str, token: str) -> None:
    for product in products:
        request = urllib.request.Request(
            f"{documents_url}/{collection}/{product['id']}",
            data=json.dumps({"fields": firestore_fields(product)}).encode(),
            method="PATCH",
            headers={"Content-Type": "application/json", "Authorization": f"Bearer {token}"},
        )
        try:
            with urllib.request.urlopen(request, timeout=30):
                pass
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", "replace")[:500]
            raise SystemExit(f"error: {collection}/{product['id']}: HTTP {error.code}: {detail}") from None
        except OSError as error:
            raise SystemExit(f"error: {collection}/{product['id']}: {error}") from None


def emulator_address(value: str) -> str:
    # A host:port only, so the emulator's bypass token cannot be aimed at a URL.
    if not re.fullmatch(r"[A-Za-z0-9.-]+:[0-9]{1,5}", value):
        raise argparse.ArgumentTypeError("expected HOST:PORT")
    return value


def project_id(value: str) -> str:
    if not re.fullmatch(r"[a-z][a-z0-9-]{4,28}[a-z0-9]", value):
        raise argparse.ArgumentTypeError("not a Firebase project id")
    return value


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--emulator", type=emulator_address, metavar="HOST:PORT", help="Firestore emulator")
    parser.add_argument("--project", type=project_id, metavar="PROJECT_ID",
                        help=f"Firebase project (with --emulator, default {EMULATOR_PROJECT})")
    parser.add_argument("--collection", choices=COLLECTIONS, default=COLLECTIONS[0], help="target collection")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true", help="validate and list without writing (default)")
    mode.add_argument("--apply", action="store_true", help="write the catalog")
    args = parser.parse_args(argv)
    if args.apply and not (args.emulator or args.project):
        parser.error("--apply needs --emulator or --project")
    try:
        products = load_catalog()
    except ValueError as error:
        raise SystemExit(f"error: {error}") from None

    project = args.project or (EMULATOR_PROJECT if args.emulator else "(none)")
    target = f"emulator {args.emulator}, project {project}" if args.emulator else f"project {project}"
    if not args.apply:
        for product in products:
            print(f"{args.collection}/{product['id']}  {product['barcode']}  {product['name']}")
        print(f"Dry run ({target}): {len(products)} valid products, nothing written. Pass --apply to write.")
        return 0

    base = f"http://{args.emulator}" if args.emulator else "https://firestore.googleapis.com"
    # The emulator accepts `owner` as a rules-bypassing token; it never gets a real one.
    token = "owner" if args.emulator else access_token()
    seed(products, f"{base}/v1/projects/{project}/databases/(default)/documents", args.collection, token)
    print(f"Seeded {len(products)} products into {args.collection} ({target}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
