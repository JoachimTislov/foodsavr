#!/usr/bin/env python3
"""Upload one APK to an existing Drive folder using a user's OAuth refresh token."""

import json
import os
from pathlib import Path
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlparse
from urllib.request import Request, urlopen


def upload(path):
    folder = os.environ["GOOGLE_DRIVE_FOLDER_ID"]
    if not re.fullmatch(r"[A-Za-z0-9_-]+", folder):
        raise ValueError("GOOGLE_DRIVE_FOLDER_ID must be a folder ID, not a URL")
    credentials = json.loads(os.environ["GOOGLE_DRIVE_OAUTH_JSON"])
    token_body = urlencode({
        "grant_type": "refresh_token",
        "client_id": credentials["client_id"],
        "client_secret": credentials["client_secret"],
        "refresh_token": credentials["refresh_token"],
    }).encode()
    with urlopen(Request("https://oauth2.googleapis.com/token", data=token_body), timeout=60) as response:
        access_token = json.load(response)["access_token"]
    headers = {"Authorization": f"Bearer {access_token}"}
    size = path.stat().st_size
    if not size:
        raise ValueError("APK is empty")
    metadata = json.dumps({"name": path.name, "parents": [folder]}).encode()
    request = Request(
        "https://www.googleapis.com/upload/drive/v3/files?"
        "uploadType=resumable&supportsAllDrives=true&fields=id,webViewLink",
        data=metadata,
        headers={**headers, "Content-Type": "application/json",
                 "X-Upload-Content-Type": "application/vnd.android.package-archive",
                 "X-Upload-Content-Length": str(size)},
    )
    with urlopen(request, timeout=60) as response:
        location = response.headers["Location"]
    target = urlparse(location)
    if target.scheme != "https" or target.hostname != "www.googleapis.com":
        raise ValueError("Unexpected Drive upload URL")
    with path.open("rb") as apk:
        chunks = iter(lambda: apk.read(1024 * 1024), b"")
        request = Request(location, data=chunks, method="PUT", headers={
            **headers, "Content-Type": "application/vnd.android.package-archive",
            "Content-Length": str(size),
        })
        with urlopen(request, timeout=600) as response:
            result = json.load(response)
    file_id = result["id"]
    if not re.fullmatch(r"[A-Za-z0-9_-]+", file_id):
        raise ValueError("Unexpected Drive file ID")
    link = f"https://drive.google.com/file/d/{file_id}/view"
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as summary:
        summary.write(f"\n[Download Android APK]({link})\n")
    print(f"APK uploaded: {link}")


if __name__ == "__main__":
    try:
        upload(Path(sys.argv[1]))
    except HTTPError as error:
        # OAuth and Drive responses can contain credentials; log only the status.
        print(f"::error::Google Drive request failed (HTTP {error.code})")
        raise SystemExit(1)
    except (ValueError, KeyError, OSError, URLError):
        print("::error::Drive upload failed; check the APK, folder ID and OAuth credentials")
        raise SystemExit(1)
