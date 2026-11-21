#!/usr/bin/env python3
"""Keep Firebase Hosting storage under budget before a deploy.

Usage: hosting_storage_guard.py {preview|live} NEW_BUILD_BYTES [--dry-run]
env:   PROJECT_ID, SITE_ID (defaults to PROJECT_ID), ACCESS_TOKEN
       (else `gcloud auth print-access-token`), KEEP_CHANNEL (preview
       channel being deployed; never deleted).

Storage = sum of versionBytes of FINALIZED versions (conservative).
- Build over BUILD_WARN (5 GB): warning + job summary.
- Over SOFT_LIMIT (8 GB, incl. the new build): delete preview channels,
  oldest first. A preview that still does not fit is skipped (exit 3), so
  previews never eat production headroom.
- live: if still over HARD_LIMIT (10 GB), delete live versions older than
  the KEEP_LIVE (3) latest, oldest first. Fail (exit 2) if it cannot fit.
"""

import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

GB = 1024**3
SOFT_LIMIT = 8 * GB
HARD_LIMIT = 10 * GB
KEEP_LIVE = 3
BUILD_WARN = 5 * GB
API = "https://firebasehosting.googleapis.com/v1beta1"


def token():
    return os.environ.get("ACCESS_TOKEN") or subprocess.check_output(
        ["gcloud", "auth", "print-access-token"], text=True
    ).strip()


TOKEN = None


def call(method, path, params=""):
    req = urllib.request.Request(
        f"{API}/{path}{params}",
        method=method,
        headers={"Authorization": f"Bearer {TOKEN}", "x-goog-user-project": os.environ["PROJECT_ID"]},
    )
    try:
        with urllib.request.urlopen(req) as res:
            body = res.read()
    except urllib.error.HTTPError as e:
        sys.exit(f"::error::{method} {path} -> {e.code}: {e.read().decode()[:500]}")
    return json.loads(body) if body else {}


def list_all(path, key):
    items, page = [], ""
    while True:
        res = call("GET", path, f"?pageSize=100{'&pageToken=' + page if page else ''}")
        items += res.get(key, [])
        page = res.get("nextPageToken")
        if not page:
            return items


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

    sizes = {
        v["name"]: int(v.get("versionBytes", 0))
        for v in list_all(f"{site}/versions", "versions")
        if v.get("status") == "FINALIZED"
    }
    used = sum(sizes.values())

    # Live versions, newest release first; the latest KEEP_LIVE are protected.
    live_versions = []
    for r in list_all(f"{site}/channels/live/releases", "releases"):
        name = r.get("version", {}).get("name")
        if name in sizes and name not in live_versions:
            live_versions.append(name)
    protected = set(live_versions[:KEEP_LIVE])
    live_set = set(live_versions)

    previews = sorted(
        (c for c in list_all(f"{site}/channels", "channels") if not c["name"].endswith("/channels/live")),
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
        if name in protected or name not in sizes:
            continue
        act(f"Deleting old live version {name.rsplit('/', 1)[1]} ({gb(sizes[name])})", "DELETE", name)
        used -= sizes.pop(name)

    if used + new_bytes > HARD_LIMIT:
        print(f"::error::Cannot fit live deploy under {gb(HARD_LIMIT)} without touching the {KEEP_LIVE} latest releases.")
        sys.exit(2)
    print(f"OK: {gb(used + new_bytes)} after deploy")


if __name__ == "__main__":
    main()
