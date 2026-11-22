#!/usr/bin/env python3
"""Read-only Firebase key discovery and isolated Terraform backend config."""

import json
import os
from pathlib import Path
import re
import shutil
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen


def discover_api_key(project, app, token, opener=urlopen):
    url = (
        'https://firebase.googleapis.com/v1beta1/projects/'
        f'{quote(project, safe="")}/webApps/{quote(app, safe="")}'
    )
    request = Request(url, headers={
        'Authorization': f'Bearer {token}',
        'x-goog-user-project': project,
    })
    try:
        with opener(request, timeout=30) as response:
            result = json.load(response)
    except (HTTPError, URLError, ValueError) as error:
        raise ValueError(
            'Cannot discover the web API key ID. Check Firebase read access or '
            'set firebase.webApiKeyId in the selected environment.'
        ) from error
    key = result.get('apiKeyId') if isinstance(result, dict) else None
    if not isinstance(key, str) or not re.fullmatch(r'[A-Za-z0-9_-]+', key):
        raise ValueError(
            'Firebase returned no valid apiKeyId. Set firebase.webApiKeyId '
            'from Project settings / Google Cloud API keys.'
        )
    return key


def prepare_config(source, destination, backend, state_path):
    source, destination = Path(source), Path(destination)
    for file in source.glob('*.tf'):
        shutil.copy2(file, destination / file.name)
    lock = source / '.terraform.lock.hcl'
    if lock.exists():
        shutil.copy2(lock, destination / lock.name)
    main = destination / 'main.tf'
    text = main.read_text()
    replacement = (
        '  backend "local" {\n'
        f'    path = {json.dumps(str(state_path)).replace("${", "$${").replace("%{", "%%{")}\n'
        '  }\n'
        if backend == 'local' else '  backend "gcs" {}\n'
    )
    text, count = re.subn(
        r'(?ms)^  backend "gcs" \{\n.*?^  \}\n',
        lambda _: replacement,
        text,
    )
    if count != 1:
        raise ValueError('Expected one GCS backend block in Terraform source.')
    main.write_text(text)


def main():
    try:
        if sys.argv[1] == 'api-key':
            print(discover_api_key(
                os.environ['PROJECT_ID'], os.environ['WEB_APP_ID'],
                os.environ['GOOGLE_OAUTH_ACCESS_TOKEN'],
            ))
        elif sys.argv[1] == 'config':
            prepare_config(*sys.argv[2:])
        else:
            raise ValueError('Unknown bootstrap helper command.')
    except (ValueError, OSError, KeyError) as error:
        sys.exit(str(error))


if __name__ == '__main__':
    main()
