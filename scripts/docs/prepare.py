"""Stage maintained repository sources for the documentation build."""

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def prepare():
    destination = ROOT / "build/docs-source"
    shutil.rmtree(destination, ignore_errors=True)
    destination.mkdir(parents=True)
    for directory in ("doc", "specs/source-of-truth", "assets/logos"):
        shutil.copytree(ROOT / directory, destination / directory)
    for filename in ("README.md", "INDEX.md", "TODO.md", "CONTRIBUTING.md", "coding-standards.md"):
        shutil.copy2(ROOT / filename, destination / ("project-overview.md" if filename == "README.md" else filename))
    shutil.copy2(ROOT / "doc/pages-home.md", destination / "index.md")
    # The landing page has one public URL.
    (destination / "doc/pages-home.md").unlink()
    styles = destination / "stylesheets"
    styles.mkdir()
    shutil.copy2(ROOT / "scripts/docs/extra.css", styles / "extra.css")


if __name__ == "__main__":
    prepare()
