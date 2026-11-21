"""Fail a documentation build when an internal link or asset is missing."""

import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit


class References(HTMLParser):
    def __init__(self):
        super().__init__()
        self.urls = []

    def handle_starttag(self, tag, attrs):
        for key, value in attrs:
            if value and ((tag == 'a' and key == 'href') or key == 'src' or (tag == 'link' and key == 'href')):
                self.urls.append(value)


def check(root, prefix="/foodsavr/"):
    errors = []
    pages = list(root.rglob('*.html'))
    for page in pages:
        parser = References()
        parser.feed(page.read_text())
        for reference in parser.urls:
            url = urlsplit(reference)
            if url.scheme or url.netloc or not url.path:
                continue
            path = unquote(url.path)
            if path.startswith('/'):
                if not path.startswith(prefix):
                    errors.append(f'{page.relative_to(root)}: outside site prefix: {reference}')
                    continue
                target = root / path[len(prefix):]
            else:
                target = page.parent / path
            if target.is_dir():
                target /= 'index.html'
            if not target.is_file():
                errors.append(f'{page.relative_to(root)}: missing {reference}')
    if not pages or not (root / 'index.html').is_file():
        errors.append('Site must contain index.html')
    if errors:
        raise SystemExit('\n'.join(errors))
    print(f'Local navigation and assets verified across {len(pages)} HTML pages.')


if __name__ == '__main__':
    check(Path(sys.argv[1]).resolve())
