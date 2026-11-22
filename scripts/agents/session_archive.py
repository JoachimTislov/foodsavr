#!/usr/bin/env python3
"""Archive agent session transcripts to a private GCS bucket (#278).

Transcripts are redacted line by line (fail closed), bundled deterministically,
and stored content-addressed so `agentctl trace` -> `agentctl sessions fetch`
works from any machine. Stdlib only; transport is `gcloud storage` via
subprocess with timeouts. Never prints secret values, only rule names and
line numbers.
"""

from __future__ import annotations

import glob
import gzip
import hashlib
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import tomllib
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Any, Callable, Mapping

sys.path.insert(0, str(Path(__file__).resolve().parent))
import traceability as tr  # noqa: E402

SCHEMA = "agent-session-archive/1"
AGENTCTL_SCHEMA = 1
ARCHIVABLE = ("claude-code", "codex")
MIN_SECRET_LENGTH = 8
GCS_URI_RE = re.compile(r"^gs://([a-z0-9][a-z0-9._-]{1,220})/(.+)$")
OBJECT_RE = re.compile(r"^(?P<prefix>.*?)(?P<harness>[a-z][a-z0-9-]*)/(?P<native>[^/]+)/(?P<sha>[0-9a-f]{64})\.tar\.gz$")


class ArchiveError(ValueError):
    """Actionable failure (never contains secret values)."""


# --------------------------------------------------------------- redaction

PLACEHOLDER = r"(?!\[REDACTED)"
EMAIL_RE = re.compile(r"[A-Za-z0-9._%+\-]+@[A-Za-z0-9][A-Za-z0-9.\-]*\.[A-Za-z]{2,}")
FILE_TLDS = {"png", "jpg", "jpeg", "gif", "svg", "webp", "ico", "css", "js", "ts", "json"}

# (name, pattern, replacement). Order matters: specific vendors before generic shapes.
PATTERNS: list[tuple[str, re.Pattern[str], str]] = [
    ("pem-private-key", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----", re.S), "[REDACTED:pem-private-key]"),
    ("github-token", re.compile(r"(?<![A-Za-z0-9])(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})"), "[REDACTED:github-token]"),
    ("anthropic-key", re.compile(r"(?<![A-Za-z0-9])sk-ant-[A-Za-z0-9_\-]{10,}"), "[REDACTED:anthropic-key]"),
    ("openai-key", re.compile(r"(?<![A-Za-z0-9])sk-(?:proj-)?[A-Za-z0-9_\-]{20,}"), "[REDACTED:openai-key]"),
    ("slack-token", re.compile(r"(?<![A-Za-z0-9])xox[abposr]-[A-Za-z0-9-]{10,}"), "[REDACTED:slack-token]"),
    ("aws-access-key", re.compile(r"(?<![A-Za-z0-9])AKIA[0-9A-Z]{16}(?![A-Za-z0-9])"), "[REDACTED:aws-access-key]"),
    ("google-oauth-token", re.compile(r"(?<![A-Za-z0-9])ya29\.[A-Za-z0-9_\-]{20,}"), "[REDACTED:google-oauth-token]"),
    ("google-api-key", re.compile(r"(?<![A-Za-z0-9])AIza[0-9A-Za-z_\-]{35}"), "[REDACTED:google-api-key]"),
    ("jwt", re.compile(r"(?<![A-Za-z0-9_\-])eyJ[A-Za-z0-9_\-]{8,}\.eyJ[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}"), "[REDACTED:jwt]"),
    ("bearer-token", re.compile(r"(?i)\bBearer\s+" + PLACEHOLDER + r"[A-Za-z0-9._~+/\-]{16,}=*"), "Bearer [REDACTED:bearer-token]"),
    ("secret-assignment", re.compile(r"\b([A-Z0-9_]*(?:TOKEN|SECRET|PASSWORD|PASSWD|API_KEY|PRIVATE_KEY|CREDENTIAL)[A-Z0-9_]*)=[\"']?" + PLACEHOLDER + r"[^\s'\"`]{6,}"),
     r"\1=[REDACTED:secret-assignment]"),
]
EMAIL_RULE = "email"


def email_is_exempt(address: str) -> bool:
    local, _, domain = address.lower().rpartition("@")
    return (local.startswith(("noreply", "no-reply")) or local == "git" or domain.endswith("users.noreply.github.com")
            or domain.rsplit(".", 1)[-1] in FILE_TLDS)


class Redactor:
    """Deterministic redaction of registry secrets and known secret shapes."""

    def __init__(self, secrets: Mapping[str, str] | None = None, patterns: list[tuple[str, re.Pattern[str], str]] | None = None) -> None:
        values = {name: value for name, value in (secrets or {}).items() if len(value) >= MIN_SECRET_LENGTH}
        self.secrets = sorted(values.items(), key=lambda item: (-len(item[1]), item[0]))
        self.patterns = PATTERNS if patterns is None else patterns
        self.counts: Counter[str] = Counter()

    def text(self, value: str) -> str:
        for name, secret in self.secrets:
            if secret in value:
                self.counts[f"registry:{name}"] += value.count(secret)
                value = value.replace(secret, f"[REDACTED:{name}]")
        for name, pattern, replacement in self.patterns:
            value, count = pattern.subn(replacement, value)
            if count:
                self.counts[name] += count

        def mail(match: re.Match[str]) -> str:
            if email_is_exempt(match.group(0)):
                return match.group(0)
            self.counts[EMAIL_RULE] += 1
            return "[REDACTED:email]"

        return EMAIL_RE.sub(mail, value)

    def scan(self, value: str) -> list[str]:
        """Rules that still match (after redaction this must be empty)."""
        hits = [f"registry:{name}" for name, secret in self.secrets if secret in value]
        hits += [name for name, pattern, _ in self.patterns if pattern.search(value)]
        if any(not email_is_exempt(m.group(0)) for m in EMAIL_RE.finditer(value)):
            hits.append(EMAIL_RULE)
        return hits

    def json_value(self, value: Any) -> Any:
        if isinstance(value, str):
            return self.text(value)
        if isinstance(value, list):
            return [self.json_value(item) for item in value]
        if isinstance(value, dict):
            return {self.text(str(key)): self.json_value(item) for key, item in value.items()}
        return value


def dump(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"), allow_nan=False)


def redact_jsonl(redactor: Redactor, name: str, data: bytes) -> bytes:
    """Redact decoded strings per line; abort (names + line numbers only) if a line is invalid or a secret survives."""
    out, problems = [], []
    for number, raw in enumerate(data.decode("utf-8", errors="replace").split("\n"), 1):
        if not raw.strip():
            continue
        try:
            parsed = json.loads(raw)
        except ValueError:
            problems.append(f"{name}:{number}: not valid JSON (cannot redact safely)")
            continue
        line = dump(redactor.json_value(parsed))
        try:
            json.loads(line)
        except ValueError:
            problems.append(f"{name}:{number}: redacted line is not valid JSON")
            continue
        hits = redactor.scan(line)
        if hits:
            problems.append(f"{name}:{number}: unredacted after redaction: {', '.join(sorted(set(hits)))}")
        out.append(line)
    if problems:
        raise ArchiveError("redaction aborted (fail closed): " + "; ".join(problems[:10]) + ("" if len(problems) <= 10 else f"; +{len(problems) - 10} more"))
    return ("\n".join(out) + "\n").encode("utf-8") if out else b""


def redact_json_document(redactor: Redactor, name: str, data: bytes) -> bytes:
    try:
        parsed = json.loads(data.decode("utf-8", errors="replace"))
    except ValueError as error:
        raise ArchiveError(f"redaction aborted (fail closed): {name}: not valid JSON") from error
    line = dump(redactor.json_value(parsed))
    hits = redactor.scan(line)
    if hits:
        raise ArchiveError(f"redaction aborted (fail closed): {name}: unredacted after redaction: {', '.join(sorted(set(hits)))}")
    return (line + "\n").encode("utf-8")


# ------------------------------------------------------- registry secrets

def parse_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return values
    for line in lines:
        match = re.match(r"^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$", line)
        if match:
            value = match.group(2).strip()
            if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
                value = value[1:-1]
            values[match.group(1)] = value
    return values


def env_files(root: Path) -> list[Path]:
    files = [root / ".env"]
    try:
        common = subprocess.run(["git", "-C", str(root), "rev-parse", "--git-common-dir"], capture_output=True, text=True,
                                timeout=10, stdin=subprocess.DEVNULL, check=False).stdout.strip()
        if common:
            main = ((root / common).resolve().parent / ".env")
            if main not in files:
                files.append(main)
    except (OSError, subprocess.SubprocessError):
        pass
    return files


def registry_secrets(registry: Path, environ: Mapping[str, str], files: list[Path]) -> dict[str, str]:
    """Values of non-public secrets named in the registry, from the environment and .env files."""
    try:
        names = {name: spec for name, spec in tomllib.loads(registry.read_text(encoding="utf-8")).get("secrets", {}).items()
                 if not spec.get("public", False)}
    except (OSError, tomllib.TOMLDecodeError):
        return {}
    found: dict[str, str] = {}
    for path in files:
        for name, value in parse_env_file(path).items():
            if name in names and len(value) >= MIN_SECRET_LENGTH:
                found.setdefault(name, value)
    for name in names:
        value = environ.get(name, "")
        if len(value) >= MIN_SECRET_LENGTH:
            found[name] = value
    return found


# ------------------------------------------------------------ discovery

def split_session_id(session_id: str) -> tuple[str, str]:
    harness = tr.HARNESS_ALIASES.get(session_id.split(":", 1)[0], session_id.split(":", 1)[0]) if tr.PREFIX_RE.match(session_id) else ""
    native = tr.native_part(session_id)
    if "/" in native or not tr.NATIVE_RE.match(native) or not harness:
        raise ArchiveError(f"cannot archive {session_id!r}: expected <harness>:<native-id> with a plain native id")
    return harness, native


def find_transcripts(session_id: str, home: Path | None = None) -> list[tuple[str, Path]]:
    """(archive name, local path) pairs: the main transcript plus Claude Code subagent files."""
    harness, native = split_session_id(session_id)
    base_home = home or Path.home()
    spec = tr.LOCATORS.get(harness)
    if harness not in ARCHIVABLE or spec is None:
        raise ArchiveError(f"no transcript archiving for harness {harness!r}")
    for base, pattern in spec["transcripts"]:
        root = Path(base.replace("~", str(base_home), 1))
        if harness == "claude-code" and not home and os.environ.get("CLAUDE_CONFIG_DIR"):
            root = Path(os.environ["CLAUDE_CONFIG_DIR"]) / "projects"
        matches = sorted(root.glob(pattern.format(native=glob.escape(native)))) if root.is_dir() else []
        if matches:
            main = matches[0]
            files = [("transcript.jsonl", main)]
            subagents = main.parent / native / "subagents"
            if subagents.is_dir():
                for item in sorted(subagents.iterdir()):
                    if item.is_file() and not item.is_symlink() and (item.name.endswith(".jsonl") or item.name.endswith(".meta.json")):
                        files.append((f"subagents/{item.name}", item))
            return files
    return []


# --------------------------------------------------------------- bundle

class Bundle:
    def __init__(self, data: bytes, sha256: str, manifest: dict[str, Any], uri: str) -> None:
        self.data, self.sha256, self.manifest, self.uri = data, sha256, manifest, uri


def deterministic_targz(entries: list[tuple[str, bytes]]) -> bytes:
    buffer = io.BytesIO()
    with gzip.GzipFile(filename="", mode="wb", fileobj=buffer, mtime=0, compresslevel=9) as gz:
        with tarfile.open(fileobj=gz, mode="w", format=tarfile.GNU_FORMAT) as tar:
            for name, data in sorted(entries):
                info = tarfile.TarInfo(name)
                info.size, info.mtime, info.mode = len(data), 0, 0o644
                info.uid = info.gid = 0
                info.uname = info.gname = ""
                tar.addfile(info, io.BytesIO(data))
    return buffer.getvalue()


def object_name(config: Mapping[str, Any], harness: str, native: str, sha: str) -> str:
    return f"{config.get('prefix', 'sessions/')}{harness}/{native}/{sha}.tar.gz"


def build_bundle(session_id: str, files: list[tuple[str, Path]], redactor: Redactor, config: Mapping[str, Any]) -> Bundle:
    harness, native = split_session_id(session_id)
    entries: list[tuple[str, bytes]] = []
    listing = []
    newest = 0.0
    for arcname, path in sorted(files):
        raw = path.read_bytes()
        newest = max(newest, path.stat().st_mtime)
        data = redact_jsonl(redactor, arcname, raw) if arcname.endswith(".jsonl") else redact_json_document(redactor, arcname, raw)
        entries.append((arcname, data))
        listing.append({"path": arcname, "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)})
    manifest = {
        "schema": SCHEMA, "agentctl_schema": AGENTCTL_SCHEMA, "session_id": session_id, "harness": harness, "native_id": native,
        "files": listing, "redactions": dict(sorted(redactor.counts.items())),
        # Source mtime keeps the bundle reproducible; the wall-clock archive time lives in the session index (`archived_at`).
        "source_mtime": datetime.fromtimestamp(int(newest), timezone.utc).isoformat() if newest else None,
    }
    entries.append(("manifest.json", (json.dumps(manifest, sort_keys=True, indent=2) + "\n").encode("utf-8")))
    data = deterministic_targz(entries)
    sha = hashlib.sha256(data).hexdigest()
    bucket = bucket_name(config)
    return Bundle(data, sha, manifest, f"gs://{bucket}/{object_name(config, harness, native, sha)}")


# ---------------------------------------------------------------- config

def load_config(path: Path, environ: Mapping[str, str] | None = None) -> dict[str, Any] | None:
    """Archive config, or None when archiving is not configured."""
    environ = os.environ if environ is None else environ
    config: dict[str, Any] = {}
    try:
        config = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        config = {}
    override = (environ.get("AGENT_SESSION_BUCKET") or "").strip()
    if override:
        config["bucket"] = override.removeprefix("gs://").strip("/")
    if not config.get("bucket"):
        return None
    config.setdefault("prefix", "sessions/")
    if not str(config["prefix"]).endswith("/"):
        config["prefix"] = f"{config['prefix']}/"
    return config


def bucket_name(config: Mapping[str, Any]) -> str:
    return str(config["bucket"]).removeprefix("gs://").strip("/")


# ------------------------------------------------------------- transport

AUTH_HINTS = ("not logged in", "reauthentication", "gcloud auth login", "401", "anonymous caller", "credentials", "permission", "403")


class Gcloud:
    """Thin `gcloud storage` wrapper: timeouts, no prompts, actionable errors."""

    def __init__(self, project: str | None = None, executable: str | None = None) -> None:
        self.project = project
        self.executable = executable or shutil.which("gcloud")

    def available(self) -> bool:
        return bool(self.executable)

    def run(self, args: list[str], timeout: int = 60) -> subprocess.CompletedProcess[str]:
        if not self.executable:
            raise ArchiveError("gcloud not found on PATH; install the Google Cloud CLI (https://cloud.google.com/sdk/docs/install) then run `gcloud auth login`")
        command = [self.executable, *args]
        if self.project and args[:1] == ["storage"]:
            command += ["--project", self.project]
        try:
            return subprocess.run(command, capture_output=True, text=True, timeout=timeout, stdin=subprocess.DEVNULL, check=False,
                                  env={**os.environ, "CLOUDSDK_CORE_DISABLE_PROMPTS": "1"})
        except subprocess.TimeoutExpired as error:
            raise ArchiveError(f"gcloud timed out after {timeout}s ({' '.join(args[:3])}); check the network") from error
        except OSError as error:
            raise ArchiveError(f"cannot run gcloud: {error}") from error

    def check(self, result: subprocess.CompletedProcess[str], action: str) -> subprocess.CompletedProcess[str]:
        if result.returncode == 0:
            return result
        detail = " ".join((result.stderr or "").split())[:300]
        lowered = detail.lower()
        if "bucket does not exist" in lowered or "404" in lowered and "bucket" in lowered:
            raise ArchiveError(f"{action} failed: bucket missing; the owner runs `scripts/agents/agentctl sessions provision-archive --apply`")
        if any(hint in lowered for hint in AUTH_HINTS):
            raise ArchiveError(f"{action} failed: not authenticated or not permitted; run `gcloud auth login` (an account with storage access to the project). {detail}")
        raise ArchiveError(f"{action} failed: {detail or 'gcloud exited ' + str(result.returncode)}")

    def authenticated(self) -> bool:
        try:
            result = self.run(["auth", "list", "--filter=status:ACTIVE", "--format=value(account)"], timeout=10)
        except ArchiveError:
            return False
        return result.returncode == 0 and bool(result.stdout.strip())

    def upload(self, local: Path, uri: str) -> None:
        """Content-addressed objects are immutable: --no-clobber never overwrites."""
        self.check(self.run(["storage", "cp", "--no-clobber", str(local), uri], timeout=300), "upload")

    def download(self, uri: str, local: Path) -> None:
        self.check(self.run(["storage", "cp", uri, str(local)], timeout=300), "download")

    def list(self, uri: str) -> list[str]:
        result = self.run(["storage", "ls", uri], timeout=30)
        if result.returncode != 0 and "matched no objects" in (result.stderr or "").lower():
            return []
        return [line.strip() for line in self.check(result, "list").stdout.splitlines() if line.strip()]


def ensure_auth(gcloud: Gcloud) -> None:
    if not gcloud.available():
        gcloud.run(["version"])  # raises the actionable "not found" error
    if not gcloud.authenticated():
        raise ArchiveError("gcloud has no active account; run `gcloud auth login` (or `gcloud auth application-default login` for tooling)")


# ------------------------------------------------------------- operations

def archive(session_id: str, config: Mapping[str, Any], redactor: Redactor, gcloud: Gcloud | None = None,
            dry_run: bool = False, home: Path | None = None) -> dict[str, Any]:
    """Redact, bundle, and upload one session. Dry runs never touch gcloud."""
    files = find_transcripts(session_id, home)
    if not files:
        return {"status": "skipped", "reason": "no local transcript found", "session_id": session_id}
    bundle = build_bundle(session_id, files, redactor, config)
    result = {"status": "dry-run" if dry_run else "archived", "session_id": session_id, "uri": bundle.uri, "sha256": bundle.sha256,
              "bytes": len(bundle.data), "manifest": bundle.manifest, "redactions": bundle.manifest["redactions"]}
    if dry_run:
        return result
    gcloud = gcloud or Gcloud(config.get("project"))
    ensure_auth(gcloud)
    with tempfile.TemporaryDirectory() as directory:
        local = Path(directory) / "bundle.tar.gz"
        local.write_bytes(bundle.data)
        gcloud.upload(local, bundle.uri)
    return result


def cache_root() -> Path:
    override = os.environ.get("AGENT_SESSION_CACHE")
    if override:
        return Path(override).expanduser()
    return Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "foodsavr" / "agent-sessions"


def safe_member_path(name: str) -> PurePosixPath:
    path = PurePosixPath(name)
    if not name or path.is_absolute() or "\\" in name or any(part in {"..", ""} for part in name.split("/")):
        raise ArchiveError(f"unsafe path in archive: {name!r}")
    return path


def extract_bundle(bundle: Path, destination: Path) -> list[str]:
    """Extract regular files only; reject absolute paths, `..`, links and devices. Verifies the manifest."""
    destination.mkdir(parents=True, exist_ok=True)
    root = destination.resolve()
    written: dict[str, bytes] = {}
    with tarfile.open(bundle, "r:gz") as tar:
        for member in tar.getmembers():
            relative = safe_member_path(member.name)
            if not member.isreg():
                raise ArchiveError(f"unsafe member in archive (not a regular file): {member.name!r}")
            target = (root / relative).resolve()
            if root not in target.parents:
                raise ArchiveError(f"unsafe path in archive: {member.name!r}")
            handle = tar.extractfile(member)
            written[str(relative)] = handle.read() if handle else b""
    manifest_raw = written.get("manifest.json")
    if manifest_raw is None:
        raise ArchiveError("archive has no manifest.json")
    manifest = json.loads(manifest_raw)
    expected = {entry["path"]: entry for entry in manifest.get("files", [])}
    if set(written) - {"manifest.json"} != set(expected):
        raise ArchiveError("archive contents do not match its manifest")
    for path, entry in expected.items():
        if hashlib.sha256(written[path]).hexdigest() != entry["sha256"]:
            raise ArchiveError(f"manifest sha256 mismatch for {path}")
    for relative, data in written.items():
        target = root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        target.chmod(0o600)
    return sorted(written)


def parse_uri(uri: str) -> tuple[str, str, str, str]:
    """(bucket, harness, native, sha) from an archive object URI."""
    match = GCS_URI_RE.match(uri)
    found = OBJECT_RE.match(match.group(2)) if match else None
    if not match or not found:
        raise ArchiveError(f"not an agent-session archive URI: {uri!r}")
    return match.group(1), found["harness"], found["native"], found["sha"]


def fetch(uri: str, gcloud: Gcloud, out: Path | None = None) -> Path:
    """Download, verify sha256 against the content-addressed name, extract safely, return the directory."""
    _, harness, native, sha = parse_uri(uri)
    destination = out or cache_root() / harness / native / sha
    if (destination / "manifest.json").is_file() and not out:
        return destination
    ensure_auth(gcloud)
    destination.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as directory:
        local = Path(directory) / "bundle.tar.gz"
        gcloud.download(uri, local)
        digest = hashlib.sha256(local.read_bytes()).hexdigest()
        if digest != sha:
            raise ArchiveError(f"sha256 mismatch for {uri}: object is not the content it is named after; not extracted")
        extract_bundle(local, destination)
    return destination


def provision_commands(config: Mapping[str, Any]) -> list[list[str]]:
    bucket, project = bucket_name(config), config.get("project")
    command = ["gcloud", "storage", "buckets", "create", f"gs://{bucket}", f"--project={project}",
               f"--location={config.get('location', 'europe-north1')}", "--uniform-bucket-level-access", "--public-access-prevention"]
    # Soft delete stays at the default retention; objects are immutable by construction (content-addressed, --no-clobber).
    return [command]
