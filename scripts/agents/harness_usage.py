#!/usr/bin/env python3
"""Direct harness quota / usage-limit probing and headroom-based selection.

Ported from T3 Code's MIT-licensed usage-limit implementation (pingdotgg/t3code):
  - packages/shared/src/usageLimits.ts (window exhaustion & headroom model)
  - apps/server/src/provider/antigravityUsageLimits.ts
  - apps/server/src/provider/codexUsageLimits.ts
  - apps/server/src/provider/claudeUsageLimits.ts

Probes installed harnesses directly (Claude CLI, Codex app-server, Antigravity
Cloud Code quota API) with strict bounded timeouts and fail-open semantics so CI
can skip exhausted subscriptions and pick the harness with the most remaining
headroom without introducing a third-party model proxy.
"""

from __future__ import annotations

import hashlib
import json
import os
import platform
import re
import select
import shutil
import subprocess
import tempfile
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict, dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Callable, Mapping
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

DEFAULT_TIMEOUT_SECONDS = 5.0
DEFAULT_EXHAUSTION_THRESHOLD = 95.0
CACHE_SECONDS = 60
ANTIGRAVITY_RELOGIN = "Owner action: sign in again with agy."
ANTIGRAVITY_ENDPOINTS = (
    "https://daily-cloudcode-pa.googleapis.com",
    "https://cloudcode-pa.googleapis.com",
)
ANTIGRAVITY_USER_AGENT_VERSION = "2.24.0"
ANTIGRAVITY_USER_AGENT_CL = "963137146"
CLAUDE_OAUTH_USAGE_URL = "https://api.anthropic.com/api/oauth/usage"
CLAUDE_OAUTH_USER_AGENT = "claude-code/2.1.326"
SUPPORTED_PROVIDERS = ("claude", "codex", "antigravity")


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def iso_utc(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def parse_iso(value: str | None) -> datetime | None:
    if not value or not isinstance(value, str):
        return None
    raw = value.strip()
    if not raw:
        return None
    if raw.endswith("Z"):
        raw = raw[:-1] + "+00:00"
    try:
        dt = datetime.fromisoformat(raw)
    except ValueError:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _clamp(value: float, low: float = 0.0, high: float = 100.0) -> float:
    return max(low, min(high, value))


def _epoch_to_iso(value: Any) -> str | None:
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        return None
    if value <= 0:
        return None
    # Handle milliseconds vs seconds defensively.
    try:
        seconds = value / 1000.0 if value > 10_000_000_000 else float(value)
        return iso_utc(datetime.fromtimestamp(seconds, tz=timezone.utc))
    except (OverflowError, OSError, ValueError):
        return None


QUOTA_ERROR = re.compile(
    r"\b(?:usage_limit_reached|insufficient_quota|quota_exceeded|rate_limit_exceeded|"
    r"rate_limit_error|resource_exhausted|too many requests|"
    r"(?:usage|rate) limit (?:reached|exceeded)|"
    r"(?:hit|reached) your [^.\n]{0,60}\blimit\b|"
    r"quota(?: limit)? (?:has been )?(?:reached|exceeded|exhausted|will reset)|"
    r"(?:exceeded|exhausted) [^.\n]{0,30}\bquota|exhausted your capacity|"
    r"(?:http(?: error)?|(?:status|error)(?: code)?)\s*[:=]?\s*429|^429(?=[:\s]|$))\b",
    re.IGNORECASE | re.MULTILINE,
)
RESET_ISO = re.compile(
    r"\b(?:resets?(?: at| on| time)?|try again at|retry (?:at|after))\s*[:=]?\s*"
    r"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?(?:Z|[+-]\d{2}:\d{2}))",
    re.IGNORECASE,
)
RESET_CLOCK = re.compile(
    r"\bresets?\s+(?:at\s+)?(1[0-2]|0?[1-9])(?::([0-5]\d))?\s*(am|pm)\s+\(([^()]+)\)",
    re.IGNORECASE,
)
RESET_DELAY = re.compile(
    r"\b(?:reset(?:s)?\s+(?:in|after)|try again in|retry (?:in|after))\s+((?:\d+\s*[hms]\s*)+)",
    re.IGNORECASE,
)


def _reset_from_message(message: str, ref: datetime) -> datetime | None:
    if match := RESET_ISO.search(message):
        return parse_iso(match[1])
    if match := RESET_CLOCK.search(message):
        hour, minute, period, zone = match.groups()
        try:
            local = ref.astimezone(ZoneInfo(zone))
        except (ZoneInfoNotFoundError, ValueError):
            return None
        reset_hour = (int(hour) % 12) + (12 if period.lower() == "pm" else 0)
        candidate = local.replace(hour=reset_hour, minute=int(minute or 0), second=0, microsecond=0)
        return candidate if candidate > local else candidate + timedelta(days=1)
    if match := RESET_DELAY.search(message):
        try:
            units = {"h": 3600, "m": 60, "s": 1}
            seconds = sum(int(amount) * units[unit.lower()] for amount, unit in re.findall(r"(\d+)\s*([hms])", match[1], re.I))
            return ref + timedelta(seconds=seconds)
        except (ValueError, OverflowError):
            return None
    return None


def quota_error_details(error: Any, *, now: datetime | None = None) -> dict[str, str]:
    """Recognize a usage-limit diagnostic and normalize a supplied reset to UTC."""
    ref = now or utc_now()
    nodes = [(None, error)]
    exhausted = False
    resets: list[datetime] = []
    while nodes:
        key, value = nodes.pop()
        if isinstance(value, dict):
            nodes.extend((re.sub(r"[_-]", "", name).lower(), item) for name, item in value.items())
        elif isinstance(value, list):
            nodes.extend((key, item) for item in value)
        elif key in {"resetsat", "resetat", "resettime", "quotaresettime", "quotaresettimestamp"}:
            if isinstance(value, str) and value.isascii() and value.isdecimal() and len(value) <= 16:
                value = int(value)
            reset = parse_iso(value) if isinstance(value, str) else parse_iso(_epoch_to_iso(value))
            if reset is not None:
                resets.append(reset)
        elif key in {"code", "status", "statuscode", "httpstatus", "httpstatuscode"} and str(value) == "429":
            exhausted = True
        elif isinstance(value, str) and key in {
            None, "code", "status", "type", "reason", "error", "errors", "message", "result", "detail", "details", "response",
        }:
            message = re.sub(r"\bdisk quota (?:reached|exceeded|exhausted)\b", "", value, flags=re.I)
            exhausted |= bool(QUOTA_ERROR.search(message) or re.fullmatch(r"(?:error:\s*)?quota", message.strip(), re.I))
            if reset := _reset_from_message(message, ref):
                resets.append(reset)
    if not exhausted:
        return {}
    details = {"failure_kind": "quota_exhausted"}
    if resets:
        details["resets_at"] = iso_utc(min(resets))
    return details


@dataclass(frozen=True)
class UsageWindow:
    id: str
    label: str
    used_percent: float
    window_duration_mins: int | None = None
    resets_at: str | None = None
    model_id: str | None = None
    disabled: bool = False
    is_extra_usage: bool = False

    def is_reset(self, now: datetime) -> bool:
        reset_dt = parse_iso(self.resets_at)
        return reset_dt is not None and reset_dt <= now

    def remaining_percent(self, now: datetime) -> float:
        if self.disabled:
            return 0.0
        if self.is_reset(now):
            return 100.0
        return round(_clamp(100.0 - self.used_percent, 0.0, 100.0), 2)

    def is_exhausted(self, now: datetime, threshold: float = DEFAULT_EXHAUSTION_THRESHOLD) -> bool:
        if self.is_extra_usage:
            return False
        if self.disabled:
            return True
        if self.used_percent < threshold:
            return False
        return not self.is_reset(now)

    def to_dict(self, now: datetime | None = None) -> dict[str, Any]:
        ref = now or utc_now()
        payload: dict[str, Any] = {
            "id": self.id,
            "label": self.label,
            "used_percent": round(self.used_percent, 2),
            "remaining_percent": self.remaining_percent(ref),
            "exhausted": self.is_exhausted(ref),
        }
        if self.window_duration_mins is not None:
            payload["window_duration_mins"] = self.window_duration_mins
        if self.resets_at is not None:
            payload["resets_at"] = self.resets_at
        if self.model_id is not None:
            payload["model_id"] = self.model_id
        if self.disabled:
            payload["disabled"] = True
        if self.is_extra_usage:
            payload["is_extra_usage"] = True
        return payload


@dataclass(frozen=True)
class HarnessUsageSnapshot:
    provider: str
    status: str  # "ok" | "unmetered" | "unavailable" | "error"
    windows: tuple[UsageWindow, ...] = ()
    auth_mode: str = "subscription"  # "subscription" | "api_key" | "none"
    fetched_at: str = ""
    plan_type: str | None = None
    error: str | None = None

    def blocking_windows(self) -> tuple[UsageWindow, ...]:
        return tuple(w for w in self.windows if not w.is_extra_usage)

    def exhausted(self, now: datetime, threshold: float = DEFAULT_EXHAUSTION_THRESHOLD) -> bool:
        if self.status != "ok":
            return False
        return any(w.is_exhausted(now, threshold=threshold) for w in self.blocking_windows())

    def exhausted_windows(self, now: datetime, threshold: float = DEFAULT_EXHAUSTION_THRESHOLD) -> list[UsageWindow]:
        if self.status != "ok":
            return []
        return [w for w in self.blocking_windows() if w.is_exhausted(now, threshold=threshold)]

    def min_remaining_percent(self, now: datetime) -> float | None:
        if self.status == "unmetered":
            return 100.0
        if self.status != "ok":
            return None
        blocking = self.blocking_windows()
        if not blocking:
            return None
        return min(w.remaining_percent(now) for w in blocking)

    def to_dict(self, now: datetime | None = None, threshold: float = DEFAULT_EXHAUSTION_THRESHOLD) -> dict[str, Any]:
        ref = now or utc_now()
        payload: dict[str, Any] = {
            "provider": self.provider,
            "status": self.status,
            "auth_mode": self.auth_mode,
            "fetched_at": self.fetched_at or iso_utc(ref),
            "exhausted": self.exhausted(ref, threshold=threshold),
            "min_remaining_percent": self.min_remaining_percent(ref),
            "windows": [w.to_dict(ref) for w in self.windows],
        }
        if self.plan_type:
            payload["plan_type"] = self.plan_type
        if self.error:
            payload["error"] = self.error
        return payload


# ---------------------------------------------------------------------------
# Pure payload parsers (ported from pingdotgg/t3code)
# ---------------------------------------------------------------------------

def _antigravity_window_duration_mins(window_name: str | None) -> int | None:
    if not window_name:
        return None
    normalized = window_name.strip().lower()
    if normalized in {"5h", "five_hour", "session"}:
        return 300
    if normalized in {"weekly", "7d", "seven_day"}:
        return 10080
    if normalized.endswith("h") and normalized[:-1].isdigit():
        return int(normalized[:-1]) * 60
    if normalized.endswith("d") and normalized[:-1].isdigit():
        return int(normalized[:-1]) * 1440
    return None


def _is_untouched_antigravity_bucket(
    remaining_fraction: float,
    description: str | None,
    reset_time: str | None,
    duration_mins: int | None,
    now: datetime,
) -> bool:
    if remaining_fraction < 1.0 or (description and description.strip()):
        return False
    if not reset_time or duration_mins is None:
        return False
    reset_dt = parse_iso(reset_time)
    if reset_dt is None:
        return False
    expected = now + timedelta(minutes=duration_mins)
    return abs((reset_dt - expected).total_seconds()) <= 300


def _is_antigravity_3p_bucket(bucket_id: str, group_label: str) -> bool:
    bid = bucket_id.strip().lower()
    if bid == "3p" or bid.startswith("3p-"):
        return True
    glabel = group_label.strip().lower()
    return bool(glabel) and "gemini" not in glabel and ("claude" in glabel or "gpt" in glabel or "3p" in glabel)


def parse_antigravity_quota_summary(payload: Mapping[str, Any], now: datetime | None = None) -> list[UsageWindow]:
    ref = now or utc_now()
    buckets: list[dict[str, Any]] = []
    raw_groups = payload.get("groups")
    if isinstance(raw_groups, list):
        for group in raw_groups:
            if isinstance(group, dict) and isinstance(group.get("buckets"), list):
                group_label = group.get("label") or group.get("displayName") or group.get("groupId") or ""
                for bucket in group["buckets"]:
                    if isinstance(bucket, dict):
                        buckets.append({"_group_label": group_label, **bucket})
    raw_buckets = payload.get("buckets")
    if isinstance(raw_buckets, list):
        for bucket in raw_buckets:
            if isinstance(bucket, dict):
                buckets.append(bucket)

    windows: list[UsageWindow] = []
    for index, bucket in enumerate(buckets):
        bucket_id = str(bucket.get("bucketId") or bucket.get("id") or f"bucket-{index}")
        group_label = str(bucket.get("_group_label") or "").strip()
        if _is_antigravity_3p_bucket(bucket_id, group_label):
            continue
        remaining_raw = bucket.get("remainingFraction")
        disabled = bool(bucket.get("disabled", False))
        if remaining_raw is None and not disabled:
            continue
        if isinstance(remaining_raw, (int, float)) and not isinstance(remaining_raw, bool):
            remaining_fraction = max(0.0, min(1.0, float(remaining_raw)))
        else:
            remaining_fraction = 0.0 if disabled else 1.0
        used_percent = 100.0 if disabled else _clamp((1.0 - remaining_fraction) * 100.0)
        window_tag = str(bucket.get("window") or bucket.get("windowType") or "").strip()
        duration_mins = _antigravity_window_duration_mins(window_tag)
        if duration_mins is None and isinstance(bucket.get("windowDurationMins"), (int, float)):
            duration_mins = int(bucket["windowDurationMins"])
        reset_time = bucket.get("resetTime") if isinstance(bucket.get("resetTime"), str) else None
        description = bucket.get("description") if isinstance(bucket.get("description"), str) else None
        if _is_untouched_antigravity_bucket(remaining_fraction, description, reset_time, duration_mins, ref):
            reset_time = None
        label = description or (f"{group_label} ({window_tag})" if group_label and window_tag else bucket_id)
        windows.append(
            UsageWindow(
                id=bucket_id,
                label=label,
                used_percent=round(used_percent, 2),
                window_duration_mins=duration_mins,
                resets_at=reset_time,
                model_id=str(bucket.get("modelId")) if bucket.get("modelId") else None,
                disabled=disabled,
            )
        )
    return windows


def parse_antigravity_available_models(payload: Mapping[str, Any], now: datetime | None = None) -> list[UsageWindow]:
    ref = now or utc_now()
    models = payload.get("models")
    if not isinstance(models, dict):
        return []
    session_worst: tuple[float, str | None, str] | None = None
    weekly_worst: tuple[float, str | None, str] | None = None
    for model_id, info in models.items():
        if not isinstance(info, dict):
            continue
        model_provider = str(info.get("modelProvider") or "").strip().upper()
        if model_provider and model_provider != "MODEL_PROVIDER_GOOGLE":
            continue
        if not model_provider and not str(model_id).lower().startswith(("gemini-", "tab_")):
            continue
        for key, duration_mins, target in (
            ("quotaInfo", 300, "session"),
            ("weeklyQuotaInfo", 10080, "weekly"),
        ):
            q = info.get(key)
            if not isinstance(q, dict):
                continue
            rem_raw = q.get("remainingFraction")
            if not isinstance(rem_raw, (int, float)) or isinstance(rem_raw, bool):
                continue
            rem = max(0.0, min(1.0, float(rem_raw)))
            used = round(_clamp((1.0 - rem) * 100.0), 2)
            reset = q.get("resetTime") if isinstance(q.get("resetTime"), str) else None
            if _is_untouched_antigravity_bucket(rem, None, reset, duration_mins, ref):
                reset = None
            candidate = (used, reset, str(model_id))
            if target == "session":
                if session_worst is None or candidate[0] > session_worst[0]:
                    session_worst = candidate
            else:
                if weekly_worst is None or candidate[0] > weekly_worst[0]:
                    weekly_worst = candidate
    windows: list[UsageWindow] = []
    if session_worst is not None:
        windows.append(
            UsageWindow(
                id="antigravity-5h",
                label="5h session",
                used_percent=session_worst[0],
                window_duration_mins=300,
                resets_at=session_worst[1],
                model_id=session_worst[2],
            )
        )
    if weekly_worst is not None:
        windows.append(
            UsageWindow(
                id="antigravity-weekly",
                label="weekly",
                used_percent=weekly_worst[0],
                window_duration_mins=10080,
                resets_at=weekly_worst[1],
                model_id=weekly_worst[2],
            )
        )
    return windows


def parse_codex_rate_limits(payload: Mapping[str, Any]) -> tuple[list[UsageWindow], str | None]:
    result = payload.get("result") if isinstance(payload.get("result"), dict) else payload
    if not isinstance(result, Mapping):
        return [], None
    by_id = result.get("rateLimitsByLimitId")
    bucket: Mapping[str, Any] | None = None
    if isinstance(by_id, Mapping):
        if isinstance(by_id.get("codex"), Mapping):
            bucket = by_id["codex"]
        else:
            for val in by_id.values():
                if isinstance(val, Mapping):
                    bucket = val
                    break
    if bucket is None and isinstance(result.get("rateLimits"), Mapping):
        bucket = result["rateLimits"]
    if bucket is None:
        return [], None

    plan_type = str(bucket.get("planType") or result.get("planType") or "").strip() or None
    windows: list[UsageWindow] = []
    for key, default_label in (("primary", "5h session"), ("secondary", "weekly")):
        win = bucket.get(key)
        if not isinstance(win, Mapping):
            continue
        used_raw = win.get("usedPercent")
        if not isinstance(used_raw, (int, float)) or isinstance(used_raw, bool):
            continue
        duration_raw = win.get("windowDurationMins")
        duration = int(duration_raw) if isinstance(duration_raw, (int, float)) and not isinstance(duration_raw, bool) else None
        label = "monthly" if key == "primary" and (plan_type or "").lower() in {"free", "go"} else default_label
        resets_at = _epoch_to_iso(win.get("resetsAt"))
        windows.append(
            UsageWindow(
                id=f"codex-{key}",
                label=label,
                used_percent=round(_clamp(float(used_raw)), 2),
                window_duration_mins=duration,
                resets_at=resets_at,
            )
        )

    individual = bucket.get("individualLimit") or result.get("individualLimit")
    if isinstance(individual, Mapping):
        rem_raw = individual.get("remainingPercent")
        if isinstance(rem_raw, (int, float)) and not isinstance(rem_raw, bool):
            windows.append(
                UsageWindow(
                    id="codex-individual",
                    label="individual limit",
                    used_percent=round(_clamp(100.0 - float(rem_raw)), 2),
                    resets_at=_epoch_to_iso(individual.get("resetsAt")),
                )
            )
    return windows, plan_type


def parse_claude_usage(payload: Mapping[str, Any]) -> list[UsageWindow]:
    # Unwrap control_response -> response -> response / usage / rate_limits.
    data: Mapping[str, Any] = payload
    if isinstance(data.get("response"), Mapping):
        inner = data["response"]
        if isinstance(inner.get("response"), Mapping):
            data = inner["response"]
        else:
            data = inner
    if isinstance(data.get("usage"), Mapping):
        data = data["usage"]
    rate_limits = data.get("rate_limits") if isinstance(data.get("rate_limits"), Mapping) else data

    windows: list[UsageWindow] = []
    known: tuple[tuple[str, str, int | None, str | None], ...] = (
        ("five_hour", "5h session", 300, None),
        ("seven_day", "weekly", 10080, None),
        ("seven_day_sonnet", "weekly (sonnet)", 10080, "sonnet"),
        ("seven_day_opus", "weekly (opus)", 10080, "opus"),
        ("seven_day_oauth_apps", "weekly (oauth)", 10080, None),
    )
    seen: set[str] = set()
    for key, label, duration, model_id in known:
        item = rate_limits.get(key)
        if not isinstance(item, Mapping):
            continue
        util = item.get("utilization")
        if not isinstance(util, (int, float)) or isinstance(util, bool):
            continue
        seen.add(key)
        resets_at = item.get("resets_at") if isinstance(item.get("resets_at"), str) else None
        windows.append(
            UsageWindow(
                id=f"claude-{key}",
                label=label,
                used_percent=round(_clamp(float(util)), 2),
                window_duration_mins=duration,
                resets_at=resets_at,
                model_id=model_id,
            )
        )

    # Capture any additional model-scoped seven_day_* buckets without duplicating known ones.
    for key, item in rate_limits.items():
        if key in seen or not key.startswith("seven_day_") or not isinstance(item, Mapping):
            continue
        util = item.get("utilization")
        if not isinstance(util, (int, float)) or isinstance(util, bool):
            continue
        model_suffix = key[len("seven_day_"):]
        resets_at = item.get("resets_at") if isinstance(item.get("resets_at"), str) else None
        windows.append(
            UsageWindow(
                id=f"claude-{key}",
                label=f"weekly ({model_suffix})",
                used_percent=round(_clamp(float(util)), 2),
                window_duration_mins=10080,
                resets_at=resets_at,
                model_id=model_suffix,
            )
        )

    extra = data.get("extra_usage") or rate_limits.get("extra_usage")
    if isinstance(extra, Mapping) and extra.get("is_enabled"):
        util = extra.get("utilization")
        if isinstance(util, (int, float)) and not isinstance(util, bool):
            windows.append(
                UsageWindow(
                    id="claude-extra-usage",
                    label="extra usage",
                    used_percent=round(_clamp(float(util)), 2),
                    is_extra_usage=True,
                )
            )
    return windows


# ---------------------------------------------------------------------------
# Live direct harness probes (bounded timeout, fail-open)
# ---------------------------------------------------------------------------

def _antigravity_user_agent() -> str:
    sys_name = platform.system().lower()
    os_type = {"darwin": "darwin", "windows": "win32"}.get(sys_name, "linux")
    machine = platform.machine().lower()
    arch = {"x86_64": "x64", "amd64": "x64", "aarch64": "arm64", "arm64": "arm64"}.get(machine, machine or "x64")
    return (
        f"antigravity/hub/{ANTIGRAVITY_USER_AGENT_VERSION} "
        f"(aidev_client; os_type={os_type}; arch={arch}; cl={ANTIGRAVITY_USER_AGENT_CL})"
    )


def _default_antigravity_token_path(env: Mapping[str, str]) -> Path:
    override = env.get("ANTIGRAVITY_OAUTH_TOKEN_FILE", "").strip()
    if override:
        return Path(override).expanduser()
    home = Path(env.get("HOME") or Path.home())
    return home / ".gemini" / "antigravity-cli" / "antigravity-oauth-token"


def _post_json(url: str, token: str, payload: dict[str, Any], timeout: float) -> dict[str, Any]:
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "User-Agent": _antigravity_user_agent(),
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=timeout) as response:
        raw = response.read(512 * 1024).decode("utf-8", errors="replace")
    parsed = json.loads(raw)
    if not isinstance(parsed, dict):
        raise ValueError("expected JSON object from quota API")
    return parsed


def probe_antigravity(
    *,
    timeout: float = DEFAULT_TIMEOUT_SECONDS,
    token_path: Path | None = None,
    env: Mapping[str, str] | None = None,
    now: datetime | None = None,
    http_post: Callable[[str, str, dict[str, Any], float], dict[str, Any]] = _post_json,
) -> HarnessUsageSnapshot:
    ref = now or utc_now()
    environ = os.environ if env is None else env
    path = token_path or _default_antigravity_token_path(environ)
    if not path.is_file():
        if environ.get("GEMINI_API_KEY", "").strip():
            return HarnessUsageSnapshot(
                provider="antigravity",
                status="unmetered",
                auth_mode="api_key",
                fetched_at=iso_utc(ref),
            )
        return HarnessUsageSnapshot(
            provider="antigravity",
            status="unavailable",
            auth_mode="none",
            fetched_at=iso_utc(ref),
            error="antigravity OAuth token file not found",
        )
    access_token = _antigravity_access_token(path)
    if not access_token:
        return HarnessUsageSnapshot("antigravity", "error", fetched_at=iso_utc(ref), error=ANTIGRAVITY_RELOGIN)

    deadline = time.monotonic() + timeout
    windows, auth_rejected, error = _antigravity_windows(http_post, access_token, deadline, ref)
    if not windows and auth_rejected and path == _default_antigravity_token_path({**environ, "ANTIGRAVITY_OAUTH_TOKEN_FILE": ""}):
        # The native CLI owns OAuth refresh. Its model listing does not start an agent run.
        binary = shutil.which("agy", path=environ.get("PATH"))
        if binary:
            try:
                subprocess.run(
                    [binary, "models"], env=dict(environ), stdin=subprocess.DEVNULL,
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=timeout, check=True,
                )
            except (OSError, subprocess.SubprocessError):
                pass
            refreshed = _antigravity_access_token(path)
            if refreshed and refreshed != access_token:
                windows, auth_rejected, error = _antigravity_windows(
                    http_post, refreshed, time.monotonic() + timeout, ref,
                )
    if windows:
        return HarnessUsageSnapshot("antigravity", "ok", tuple(windows), fetched_at=iso_utc(ref))
    return HarnessUsageSnapshot(
        "antigravity", "error", fetched_at=iso_utc(ref),
        error=ANTIGRAVITY_RELOGIN if auth_rejected else error,
    )


def _antigravity_access_token(path: Path) -> str:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return ""
    if not isinstance(data, dict):
        return ""
    token = data.get("token", data)
    value = token.get("access_token") if isinstance(token, dict) else None
    return value.strip() if isinstance(value, str) else ""


def _antigravity_windows(
    http_post: Callable[[str, str, dict[str, Any], float], dict[str, Any]],
    token: str,
    deadline: float,
    now: datetime,
) -> tuple[list[UsageWindow], bool, str]:
    auth_rejected = False
    error = "Antigravity returned no quota windows."
    for endpoint in ANTIGRAVITY_ENDPOINTS:
        for method, parse in (
            ("retrieveUserQuotaSummary", parse_antigravity_quota_summary),
            ("fetchAvailableModels", parse_antigravity_available_models),
        ):
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                return [], auth_rejected, "Antigravity quota probe timed out."
            try:
                windows = parse(http_post(f"{endpoint}/v1internal:{method}", token, {}, remaining), now=now)
            except urllib.error.HTTPError as exc:
                error = f"Antigravity quota probe returned HTTP {exc.code}."
                auth_rejected |= exc.code in {401, 403}
                exc.close()
                if exc.code == 401:
                    return [], True, error
            except (OSError, ValueError):
                error = "Antigravity quota probe could not read quota."
            else:
                if windows:
                    return windows, False, ""
    return [], auth_rejected, error


def _read_json_rpc_response(
    proc: subprocess.Popen[str],
    matcher: Callable[[dict[str, Any]], bool],
    timeout: float,
) -> dict[str, Any] | None:
    deadline = time.monotonic() + timeout
    stdout = proc.stdout
    if stdout is None:
        return None
    fd = stdout.fileno()
    buf = ""
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return None
        ready, _, _ = select.select([fd], [], [], min(0.25, remaining))
        if not ready:
            if proc.poll() is not None:
                return None
            continue
        chunk = os.read(fd, 65536)
        if not chunk:
            return None
        buf += chunk.decode("utf-8", errors="replace")
        while "\n" in buf:
            line, buf = buf.split("\n", 1)
            line = line.strip()
            if not line or not line.startswith("{"):
                continue
            try:
                obj = json.loads(line)
            except ValueError:
                continue
            if isinstance(obj, dict) and matcher(obj):
                return obj


def _terminate_quietly(proc: subprocess.Popen[str]) -> None:
    for stream in (proc.stdin, proc.stdout, proc.stderr):
        if stream is not None:
            try:
                stream.close()
            except OSError:
                pass
    try:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=1.0)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=1.0)
    except OSError:
        pass


def probe_codex(
    *,
    timeout: float = DEFAULT_TIMEOUT_SECONDS,
    command: str = "codex",
    env: Mapping[str, str] | None = None,
    now: datetime | None = None,
) -> HarnessUsageSnapshot:
    ref = now or utc_now()
    environ = dict(os.environ if env is None else env)
    binary = shutil.which(command, path=environ.get("PATH"))
    if not binary:
        return HarnessUsageSnapshot(
            provider="codex",
            status="unavailable",
            auth_mode="none",
            fetched_at=iso_utc(ref),
            error=f"{command} binary not on PATH",
        )
    home = Path(environ.get("HOME") or Path.home())
    codex_auth = Path(environ.get("CODEX_HOME") or home / ".codex").expanduser() / "auth.json"
    if not codex_auth.is_file() and any(environ.get(key, "").strip() for key in ("OPENAI_API_KEY", "CODEX_API_KEY")):
        return HarnessUsageSnapshot(
            provider="codex",
            status="unmetered",
            auth_mode="api_key",
            fetched_at=iso_utc(ref),
        )

    proc: subprocess.Popen[str] | None = None
    try:
        proc = subprocess.Popen(
            [binary, "app-server"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=environ,
        )
        assert proc.stdin is not None
        init_req = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {"clientInfo": {"name": "foodsavr-agentctl", "version": "1.0.0"}, "capabilities": {}},
        }
        rate_req = {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "account/rateLimits/read",
            "params": {},
        }
        proc.stdin.write(json.dumps(init_req) + "\n" + json.dumps(rate_req) + "\n")
        proc.stdin.flush()
        response = _read_json_rpc_response(proc, lambda obj: obj.get("id") == 2, timeout)
    except OSError as exc:
        return HarnessUsageSnapshot(
            provider="codex",
            status="error",
            auth_mode="subscription",
            fetched_at=iso_utc(ref),
            error=f"failed to start codex app-server: {exc}",
        )
    finally:
        if proc is not None:
            _terminate_quietly(proc)

    if response is None:
        return HarnessUsageSnapshot(
            provider="codex",
            status="error",
            auth_mode="subscription",
            fetched_at=iso_utc(ref),
            error="timed out waiting for codex account/rateLimits/read",
        )
    if "error" in response:
        return HarnessUsageSnapshot(
            provider="codex",
            status="error",
            auth_mode="subscription",
            fetched_at=iso_utc(ref),
            error="Codex rejected the usage request.",
        )
    windows, plan_type = parse_codex_rate_limits(response)
    if not windows:
        return HarnessUsageSnapshot(
            provider="codex",
            status="error",
            auth_mode="subscription",
            fetched_at=iso_utc(ref),
            plan_type=plan_type,
            error="codex returned no rate-limit windows",
        )
    return HarnessUsageSnapshot(
        provider="codex",
        status="ok",
        windows=tuple(windows),
        auth_mode="subscription",
        fetched_at=iso_utc(ref),
        plan_type=plan_type,
    )


def _get_claude_oauth_usage(url: str, token: str, timeout: float) -> dict[str, Any]:
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "User-Agent": CLAUDE_OAUTH_USER_AGENT,
            "anthropic-beta": "oauth-2025-04-20",
        },
        method="GET",
    )
    with urllib.request.urlopen(req, timeout=timeout) as response:
        raw = response.read(512 * 1024).decode("utf-8", errors="replace")
    parsed = json.loads(raw)
    if not isinstance(parsed, dict):
        raise ValueError("expected JSON object from Claude OAuth usage API")
    return parsed


def _read_claude_oauth_token(environ: Mapping[str, str]) -> str | None:
    env_token = environ.get("CLAUDE_CODE_OAUTH_TOKEN", "").strip()
    if env_token:
        return env_token
    home = Path(environ.get("HOME") or Path.home())
    config = Path(environ.get("CLAUDE_CONFIG_DIR") or home / ".claude").expanduser()
    creds_path = config / ".credentials.json"
    if not creds_path.is_file():
        return None
    try:
        parsed = json.loads(creds_path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    if isinstance(parsed, Mapping):
        oauth = parsed.get("claudeAiOauth")
        if isinstance(oauth, Mapping):
            tok = oauth.get("accessToken")
            if isinstance(tok, str) and tok.strip():
                return tok.strip()
    return None


def probe_claude(
    *,
    timeout: float = DEFAULT_TIMEOUT_SECONDS,
    command: str = "claude",
    env: Mapping[str, str] | None = None,
    now: datetime | None = None,
    http_get: Callable[[str, str, float], dict[str, Any]] | None = None,
) -> HarnessUsageSnapshot:
    ref = now or utc_now()
    environ = dict(os.environ if env is None else env)
    binary = shutil.which(command, path=environ.get("PATH"))
    if not binary:
        return HarnessUsageSnapshot(
            provider="claude",
            status="unavailable",
            auth_mode="none",
            fetched_at=iso_utc(ref),
            error=f"{command} binary not on PATH",
        )
    if environ.get("ANTHROPIC_API_KEY", "").strip() and not environ.get("CLAUDE_CODE_OAUTH_TOKEN", "").strip():
        home = Path(environ.get("HOME") or Path.home())
        config = Path(environ.get("CLAUDE_CONFIG_DIR") or home / ".claude").expanduser()
        if not (config / ".credentials.json").is_file():
            return HarnessUsageSnapshot(
                provider="claude",
                status="unmetered",
                auth_mode="api_key",
                fetched_at=iso_utc(ref),
            )

    proc: subprocess.Popen[str] | None = None
    response: dict[str, Any] | None = None
    cli_error: str | None = None
    try:
        proc = subprocess.Popen(
            [binary, "--input-format", "stream-json", "--output-format", "stream-json", "--verbose"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=environ,
        )
        assert proc.stdin is not None
        req = {
            "type": "control_request",
            "request_id": "1",
            "request": {"subtype": "get_usage"},
        }
        proc.stdin.write(json.dumps(req) + "\n")
        proc.stdin.flush()
        response = _read_json_rpc_response(
            proc,
            lambda obj: (
                obj.get("type") == "control_response"
                and isinstance(obj.get("response"), dict)
                and obj["response"].get("request_id") == "1"
            ),
            timeout,
        )
    except OSError as exc:
        cli_error = f"failed to start claude stream-json control probe: {exc}"
    finally:
        if proc is not None:
            _terminate_quietly(proc)

    windows: list[UsageWindow] = []
    if response is not None:
        resp_body = response.get("response", {})
        if isinstance(resp_body, dict) and resp_body.get("subtype") == "error":
            cli_error = "Claude rejected the usage request."
        else:
            windows = parse_claude_usage(response)
            if not windows:
                cli_error = "claude returned no usage windows"
    elif cli_error is None:
        cli_error = "timed out waiting for claude get_usage control_response"

    if not windows:
        # When authenticated solely via CLAUDE_CODE_OAUTH_TOKEN (without ~/.claude/.credentials.json),
        # Claude CLI's stream-json `get_usage` returns `rate_limits_available: false`. Fall back to
        # the direct OAuth usage endpoint using the configured OAuth token.
        oauth_token = _read_claude_oauth_token(environ)
        if oauth_token:
            getter = http_get or _get_claude_oauth_usage
            try:
                oauth_payload = getter(CLAUDE_OAUTH_USAGE_URL, oauth_token, timeout)
                windows = parse_claude_usage(oauth_payload)
            except (urllib.error.URLError, OSError, ValueError) as exc:
                cli_error = f"{cli_error or 'claude get_usage failed'}; OAuth usage endpoint failed: {exc}"

    if not windows:
        return HarnessUsageSnapshot(
            provider="claude",
            status="error",
            auth_mode="subscription",
            fetched_at=iso_utc(ref),
            error=cli_error or "claude returned no usage windows",
        )
    return HarnessUsageSnapshot(
        provider="claude",
        status="ok",
        windows=tuple(windows),
        auth_mode="subscription",
        fetched_at=iso_utc(ref),
    )


def probe_provider(
    provider: str,
    *,
    timeout: float = DEFAULT_TIMEOUT_SECONDS,
    env: Mapping[str, str] | None = None,
    now: datetime | None = None,
) -> HarnessUsageSnapshot:
    ref = now or utc_now()
    if provider == "claude":
        return probe_claude(timeout=timeout, env=env, now=ref)
    if provider == "codex":
        return probe_codex(timeout=timeout, env=env, now=ref)
    if provider == "antigravity":
        return probe_antigravity(timeout=timeout, env=env, now=ref)
    return HarnessUsageSnapshot(
        provider=provider,
        status="unavailable",
        auth_mode="none",
        fetched_at=iso_utc(ref),
        error=f"quota probing not supported for provider {provider!r}",
    )


def _quota_cache_key(provider: str, env: Mapping[str, str]) -> str:
    home = Path(env.get("HOME") or Path.home())
    codex_home = Path(env.get("CODEX_HOME") or home / ".codex").expanduser()
    claude_home = Path(env.get("CLAUDE_CONFIG_DIR") or home / ".claude").expanduser()
    files, keys = {
        "claude": ([claude_home / ".credentials.json"], ["CLAUDE_CODE_OAUTH_TOKEN", "ANTHROPIC_API_KEY"]),
        "codex": ([codex_home / "auth.json"], ["CODEX_API_KEY", "OPENAI_API_KEY"]),
        "antigravity": ([_default_antigravity_token_path(env)], ["GEMINI_API_KEY"]),
    }[provider]
    identity: list[Any] = [provider, str(home), env.get("PATH")]
    identity.extend(env.get(key) for key in keys)
    for path in files:
        identity.append(str(path))
        try:
            stat = path.stat()
            identity.append([stat.st_dev, stat.st_ino, stat.st_mtime_ns, stat.st_size])
        except OSError:
            pass
    return hashlib.sha256(json.dumps(identity).encode()).hexdigest()


def invalidate_quota_cache(cache_dir: Path, provider: str) -> None:
    """Discard a probe that has been contradicted by a live usage-limit error."""
    if provider in SUPPORTED_PROVIDERS:
        try:
            (cache_dir / f"{provider}.json").unlink(missing_ok=True)
        except OSError:
            # Routing still excludes the provider for the current run.
            pass


def earliest_quota_reset(
    candidates: list[str], snapshots: Mapping[str, HarnessUsageSnapshot], *, now: datetime | None = None,
) -> str | None:
    ref = now or utc_now()
    resets = [
        reset
        for name in candidates if name in snapshots
        for window in snapshots[name].exhausted_windows(ref)
        if (reset := parse_iso(window.resets_at)) is not None
    ]
    return iso_utc(min(resets)) if resets else None


def probe_all(
    providers: list[str] | tuple[str, ...] = SUPPORTED_PROVIDERS,
    *,
    timeout: float = DEFAULT_TIMEOUT_SECONDS,
    env: Mapping[str, str] | None = None,
    now: datetime | None = None,
    cache_dir: Path | None = None,
) -> dict[str, HarnessUsageSnapshot]:
    ref = now or utc_now()
    environ = os.environ if env is None else env

    def probe(provider: str) -> HarnessUsageSnapshot:
        if cache_dir is None or provider not in SUPPORTED_PROVIDERS:
            return probe_provider(provider, timeout=timeout, env=environ, now=ref)
        cache_path = cache_dir / f"{provider}.json"
        cache_key = _quota_cache_key(provider, environ)
        try:
            data = json.loads(cache_path.read_text(encoding="utf-8"))
            if data["key"] == cache_key and 0 <= ref.timestamp() - data["checked_at"] < CACHE_SECONDS:
                cached = data["snapshot"]
                cached["windows"] = tuple(UsageWindow(**window) for window in cached["windows"])
                return HarnessUsageSnapshot(**cached)
        except (OSError, ValueError, KeyError, TypeError):
            pass
        result = probe_provider(provider, timeout=timeout, env=environ, now=ref)
        # Refresh can replace a credential during the probe. Persist only normalized quota data.
        data = {"key": _quota_cache_key(provider, environ), "checked_at": ref.timestamp(), "snapshot": asdict(result)}
        try:
            cache_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=cache_dir, delete=False) as temp:
                temporary = Path(temp.name)
                try:
                    json.dump(data, temp)
                    temp.close()
                    temporary.replace(cache_path)
                finally:
                    temporary.unlink(missing_ok=True)
        except OSError:
            pass
        return result

    names = list(dict.fromkeys(providers))
    with ThreadPoolExecutor(max_workers=len(SUPPORTED_PROVIDERS)) as executor:
        return dict(zip(names, executor.map(probe, names)))


# ---------------------------------------------------------------------------
# Headroom-based ranking & selection
# ---------------------------------------------------------------------------

def rank_providers_by_quota(
    candidates: list[str],
    snapshots: Mapping[str, HarnessUsageSnapshot],
    *,
    threshold: float = DEFAULT_EXHAUSTION_THRESHOLD,
    now: datetime | None = None,
) -> tuple[list[str], dict[str, Any]]:
    """Filter out quota-exhausted harnesses and rank remaining ones by headroom.

    Ordering tiers (fail-open):
      0. Verified subscription headroom (`status == "ok"`, not exhausted),
         sorted by descending `min_remaining_percent`, tie-breaking by original
         candidate order.
      1. Unmetered (`status == "unmetered"`, e.g. API key), original order.
      2. Unknown / probe error (`status in {"unavailable", "error"}` or absent),
         original order — preserves deterministic fallback when probes fail.
    """
    ref = now or utc_now()
    scored: list[tuple[int, float, int, str]] = []
    skipped: dict[str, str] = {}
    headroom: dict[str, float | None] = {}
    has_live_quota = False

    for index, provider in enumerate(candidates):
        snap = snapshots.get(provider)
        if snap is None:
            scored.append((2, 0.0, index, provider))
            headroom[provider] = None
            continue
        if snap.exhausted(ref, threshold=threshold):
            worst = snap.exhausted_windows(ref, threshold=threshold)
            detail = ", ".join(f"{w.label}={w.used_percent:.0f}%" for w in worst)
            skipped[provider] = f"exhausted ({detail})"
            headroom[provider] = 0.0
            continue
        rem = snap.min_remaining_percent(ref)
        headroom[provider] = rem
        if snap.status == "ok" and rem is not None:
            has_live_quota = True
            scored.append((0, -rem, index, provider))
        elif snap.status == "unmetered":
            scored.append((1, -100.0, index, provider))
        else:
            scored.append((2, 0.0, index, provider))

    scored.sort(key=lambda item: (item[0], item[1], item[2]))
    eligible = [item[3] for item in scored]
    meta = {
        "eligible": eligible,
        "skipped": skipped,
        "headroom": headroom,
        "has_live_quota": has_live_quota,
        "all_exhausted": bool(candidates) and not eligible and len(skipped) == len(candidates),
        "threshold": threshold,
    }
    return eligible, meta


def render_usage_table(
    snapshots: Mapping[str, HarnessUsageSnapshot],
    *,
    now: datetime | None = None,
    threshold: float = DEFAULT_EXHAUSTION_THRESHOLD,
) -> str:
    ref = now or utc_now()
    rows = [("PROVIDER", "STATUS", "AUTH", "HEADROOM", "EXHAUSTED", "WINDOWS / DETAIL")]
    for provider, snap in snapshots.items():
        rem = snap.min_remaining_percent(ref)
        headroom_str = f"{rem:.0f}%" if rem is not None else "-"
        exhausted_str = "yes" if snap.exhausted(ref, threshold=threshold) else "no"
        if snap.windows:
            detail = ", ".join(
                f"{w.label}:{w.used_percent:.0f}%used" + (f"(reset {w.resets_at})" if w.resets_at else "")
                for w in snap.windows
            )
        else:
            detail = snap.error or snap.auth_mode
        rows.append((provider, snap.status, snap.auth_mode, headroom_str, exhausted_str, detail))
    widths = [max(len(r[i]) for r in rows) for i in range(len(rows[0]) - 1)]
    lines = []
    for row in rows:
        prefix = "  ".join(row[i].ljust(widths[i]) for i in range(len(widths)))
        lines.append(f"{prefix}  {row[-1]}")
    return "\n".join(lines)
