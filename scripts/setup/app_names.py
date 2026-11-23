"""GitHub App names used by interactive setup."""

import re
import sys


def app_name(repo: str, role: str, *, owner_suffix: bool = False) -> str:
    owner, name = repo.lower().split("/", 1)
    name = re.sub(r"[^a-z0-9-]+", "-", name).strip("-") or "foodsavr"
    suffix = ""
    if owner_suffix:
        suffix = "-" + (re.sub(r"[^a-z0-9-]+", "-", owner).strip("-")[:8] or "fork")
    room = 34 - len(role) - len(suffix) - 1
    return f"{name[:room].rstrip('-')}-{role}{suffix}"


if __name__ == "__main__":
    print(app_name(sys.argv[1], sys.argv[2], owner_suffix="--owner-suffix" in sys.argv[3:]))
