#!/usr/bin/env python3
"""Keep Firebase Hosting storage under budget before a deploy.

Usage: hosting_storage_guard.py {preview|live} NEW_BUILD_BYTES [--dry-run]
env:   PROJECT_ID, SITE_ID (defaults to PROJECT_ID), ACCESS_TOKEN
       (else `gcloud auth print-access-token`), KEEP_CHANNEL (preview
       channel being deployed; never deleted).

Storage = sum of versionBytes of FINALIZED versions across the project.
Cleanup is confined to the selected site.
- Build over BUILD_WARN (5 GB): warning + job summary.
- Over SOFT_LIMIT (8 GB, incl. the new build): delete preview channels,
  oldest first. A preview that still does not fit is skipped (exit 3), so
  previews never eat production headroom.
- live: if still over HARD_LIMIT (10 GB), delete live versions older than
  the KEEP_LIVE (3) latest, oldest first. Fail (exit 2) if it cannot fit.
"""

import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
from urllib.parse import urlencode

GB = 1024**3
SOFT_LIMIT = 8 * GB
HARD_LIMIT = 10 * GB
KEEP_LIVE = 3
BUILD_WARN = 5 * GB
API = "https://firebasehosting.googleapis.com/v1beta1"


def token():
    access_token = os.environ.get("ACCESS_TOKEN", "").strip()
    if not access_token:
        try:
            access_token = subprocess.check_output(
                ["gcloud", "auth", "print-access-token"], text=True
            ).strip()
        except (OSError, subprocess.CalledProcessError):
            pass
    if not access_token:
        sys.exit("::error::Hosting storage check needs Google Cloud credentials. "
                 "Run `gcloud auth login` or provide a valid ACCESS_TOKEN.")
    return access_token


TOKEN = None


def call(method, path, params=""):
    req = urllib.request.Request(
        f"{API}/{path}{params}",
        method=method,
        headers={"Authorization": f"Bearer {TOKEN}", "x-goog-user-project": os.environ["PROJECT_ID"]},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as res:
            body = res.read()
    except urllib.error.HTTPError as e:
        if e.code in (401, 403):
            sys.exit(f"::error::Hosting storage check denied ({e.code}). "
                     "Use valid Google Cloud credentials with access to the selected Firebase project.")
        sys.exit(f"::error::{method} {path} -> {e.code}: {e.read().decode()[:500]}")
    return json.loads(body) if method == "GET" else None


def list_all(path, key):
    items, seen_tokens = [], set()
    params = {"pageSize": 100}
    while True:
        res = call("GET", path, "?" + urlencode(params))
        if not isinstance(res, dict) or "error" in res:
            incomplete(path)
        page = res.get("nextPageToken", "")
        rows = res.get(key, [] if not seen_tokens and not page else None)
        if not isinstance(rows, list) or not isinstance(page, str) or page in seen_tokens:
            incomplete(path)
        items.extend(rows)
        if not page:
            return items
        seen_tokens.add(page)
        params["pageToken"] = page


def incomplete(path):
    print(f"::error::Incomplete Hosting inventory for {path}.")
    sys.exit(2)


def scoped_name(row, prefix):
    name = row["name"]
    if not re.fullmatch(re.escape(prefix) + r"[a-zA-Z0-9_-]+", name):
        incomplete(prefix)
    return name


def gb(n):
    return f"{n / GB:.2f} GB"


def main():
    global TOKEN
    args = [a for a in sys.argv[1:] if a != "--dry-run"]
    dry = "--dry-run" in sys.argv
    if len(args) != 2 or args[0] not in ("preview", "live"):
        sys.exit(__doc__)
    target, new_bytes = args[0], int(args[1])
    project = os.environ["PROJECT_ID"]
    site = f"sites/{os.environ.get('SITE_ID', project)}"
    keep_channel = os.environ.get("KEEP_CHANNEL", "")
    TOKEN = token()

    sites = set()
    for row in list_all(f"projects/{project}/sites", "sites"):
        match = re.fullmatch(r"projects/[a-zA-Z0-9_-]+/(sites/[a-z0-9-]+)", row["name"])
        if not match:
            incomplete(f"projects/{project}/sites")
        sites.add(match[1])
    if site not in sites:
        incomplete(f"projects/{project}/{site}")

    sizes = {}
    used = 0
    for project_site in sorted(sites):
        path = f"{project_site}/versions"
        versions = {}
        for version in list_all(path, "versions"):
            if version["status"] != "FINALIZED":
                continue
            name = scoped_name(version, f"{path}/")
            size = int(str(version["versionBytes"]), 10)
            if size < 0 or name in versions:
                incomplete(path)
            versions[name] = size
        used += sum(versions.values())
        if project_site == site:
            sizes = versions

    # Live versions, newest release first; the latest KEEP_LIVE are protected.
    live_versions = []
    for r in list_all(f"{site}/channels/live/releases", "releases"):
        name = r.get("version", {}).get("name")
        if name in sizes and name not in live_versions:
            live_versions.append(name)
    protected = set(live_versions[:KEEP_LIVE])
    live_set = set(live_versions)

    channels = list_all(f"{site}/channels", "channels")
    for channel in channels:
        scoped_name(channel, f"{site}/channels/")
    previews = sorted(
        (c for c in channels if c["name"] != f"{site}/channels/live"),
        key=lambda c: c.get("updateTime", ""),
    )

    # Non-live channels referencing each version (clones can share one).
    refs = {}
    chan_versions = {}
    for ch in previews:
        vs = {
            r.get("version", {}).get("name")
            for r in list_all(f"{ch['name']}/releases", "releases")
        }
        chan_versions[ch["name"]] = vs
        for v in vs:
            refs[v] = refs.get(v, 0) + 1

    def act(desc, method, path):
        print(("[dry-run] " if dry else "") + desc)
        if not dry:
            call(method, path)

    print(f"Hosting storage: {gb(used)} + new build {gb(new_bytes)}")
    if new_bytes > BUILD_WARN:
        msg = f"Web build is {gb(new_bytes)} (over {gb(BUILD_WARN)}); check build/web for bloat."
        print(f"::warning::{msg}")
        summary = os.environ.get("GITHUB_STEP_SUMMARY")
        if summary:
            with open(summary, "a") as f:
                f.write(f"⚠️ {msg}\n")

    # 1) Over soft limit -> drop previews, oldest first.
    for ch in previews:
        if used + new_bytes <= SOFT_LIMIT:
            break
        cid = ch["name"].rsplit("/", 1)[1]
        if cid == keep_channel:
            continue
        freed = 0
        for name in chan_versions[ch["name"]]:
            refs[name] = refs.get(name, 1) - 1
            if refs[name] <= 0 and name in sizes and name not in live_set:
                freed += sizes.pop(name)
        act(f"Deleting preview channel {cid} (frees ~{gb(freed)})", "DELETE", ch["name"])
        used -= freed

    if target == "preview":
        if used + new_bytes > SOFT_LIMIT:
            print(f"::warning::Preview skipped: {gb(used + new_bytes)} would exceed {gb(SOFT_LIMIT)}.")
            sys.exit(3)
        return

    # 2) Live: over hard limit -> drop old live versions beyond the latest KEEP_LIVE.
    for name in reversed(live_versions):
        if used + new_bytes <= HARD_LIMIT:
            break
        if name in protected or name not in sizes or refs.get(name, 0) > 0:
            continue
        act(f"Deleting old live version {name.rsplit('/', 1)[1]} ({gb(sizes[name])})", "DELETE", name)
        used -= sizes.pop(name)

    if used + new_bytes > HARD_LIMIT:
        print(f"::error::Cannot fit live deploy under {gb(HARD_LIMIT)} without touching the {KEEP_LIVE} latest releases.")
        sys.exit(2)
    print(f"OK: {gb(used + new_bytes)} after deploy")


if __name__ == "__main__":
    main()
