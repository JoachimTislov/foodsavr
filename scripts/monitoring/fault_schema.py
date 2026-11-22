#!/usr/bin/env python3
"""Canonical FaultEvent schema, normalization, classification, and quarantine.

Normalizes monitoring payloads from built-in Playwright probes, Firebase Spark
Firestore runtime_errors, Firebase Blaze Cloud Logging firebase-telemetry, and
external webhook/push services (PostHog, Checkly, Grafana Faro, Sentry,
GlitchTip, Better Stack) into one versioned FaultEvent contract.
"""

from __future__ import annotations

import hashlib
import re
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from typing import Any

SCHEMA_VERSION = 1

CATEGORIES = ("code_fault", "quota_capacity", "infrastructure")

_CONTROL_CHARS_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")
_HTML_COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)
_MULTI_NEWLINE_RE = re.compile(r"\n{3,}")
_WHITESPACE_RE = re.compile(r"\s+")

# Volatile noise stripped during deterministic fingerprinting.
_UUID_RE = re.compile(
    r"\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b",
    re.IGNORECASE,
)
_HEX_ADDR_RE = re.compile(r"\b0x[0-9a-f]+\b", re.IGNORECASE)
_ISO_TS_RE = re.compile(
    r"\b\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?\b",
    re.IGNORECASE,
)
_URL_QUERY_RE = re.compile(r"\?[^\s)\"'>]+")
_LINE_COL_RE = re.compile(r":\d+(?::\d+)?")
_ORIGIN_RE = re.compile(r"https?://[^/\s)\"'>]+")

_QUOTA_PATTERNS = (
    "resource_exhausted",
    "quota exceeded",
    "exceeded quota",
    "rate limit",
    "too many requests",
    "daily limit",
    "billing",
    "spark plan",
    "storage limit",
    "bandwidth limit",
    "free tier limit",
    "insufficient quota",
    "write stream exhausted",
    "capacity exhausted",
)

_INFRA_PATTERNS = (
    "502 bad gateway",
    "503 service unavailable",
    "504 gateway timeout",
    "econnrefused",
    "enotfound",
    "etimedout",
    "eai_again",
    "err_name_not_resolved",
    "err_connection_timed_out",
    "upstream connect error",
    "tls handshake",
    "dns resolution",
    "service unavailable",
    "bad gateway",
    "gateway timeout",
)


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def sanitize_text(value: Any, max_len: int = 500) -> str:
    """Quarantine untrusted telemetry text against prompt and markdown injection."""
    if value is None:
        return ""
    text = str(value)
    text = _HTML_COMMENT_RE.sub(" ", text)
    text = _CONTROL_CHARS_RE.sub(" ", text)
    text = text.replace("```", "'''").replace("~~~", "---")
    text = _MULTI_NEWLINE_RE.sub("\n\n", text)
    text = text.strip()
    if len(text) > max_len:
        if max_len <= 3:
            return text[:max_len]
        return text[: max_len - 3].rstrip() + "..."
    return text


def sanitize_url(value: Any, max_len: int = 300) -> str:
    """Sanitize untrusted URLs, allowing only http(s) URLs or root-relative paths."""
    raw = sanitize_text(value, max_len=max_len)
    if not raw:
        return ""
    first_line = raw.splitlines()[0].strip()
    lower = first_line.lower()
    if lower.startswith("https://") or lower.startswith("http://") or first_line.startswith("/"):
        return first_line[:max_len]
    return "[redacted-non-http-url]"


def sanitize_stack_frames(
    frames: Any,
    max_frames: int = 12,
    max_frame_len: int = 240,
) -> list[str]:
    """Normalize and truncate stack frames."""
    if frames is None:
        return []
    raw_items: list[str]
    if isinstance(frames, str):
        raw_items = [line for line in frames.splitlines() if line.strip()]
    elif isinstance(frames, list):
        raw_items = []
        for item in frames:
            if isinstance(item, dict):
                fn = item.get("function") or item.get("filename") or ""
                file_path = item.get("filename") or item.get("abs_path") or ""
                lineno = item.get("lineno")
                if file_path and lineno is not None:
                    raw_items.append(f"{fn} ({file_path}:{lineno})".strip())
                elif fn or file_path:
                    raw_items.append(f"{fn} {file_path}".strip())
            elif item is not None:
                text = str(item).strip()
                if text:
                    raw_items.append(text)
    else:
        return []

    cleaned: list[str] = []
    for item in raw_items[:max_frames]:
        sanitized = sanitize_text(item, max_len=max_frame_len)
        if sanitized:
            cleaned.append(sanitized)
    return cleaned


def classify_fault(
    error_type: str,
    message: str,
    status_code: int | None = None,
    source: str = "",
) -> str:
    """Classify fault into code_fault, quota_capacity, or infrastructure."""
    combined = f"{error_type} {message} {source}".lower()
    if status_code == 429 or any(pattern in combined for pattern in _QUOTA_PATTERNS):
        return "quota_capacity"
    if status_code in {502, 503, 504} or any(pattern in combined for pattern in _INFRA_PATTERNS):
        return "infrastructure"
    return "code_fault"


def normalize_message_for_fingerprint(message: str) -> str:
    """Strip ephemeral noise from an error message before hashing."""
    text = sanitize_text(message, max_len=500).lower()
    text = _ISO_TS_RE.sub("<ts>", text)
    text = _UUID_RE.sub("<uuid>", text)
    text = _HEX_ADDR_RE.sub("<hex>", text)
    text = _URL_QUERY_RE.sub("", text)
    text = _LINE_COL_RE.sub("", text)
    text = _WHITESPACE_RE.sub(" ", text).strip()
    return text


def normalize_frame_for_fingerprint(frame: str) -> str:
    """Strip host/query/line noise from a stack frame before hashing."""
    text = sanitize_text(frame, max_len=240).lower()
    text = _ORIGIN_RE.sub("<origin>", text)
    text = _URL_QUERY_RE.sub("", text)
    text = _LINE_COL_RE.sub("", text)
    text = _WHITESPACE_RE.sub(" ", text).strip()
    return text


def compute_fingerprint(
    platform: str,
    error_type: str,
    message: str,
    stack_frames: list[str],
) -> str:
    """Compute deterministic sha256 fingerprint for deduplication."""
    norm_platform = (platform or "web").strip().lower()
    norm_type = (error_type or "UnknownError").strip().lower()
    norm_msg = normalize_message_for_fingerprint(message)
    norm_frames = [
        normalize_frame_for_fingerprint(f)
        for f in stack_frames[:3]
        if f and f.strip()
    ]
    canonical = "|".join([norm_platform, norm_type, norm_msg, *norm_frames])
    digest = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    return f"sha256:{digest}"


@dataclass
class FaultEvent:
    schema_version: int
    fingerprint: str
    category: str
    source: str
    deployment_level: str
    environment: str
    platform: str
    release_sha: str
    url: str
    error_type: str
    message: str
    stack_frames: list[str] = field(default_factory=list)
    occurred_at: str = field(default_factory=utc_now_iso)
    occurrence_count: int = 1

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


def make_fault_event(
    *,
    source: str,
    error_type: str,
    message: str,
    platform: str = "web",
    environment: str = "production",
    deployment_level: str = "firebase-spark",
    release_sha: str = "",
    url: str = "",
    stack_frames: Any = None,
    occurred_at: str | None = None,
    occurrence_count: int = 1,
    status_code: int | None = None,
    category: str | None = None,
) -> FaultEvent:
    clean_type = sanitize_text(error_type or "UnknownError", max_len=120) or "UnknownError"
    clean_msg = sanitize_text(message, max_len=500)
    clean_url = sanitize_url(url)
    clean_frames = sanitize_stack_frames(stack_frames)
    clean_platform = sanitize_text(platform or "web", max_len=32).lower() or "web"
    clean_env = sanitize_text(environment or "production", max_len=32).lower() or "production"
    clean_level = sanitize_text(deployment_level or "firebase-spark", max_len=64).lower() or "firebase-spark"
    clean_source = sanitize_text(source or "unknown", max_len=64).lower() or "unknown"
    clean_sha = sanitize_text(release_sha, max_len=64)
    clean_ts = sanitize_text(occurred_at, max_len=64) or utc_now_iso()
    count = max(1, int(occurrence_count or 1))

    resolved_category = (
        category
        if category in CATEGORIES
        else classify_fault(clean_type, clean_msg, status_code=status_code, source=clean_source)
    )
    fingerprint = compute_fingerprint(clean_platform, clean_type, clean_msg, clean_frames)

    return FaultEvent(
        schema_version=SCHEMA_VERSION,
        fingerprint=fingerprint,
        category=resolved_category,
        source=clean_source,
        deployment_level=clean_level,
        environment=clean_env,
        platform=clean_platform,
        release_sha=clean_sha,
        url=clean_url,
        error_type=clean_type,
        message=clean_msg,
        stack_frames=clean_frames,
        occurred_at=clean_ts,
        occurrence_count=count,
    )


def _extract_error_type(message: str, default: str = "RuntimeError") -> str:
    match = re.match(r"^\s*(?:Uncaught\s+)?([A-Za-z_][A-Za-z0-9_]*(?:Error|Exception))\s*:", message)
    if match:
        return match.group(1)
    if "EmptyEnvFileError" in message:
        return "EmptyEnvFileError"
    return default


def _decode_firestore_value(value: Any) -> Any:
    if not isinstance(value, dict):
        return value
    if "stringValue" in value:
        return value["stringValue"]
    if "integerValue" in value:
        return int(value["integerValue"])
    if "doubleValue" in value:
        return float(value["doubleValue"])
    if "booleanValue" in value:
        return value["booleanValue"]
    if "timestampValue" in value:
        return value["timestampValue"]
    if "nullValue" in value:
        return None
    if "arrayValue" in value:
        return [_decode_firestore_value(v) for v in value["arrayValue"].get("values", [])]
    if "mapValue" in value:
        return {k: _decode_firestore_value(v) for k, v in value["mapValue"].get("fields", {}).items()}
    return value


def _normalize_playwright_probe(
    payload: dict[str, Any],
    default_environment: str,
    default_deployment_level: str,
) -> list[FaultEvent]:
    url = str(payload.get("target_url") or payload.get("url") or "")
    env = str(payload.get("environment") or default_environment)
    level = str(payload.get("deployment_level") or default_deployment_level)
    sha = str(payload.get("release_sha") or "")
    ts = str(payload.get("checked_at") or utc_now_iso())
    raw = payload.get("raw_findings") or {}
    events: list[FaultEvent] = []

    for item in raw.get("page_errors", []) or []:
        if isinstance(item, dict):
            msg = str(item.get("message") or item)
            err_type = str(item.get("name") or _extract_error_type(msg, "PageError"))
            stack = item.get("stack")
        else:
            msg = str(item)
            err_type = _extract_error_type(msg, "PageError")
            stack = None
        events.append(
            make_fault_event(
                source="github/playwright-probe",
                error_type=err_type,
                message=msg,
                platform="web",
                environment=env,
                deployment_level=level,
                release_sha=sha,
                url=url,
                stack_frames=stack,
                occurred_at=ts,
            )
        )

    for item in raw.get("console_errors", []) or []:
        if isinstance(item, dict):
            msg = str(item.get("text") or item.get("message") or item)
            stack = item.get("stack") or item.get("location")
        else:
            msg = str(item)
            stack = None
        err_type = _extract_error_type(msg, "ConsoleError")
        events.append(
            make_fault_event(
                source="github/playwright-probe",
                error_type=err_type,
                message=msg,
                platform="web",
                environment=env,
                deployment_level=level,
                release_sha=sha,
                url=url,
                stack_frames=stack,
                occurred_at=ts,
            )
        )

    for item in raw.get("http_5xx", []) or []:
        if isinstance(item, dict):
            status = item.get("status")
            req_url = str(item.get("url") or url)
            msg = f"HTTP {status} from {req_url}"
            err_type = f"Http{status}Error" if status else "Http5xxError"
        else:
            status = None
            req_url = url
            msg = str(item)
            err_type = "Http5xxError"
        events.append(
            make_fault_event(
                source="github/playwright-probe",
                error_type=err_type,
                message=msg,
                platform="web",
                environment=env,
                deployment_level=level,
                release_sha=sha,
                url=req_url,
                occurred_at=ts,
                status_code=int(status) if isinstance(status, int) else None,
            )
        )

    if payload.get("root_mounted") is False and not events:
        events.append(
            make_fault_event(
                source="github/playwright-probe",
                error_type="MissingRootMount",
                message="Flutter root element (flutter-view / flt-glass-pane) did not mount before timeout.",
                platform="web",
                environment=env,
                deployment_level=level,
                release_sha=sha,
                url=url,
                occurred_at=ts,
            )
        )

    return _merge_duplicate_events(events)


def _normalize_spark_firestore(
    payload: dict[str, Any],
    default_environment: str,
    default_deployment_level: str,
) -> list[FaultEvent]:
    if "document" in payload and isinstance(payload["document"], dict):
        payload = payload["document"]
    if "fields" in payload and isinstance(payload["fields"], dict):
        fields = {k: _decode_firestore_value(v) for k, v in payload["fields"].items()}
        ts = fields.get("occurred_at") or payload.get("createTime") or utc_now_iso()
    else:
        fields = payload
        ts = fields.get("occurred_at") or utc_now_iso()

    message = str(fields.get("message") or fields.get("error") or "")
    error_type = str(fields.get("error_type") or _extract_error_type(message, "FirestoreRuntimeError"))
    return [
        make_fault_event(
            source="firebase/spark-firestore",
            error_type=error_type,
            message=message,
            platform=str(fields.get("platform") or "web"),
            environment=str(fields.get("environment") or default_environment),
            deployment_level=str(fields.get("deployment_level") or default_deployment_level),
            release_sha=str(fields.get("release_sha") or ""),
            url=str(fields.get("url") or ""),
            stack_frames=fields.get("stack_frames") or fields.get("stack"),
            occurred_at=str(ts),
            occurrence_count=int(fields.get("occurrence_count") or 1),
        )
    ]


def _normalize_blaze_cloud_logging(
    payload: dict[str, Any],
    default_environment: str,
    default_deployment_level: str,
) -> list[FaultEvent]:
    json_payload = payload.get("jsonPayload") or {}
    proto_payload = payload.get("protoPayload") or {}
    labels = payload.get("labels") or {}
    message = str(
        json_payload.get("message")
        or json_payload.get("error")
        or payload.get("textPayload")
        or proto_payload.get("status", {}).get("message")
        or ""
    )
    error_type = str(
        json_payload.get("error_type")
        or json_payload.get("name")
        or _extract_error_type(message, "FirebaseTelemetryError")
    )
    stack = json_payload.get("stack") or json_payload.get("stack_frames")
    status_code = json_payload.get("status_code")
    return [
        make_fault_event(
            source="firebase/crashlytics-web",
            error_type=error_type,
            message=message,
            platform=str(json_payload.get("platform") or labels.get("platform") or "web"),
            environment=str(json_payload.get("environment") or labels.get("environment") or default_environment),
            deployment_level=str(json_payload.get("deployment_level") or "firebase-blaze" or default_deployment_level),
            release_sha=str(json_payload.get("release_sha") or labels.get("release_sha") or ""),
            url=str(json_payload.get("url") or ""),
            stack_frames=stack,
            occurred_at=str(payload.get("timestamp") or utc_now_iso()),
            status_code=int(status_code) if isinstance(status_code, int) else None,
        )
    ]


def _normalize_posthog(
    payload: dict[str, Any],
    default_environment: str,
    default_deployment_level: str,
) -> list[FaultEvent]:
    event_data = payload.get("data") if isinstance(payload.get("data"), dict) else payload
    if isinstance(event_data.get("event"), dict):
        event_data = event_data["event"]
    props = event_data.get("properties") if isinstance(event_data.get("properties"), dict) else event_data
    exc_list = props.get("$exception_list") or []
    first_exc = exc_list[0] if isinstance(exc_list, list) and exc_list and isinstance(exc_list[0], dict) else {}
    msg = str(
        props.get("$exception_message")
        or first_exc.get("value")
        or event_data.get("message")
        or payload.get("text")
        or "PostHog exception"
    )
    err_type = str(
        props.get("$exception_type")
        or first_exc.get("type")
        or _extract_error_type(msg, "PostHogError")
    )
    stack = (
        props.get("$exception_stack_trace_raw")
        or (first_exc.get("stacktrace") or {}).get("frames")
        or props.get("stack")
    )
    return [
        make_fault_event(
            source="posthog",
            error_type=err_type,
            message=msg,
            platform=str(props.get("$os") or "web").lower() if props.get("$os") in {"android", "web"} else "web",
            environment=str(props.get("environment") or default_environment),
            deployment_level=str(props.get("deployment_level") or default_deployment_level),
            release_sha=str(props.get("$release") or ""),
            url=str(props.get("$current_url") or event_data.get("url") or ""),
            stack_frames=stack,
            occurred_at=str(event_data.get("timestamp") or utc_now_iso()),
        )
    ]


def _normalize_checkly(
    payload: dict[str, Any],
    default_environment: str,
    default_deployment_level: str,
) -> list[FaultEvent]:
    title = str(payload.get("ALERT_TITLE") or payload.get("CHECK_NAME") or "Checkly alert")
    error = str(payload.get("ERROR") or payload.get("ALERT_TYPE") or title)
    status_code = payload.get("STATUS_CODE")
    if isinstance(status_code, str) and status_code.isdigit():
        status_code = int(status_code)
    elif not isinstance(status_code, int):
        status_code = None
    return [
        make_fault_event(
            source="checkly",
            error_type=_extract_error_type(error, "ChecklyCheckFailed"),
            message=f"{title}: {error}" if error != title else title,
            platform="web",
            environment=str(payload.get("ENVIRONMENT") or default_environment),
            deployment_level=str(payload.get("DEPLOYMENT_LEVEL") or default_deployment_level),
            url=str(payload.get("TARGET_URL") or payload.get("RESULT_LINK") or ""),
            occurred_at=str(payload.get("STARTED_AT") or utc_now_iso()),
            status_code=status_code,
        )
    ]


def _normalize_grafana_faro(
    payload: dict[str, Any],
    default_environment: str,
    default_deployment_level: str,
) -> list[FaultEvent]:
    events: list[FaultEvent] = []
    if isinstance(payload.get("alerts"), list):
        for alert in payload["alerts"]:
            if not isinstance(alert, dict):
                continue
            labels = alert.get("labels") or {}
            annotations = alert.get("annotations") or {}
            msg = str(annotations.get("summary") or annotations.get("description") or labels.get("alertname") or "Grafana alert")
            err_type = str(labels.get("error_type") or labels.get("alertname") or "GrafanaAlert")
            events.append(
                make_fault_event(
                    source="grafana-faro",
                    error_type=err_type,
                    message=msg,
                    platform=str(labels.get("platform") or "web"),
                    environment=str(labels.get("environment") or default_environment),
                    deployment_level=str(labels.get("deployment_level") or default_deployment_level),
                    url=str(annotations.get("url") or alert.get("generatorURL") or ""),
                    occurred_at=str(alert.get("startsAt") or utc_now_iso()),
                )
            )
    elif isinstance(payload.get("exceptions"), list):
        meta = payload.get("meta") or {}
        app = meta.get("app") or {}
        page = meta.get("page") or {}
        for exc in payload["exceptions"]:
            if not isinstance(exc, dict):
                continue
            msg = str(exc.get("value") or exc.get("message") or "Faro exception")
            err_type = str(exc.get("type") or _extract_error_type(msg, "FaroException"))
            events.append(
                make_fault_event(
                    source="grafana-faro",
                    error_type=err_type,
                    message=msg,
                    platform="web",
                    environment=str(app.get("environment") or default_environment),
                    deployment_level=str(app.get("deployment_level") or default_deployment_level),
                    release_sha=str(app.get("release") or ""),
                    url=str(page.get("url") or ""),
                    stack_frames=exc.get("stacktrace", {}).get("frames") if isinstance(exc.get("stacktrace"), dict) else exc.get("stack"),
                    occurred_at=str(exc.get("timestamp") or utc_now_iso()),
                )
            )
    return events


def _normalize_sentry_family(
    payload: dict[str, Any],
    source_name: str,
    default_environment: str,
    default_deployment_level: str,
) -> list[FaultEvent]:
    # Better Stack uptime incident payload
    if isinstance(payload.get("data"), dict) and isinstance(payload["data"].get("attributes"), dict):
        attrs = payload["data"]["attributes"]
        msg = str(attrs.get("cause") or attrs.get("name") or "Better Stack incident")
        status_code = attrs.get("status_code")
        return [
            make_fault_event(
                source="betterstack",
                error_type=_extract_error_type(msg, "BetterStackIncident"),
                message=msg,
                platform="web",
                environment=str(attrs.get("environment") or default_environment),
                deployment_level=default_deployment_level,
                url=str(attrs.get("url") or ""),
                occurred_at=str(attrs.get("started_at") or utc_now_iso()),
                status_code=int(status_code) if isinstance(status_code, int) else None,
            )
        ]

    # GlitchTip Slack-compatible webhook
    if "attachments" in payload and isinstance(payload["attachments"], list):
        att = payload["attachments"][0] if payload["attachments"] and isinstance(payload["attachments"][0], dict) else {}
        title = str(att.get("title") or payload.get("alias") or "GlitchTip alert")
        text = str(att.get("text") or payload.get("text") or title)
        return [
            make_fault_event(
                source="glitchtip",
                error_type=_extract_error_type(title, "GlitchTipError"),
                message=f"{title}: {text}" if text != title else title,
                platform="web",
                environment=default_environment,
                deployment_level=default_deployment_level,
                url=str(att.get("title_link") or ""),
            )
        ]

    # Sentry Internal Integration / Event webhook
    data = payload.get("data") if isinstance(payload.get("data"), dict) else payload
    event = data.get("event") or data.get("issue") or data
    if not isinstance(event, dict):
        event = {}
    metadata = event.get("metadata") or {}
    tags = {t[0]: t[1] for t in event.get("tags", []) if isinstance(t, list) and len(t) == 2} if isinstance(event.get("tags"), list) else (event.get("tags") if isinstance(event.get("tags"), dict) else {})
    msg = str(metadata.get("value") or event.get("title") or event.get("message") or "Sentry error")
    err_type = str(metadata.get("type") or _extract_error_type(msg, "SentryError"))
    frames: Any = None
    exc_values = ((event.get("exception") or {}).get("values") or [])
    if isinstance(exc_values, list) and exc_values and isinstance(exc_values[0], dict):
        err_type = str(exc_values[0].get("type") or err_type)
        msg = str(exc_values[0].get("value") or msg)
        frames = (exc_values[0].get("stacktrace") or {}).get("frames")
    return [
        make_fault_event(
            source=source_name,
            error_type=err_type,
            message=msg,
            platform=str(event.get("platform") or tags.get("platform") or "web"),
            environment=str(event.get("environment") or tags.get("environment") or default_environment),
            deployment_level=str(tags.get("deployment_level") or default_deployment_level),
            release_sha=str(event.get("release") or ""),
            url=str((event.get("request") or {}).get("url") or event.get("web_url") or ""),
            stack_frames=frames,
            occurred_at=str(event.get("datetime") or event.get("timestamp") or utc_now_iso()),
        )
    ]


def _merge_duplicate_events(events: list[FaultEvent]) -> list[FaultEvent]:
    by_fp: dict[str, FaultEvent] = {}
    for ev in events:
        if ev.fingerprint in by_fp:
            by_fp[ev.fingerprint].occurrence_count += ev.occurrence_count
        else:
            by_fp[ev.fingerprint] = ev
    return list(by_fp.values())


def normalize_payload(
    payload: Any,
    *,
    default_source: str | None = None,
    default_environment: str = "production",
    default_deployment_level: str = "firebase-spark",
) -> list[FaultEvent]:
    """Normalize any supported monitoring payload or list of payloads into FaultEvents."""
    if isinstance(payload, list):
        all_events: list[FaultEvent] = []
        for item in payload:
            all_events.extend(
                normalize_payload(
                    item,
                    default_source=default_source,
                    default_environment=default_environment,
                    default_deployment_level=default_deployment_level,
                )
            )
        return _merge_duplicate_events(all_events)

    if not isinstance(payload, dict):
        raise ValueError("Monitoring payload must be a JSON object or list of objects")

    if isinstance(payload.get("events"), list):
        return normalize_payload(
            payload["events"],
            default_source=default_source or payload.get("source"),
            default_environment=default_environment,
            default_deployment_level=default_deployment_level,
        )

    source = str(payload.get("source") or payload.get("provider") or default_source or "").lower()

    # Canonical FaultEvent pass-through
    if payload.get("schema_version") == SCHEMA_VERSION and "error_type" in payload and "message" in payload:
        return [
            make_fault_event(
                source=str(payload.get("source") or default_source or "canonical"),
                error_type=str(payload.get("error_type") or "UnknownError"),
                message=str(payload.get("message") or ""),
                platform=str(payload.get("platform") or "web"),
                environment=str(payload.get("environment") or default_environment),
                deployment_level=str(payload.get("deployment_level") or default_deployment_level),
                release_sha=str(payload.get("release_sha") or ""),
                url=str(payload.get("url") or ""),
                stack_frames=payload.get("stack_frames"),
                occurred_at=payload.get("occurred_at"),
                occurrence_count=int(payload.get("occurrence_count") or 1),
                category=payload.get("category"),
            )
        ]

    # Playwright probe output
    if source == "github/playwright-probe" or "raw_findings" in payload:
        return _normalize_playwright_probe(payload, default_environment, default_deployment_level)

    # Spark Firestore REST document
    if source == "firebase/spark-firestore" or "fields" in payload or ("document" in payload and isinstance(payload["document"], dict) and "fields" in payload["document"]):
        return _normalize_spark_firestore(payload, default_environment, default_deployment_level)

    # Blaze Cloud Logging entry
    if source == "firebase/crashlytics-web" or "logName" in payload or "jsonPayload" in payload:
        return _normalize_blaze_cloud_logging(payload, default_environment, default_deployment_level)

    # External providers
    if source == "posthog" or "$exception_message" in str(payload):
        return _normalize_posthog(payload, default_environment, default_deployment_level)

    if source == "checkly" or "CHECK_NAME" in payload or "ALERT_TITLE" in payload:
        return _normalize_checkly(payload, default_environment, default_deployment_level)

    if source == "grafana-faro" or "alerts" in payload or "exceptions" in payload:
        return _normalize_grafana_faro(payload, default_environment, default_deployment_level)

    if source in {"sentry", "glitchtip", "betterstack"} or "attachments" in payload or "data" in payload or "event" in payload:
        inferred = source or ("betterstack" if isinstance(payload.get("data"), dict) and "attributes" in payload["data"] else ("glitchtip" if "attachments" in payload else "sentry"))
        return _normalize_sentry_family(payload, inferred, default_environment, default_deployment_level)

    # Generic fallback
    if "message" in payload or "error" in payload:
        msg = str(payload.get("message") or payload.get("error") or "")
        return [
            make_fault_event(
                source=source or "external",
                error_type=str(payload.get("error_type") or _extract_error_type(msg, "ExternalFault")),
                message=msg,
                platform=str(payload.get("platform") or "web"),
                environment=str(payload.get("environment") or default_environment),
                deployment_level=str(payload.get("deployment_level") or default_deployment_level),
                release_sha=str(payload.get("release_sha") or ""),
                url=str(payload.get("url") or ""),
                stack_frames=payload.get("stack_frames") or payload.get("stack"),
                occurred_at=payload.get("occurred_at"),
            )
        ]

    return []
