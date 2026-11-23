"""Check or apply Meta's documented Application settings using an app token."""

import argparse
import json
import os
import re
import sys
from urllib.parse import urlencode
from urllib.request import Request, urlopen

GRAPH_API = "https://graph.facebook.com/v27.0"
LEGAL_SITE = "https://my-foodsavr-store.web.app"
URL_FIELDS = ("website_url", "privacy_policy_url", "terms_of_service_url")
FIELDS = ("app_domains", *URL_FIELDS)


def graph_request(endpoint, token, settings=None):
    if settings is None:
        request = Request(f"{endpoint}?{urlencode({'fields': ','.join(FIELDS)})}")
    else:
        form = dict(settings)
        if "app_domains" in form:
            form["app_domains"] = json.dumps(form["app_domains"])
        request = Request(endpoint, data=urlencode(form).encode())
    request.add_unredirected_header("Authorization", f"Bearer {token}")
    with urlopen(request, timeout=20) as response:
        payload = json.load(response)
    if not isinstance(payload, dict) or "error" in payload:
        raise ValueError("Invalid Graph response")
    return payload


def changed_settings(current, project):
    website_domain = f"{project}.web.app"
    desired = {
        "website_url": f"https://{website_domain}/",
        "privacy_policy_url": f"{LEGAL_SITE}/privacy",
        "terms_of_service_url": f"{LEGAL_SITE}/terms",
    }
    updates = {key: value for key, value in desired.items() if current.get(key) != value}
    domains = current.get("app_domains", [])
    if not isinstance(domains, list) or not all(isinstance(domain, str) for domain in domains):
        raise ValueError("Invalid app_domains response")
    if website_domain not in domains:
        updates["app_domains"] = [*domains, website_domain]
    return updates


def sync(project, app_id, token, check, request=graph_request):
    endpoint = f"{GRAPH_API}/{app_id}"

    def read():
        current = request(endpoint, token)
        if current.get("id") != app_id:
            raise ValueError("Graph returned a different app ID")
        return changed_settings(current, project)

    updates = read()
    if not updates:
        print("Meta app settings are current.")
        return 0
    if check:
        print(f"Meta app settings need updating: {', '.join(sorted(updates))}.")
        return 1
    if request(endpoint, token, updates).get("success") is not True or read():
        raise ValueError("Graph settings could not be verified")
    print(f"Updated Meta app settings: {', '.join(sorted(updates))}.")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    app_id = os.environ.get("FACEBOOK_APP_ID", "")
    secret = os.environ.get("FACEBOOK_APP_SECRET", "")
    if not re.fullmatch(r"[0-9]+", app_id) or not secret:
        print("Meta app ID or app secret is missing or invalid.", file=sys.stderr)
        return 1
    try:
        return sync(args.project, app_id, f"{app_id}|{secret}", args.check)
    except (OSError, ValueError):
        # Graph responses and HTTP exceptions may contain credentials or request details.
        print("Meta Graph API could not verify app settings. Check app credentials and access.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
