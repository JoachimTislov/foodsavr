"""Keep published documentation links pointed at the appropriate source."""

import posixpath
import re
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit

from mkdocs.utils import get_relative_url

ROOT = Path(__file__).resolve().parents[2]
# Markdown links and images. Leave absolute URLs and same-page anchors alone.
LINK = re.compile(r"(!?\[[^\]\n]*\]\()([^\s)]+)([^)]*\))")


def on_page_markdown(markdown, page, config, files):
    def resolve(match):
        original = match[2]
        url = urlsplit(original)
        if url.scheme or url.netloc or not url.path or url.path.startswith("/"):
            return match[0]
        target = posixpath.normpath(posixpath.join(posixpath.dirname(page.file.src_uri), url.path))
        if target == "README.md":
            relative = posixpath.relpath("project-overview.md", posixpath.dirname(page.file.src_uri) or ".")
            return match[1] + urlunsplit(("", "", relative, url.query, url.fragment)) + match[3]
        if files.get_file_from_path(target):
            return match[0]
        # Code, templates, and directory references belong in the repository.
        repo_url = (config.get("repo_url") or "").rstrip("/")
        parsed_repo = urlsplit(repo_url)
        if match[1].startswith("!"):
            if parsed_repo.netloc == "github.com" and parsed_repo.path.strip("/"):
                base = f"https://raw.githubusercontent.com/{parsed_repo.path.strip('/')}/main/"
            elif repo_url:
                base = f"{repo_url}/raw/main/"
            else:
                base = ""
        else:
            kind = "tree" if (ROOT / target).is_dir() else "blob"
            base = f"{repo_url}/{kind}/main/" if repo_url else ""
        rewritten = urlunsplit(("", "", base + target, url.query, url.fragment))
        return match[1] + rewritten + match[3]

    def image(match):
        url = match[2]
        if urlsplit(url).scheme or url.startswith("/"):
            return match[0]
        target = posixpath.normpath(posixpath.join(posixpath.dirname(page.file.src_uri), url))
        file = files.get_file_from_path(target)
        if file:
            return match[1] + get_relative_url(file.url, page.url) + match[3]
        return match[0]

    markdown = re.sub(r'(<img\b[^>]*\bsrc=["\'])([^"\']+)(["\'])', image, markdown)
    return LINK.sub(resolve, markdown)
