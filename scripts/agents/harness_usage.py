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

import json
import os
import platform
import select
import shutil
import subprocess
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Callable, Mapping

DEFAULT_TIMEOUT_SECONDS = 5.0
DEFAULT_EXHAUSTION_THRESHOLD = 95.0
ANTIGRAVITY_ENDPOINTS = (
    "https://daily-cloudcode-pa.googleapis.com",
    "https://cloudcode-pa.googleapis.com",
)
ANTIGRAVITY_USER_AGENT_VERSION = "2.24.0"
ANTIGRAVITY_USER_AGENT_CL = "963137146"
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
    seconds = value / 1000.0 if value > 10_000_000_000 else float(value)
    try:
        return iso_utc(datetime.fromtimestamp(seconds, tz=timezone.utc))
    except (OverflowError, OSError, ValueError):
        return None


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


def parse_antigravity_quota_summary(payload: Mapping[str, Any], now: datetime | None = None) -> list[UsageWindow]:
    ref = now or utc_now()
    buckets: list[dict[str, Any]] = []
    raw_groups = payload.get("groups")
    if isinstance(raw_groups, list):
        for group in raw_groups:
            if isinstance(group, dict) and isinstance(group.get("buckets"), list):
                group_label = group.get("label") or group.get("groupId") or ""
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
        bucket_id = str(bucket.get("bucketId") or bucket.get("id") or f"bucket-{index}")
        group_label = str(bucket.get("_group_label") or "").strip()
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
    try:
        token_data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        return HarnessUsageSnapshot(
            provider="antigravity",
            status="error",
            auth_mode="subscription",
            fetched_at=iso_utc(ref),
            error=f"failed to parse antigravity token file: {exc}",
        )
    access_token = ""
    if isinstance(token_data, dict):
        if isinstance(token_data.get("access_token"), str):
            access_token = token_data["access_token"].strip()
        elif isinstance(token_data.get("token"), dict) and isinstance(token_data["token"].get("access_token"), str):
            access_token = token_data["token"]["access_token"].strip()
    if not access_token:
        return HarnessUsageSnapshot(
            provider="antigravity",
            status="error",
            auth_mode="subscription",
            fetched_at=iso_utc(ref),
            error="antigravity token file missing access_token",
        )

    last_error = "no endpoints tried"
    per_call_timeout = max(1.0, min(timeout, 10.0))
    for endpoint in ANTIGRAVITY_ENDPOINTS:
        try:
            summary_payload = http_post(f"{endpoint}/v1internal:retrieveUserQuotaSummary", access_token, {}, per_call_timeout)
            windows = parse_antigravity_quota_summary(summary_payload, now=ref)
            if windows:
                return HarnessUsageSnapshot(
                    provider="antigravity",
                    status="ok",
                    windows=tuple(windows),
                    auth_mode="subscription",
                    fetched_at=iso_utc(ref),
                )
        except (OSError, ValueError, urllib.error.URLError) as exc:
            last_error = str(exc)
        try:
            models_payload = http_post(f"{endpoint}/v1internal:fetchAvailableModels", access_token, {}, per_call_timeout)
            windows = parse_antigravity_available_models(models_payload, now=ref)
            if windows:
                return HarnessUsageSnapshot(
                    provider="antigravity",
                    status="ok",
                    windows=tuple(windows),
                    auth_mode="subscription",
                    fetched_at=iso_utc(ref),
                )
        except (OSError, ValueError, urllib.error.URLError) as exc:
            last_error = str(exc)

    return HarnessUsageSnapshot(
        provider="antigravity",
        status="error",
        auth_mode="subscription",
        fetched_at=iso_utc(ref),
        error=f"antigravity quota probe failed: {last_error}",
    )


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
    codex_auth = home / ".codex" / "auth.json"
    if not codex_auth.is_file() and environ.get("OPENAI_API_KEY", "").strip():
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
        err = response["error"]
        msg = err.get("message", str(err)) if isinstance(err, dict) else str(err)
        return HarnessUsageSnapshot(
            provider="codex",
            status="error",
            auth_mode="subscription",
            fetched_at=iso_utc(ref),
            error=f"codex rateLimits error: {msg}",
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


def probe_claude(
    *,
    timeout: float = DEFAULT_TIMEOUT_SECONDS,
    command: str = "claude",
    env: Mapping[str, str] | None = None,
    now: datetime | None = None,
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
        if not (home / ".claude" / ".credentials.json").is_file():
            return HarnessUsageSnapshot(
                provider="claude",
                status="unmetered",
                auth_mode="api_key",
                fetched_at=iso_utc(ref),
            )

    proc: subprocess.Popen[str] | None = None
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
        return HarnessUsageSnapshot(
            provider="claude",
            status="error",
            auth_mode="subscription",
            fetched_at=iso_utc(ref),
            error=f"failed to start claude stream-json control probe: {exc}",
        )
    finally:
        if proc is not None:
            _terminate_quietly(proc)

    if response is None:
        return HarnessUsageSnapshot(
            provider="claude",
            status="error",
            auth_mode="subscription",
            fetched_at=iso_utc(ref),
            error="timed out waiting for claude get_usage control_response",
        )
    resp_body = response.get("response", {})
    if isinstance(resp_body, dict) and resp_body.get("subtype") == "error":
        return HarnessUsageSnapshot(
            provider="claude",
            status="error",
            auth_mode="subscription",
            fetched_at=iso_utc(ref),
            error=f"claude get_usage error: {resp_body.get('error', 'unknown')}",
        )
    windows = parse_claude_usage(response)
    if not windows:
        return HarnessUsageSnapshot(
            provider="claude",
            status="error",
            auth_mode="subscription",
            fetched_at=iso_utc(ref),
            error="claude returned no usage windows",
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


def probe_all(
    providers: list[str] | tuple[str, ...] = SUPPORTED_PROVIDERS,
    *,
    timeout: float = DEFAULT_TIMEOUT_SECONDS,
    env: Mapping[str, str] | None = None,
    now: datetime | None = None,
) -> dict[str, HarnessUsageSnapshot]:
    ref = now or utc_now()
    return {
        provider: probe_provider(provider, timeout=timeout, env=env, now=ref)
        for provider in dict.fromkeys(providers)
    }


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
