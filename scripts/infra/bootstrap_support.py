#!/usr/bin/env python3
"""Read-only Firebase key discovery, worktree-safe state paths, and Terraform config prep."""

import json
import os
from pathlib import Path
import re
import shutil
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

SAFE_SEGMENT_RE = re.compile(r'^[A-Za-z0-9][A-Za-z0-9._-]*$')


def validate_segment(value, label):
    if not isinstance(value, str) or not SAFE_SEGMENT_RE.fullmatch(value) or value in {'.', '..'}:
        raise ValueError(f'{label} must be a safe path segment without separators or traversal.')
    return value


def local_state_path(repo_slug, stack, xdg_state_home=None, home=None):
    """Return the worktree-safe XDG local Terraform state file path (ADR 0008)."""
    if not isinstance(repo_slug, str) or repo_slug.count('/') != 1:
        raise ValueError('Repository slug must be in owner/repo format.')
    owner, repo = repo_slug.split('/', 1)
    validate_segment(owner, 'repository owner')
    validate_segment(repo, 'repository name')
    validate_segment(stack, 'state stack')

    state_root_env = xdg_state_home if xdg_state_home is not None else os.environ.get('XDG_STATE_HOME', '')
    if state_root_env:
        base = Path(state_root_env).expanduser()
    else:
        home_dir = Path(home).expanduser() if home is not None else Path.home()
        base = home_dir / '.local' / 'state'
    return base / 'foodsavr' / 'terraform' / owner / repo / stack / 'terraform.tfstate'


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
    escaped_state = json.dumps(str(state_path)).replace('${', '$${').replace('%{', '%%{')
    replacement = (
        '  backend "local" {\n'
        f'    path = {escaped_state}\n'
        '  }\n'
        if backend == 'local' else '  backend "gcs" {}\n'
    )
    text, count = re.subn(
        r'(?ms)^  backend "(?:gcs|local)" \{(?:\n.*?^  \}|\})\n',
        lambda _: replacement,
        text,
    )
    if count != 1:
        raise ValueError('Expected one GCS or local backend block in Terraform source.')
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
        elif sys.argv[1] == 'state-path':
            print(local_state_path(sys.argv[2], sys.argv[3]))
        else:
            raise ValueError('Unknown bootstrap helper command.')
    except (ValueError, OSError, KeyError, IndexError) as error:
        sys.exit(str(error))


if __name__ == '__main__':
    main()
