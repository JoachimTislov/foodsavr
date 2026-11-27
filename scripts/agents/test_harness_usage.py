#!/usr/bin/env python3
"""Unit tests for scripts/agents/harness_usage.py."""

from __future__ import annotations

import json
import os
import stat
import sys
import tempfile
import unittest
import urllib.error
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts/agents"))
import harness_usage as hu  # noqa: E402

NOW = datetime(2026, 11, 22, 12, 0, 0, tzinfo=timezone.utc)


def _write_exec(path: Path, body: str) -> Path:
    path.write_text(body, encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR)
    return path


class AntigravityRefreshTest(unittest.TestCase):
    def test_expired_login_is_refreshed_by_the_native_cli(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            token_path = home / ".gemini/antigravity-cli/antigravity-oauth-token"
            token_path.parent.mkdir(parents=True)
            token_path.write_text(json.dumps({"token": {"access_token": "expired"}}))
            _write_exec(
                home / "agy",
                f"#!{sys.executable}\n"
                "from pathlib import Path\n"
                f"Path({str(token_path)!r}).write_text("
                + repr(json.dumps({"token": {"access_token": "refreshed"}})) + ")\n",
            )

            def quota(url, token, payload, timeout):
                if token == "expired":
                    raise urllib.error.HTTPError(url, 401, "Unauthorized", {}, None)
                return {"buckets": [{"remainingFraction": 0.8}]}

            env = {**os.environ, "HOME": tmp, "PATH": tmp}
            result = hu.probe_antigravity(env=env, now=NOW, http_post=quota)
            self.assertEqual(result.min_remaining_percent(NOW), 80.0)

    def test_rejected_login_reports_one_owner_action(self):
        with tempfile.TemporaryDirectory() as tmp:
            token_path = Path(tmp) / "token"
            token_path.write_text('{"access_token": "invalid"}')

            def quota(url, token, payload, timeout):
                raise urllib.error.HTTPError(url, 403, "Forbidden", {}, None)

            result = hu.probe_antigravity(token_path=token_path, now=NOW, http_post=quota)
            self.assertEqual(result.error, "Owner action: sign in again with agy.")


class UsageWindowTest(unittest.TestCase):
    def test_exhausted_respects_threshold_and_reset_time(self):
        future = hu.iso_utc(NOW + timedelta(hours=2))
        past = hu.iso_utc(NOW - timedelta(minutes=1))
        full = hu.UsageWindow("w1", "5h", used_percent=96.0, resets_at=future)
        self.assertTrue(full.is_exhausted(NOW))
        self.assertEqual(full.remaining_percent(NOW), 4.0)

        already_reset = hu.UsageWindow("w2", "5h", used_percent=100.0, resets_at=past)
        self.assertFalse(already_reset.is_exhausted(NOW))
        self.assertEqual(already_reset.remaining_percent(NOW), 100.0)

        extra = hu.UsageWindow("w3", "extra", used_percent=100.0, resets_at=future, is_extra_usage=True)
        self.assertFalse(extra.is_exhausted(NOW))

        disabled = hu.UsageWindow("w4", "5h", used_percent=10.0, disabled=True)
        self.assertTrue(disabled.is_exhausted(NOW))
        self.assertEqual(disabled.remaining_percent(NOW), 0.0)


class AntigravityParserAndProbeTest(unittest.TestCase):
    def test_parse_quota_summary_and_untouched_reset_omission(self):
        untouched_reset = hu.iso_utc(NOW + timedelta(minutes=300))
        active_reset = hu.iso_utc(NOW + timedelta(minutes=120))
        payload = {
            "groups": [
                {
                    "label": "Gemini Pro",
                    "buckets": [
                        {"bucketId": "pro-5h", "window": "5h", "remainingFraction": 1.0, "resetTime": untouched_reset},
                        {"bucketId": "pro-weekly", "window": "weekly", "remainingFraction": 0.35, "resetTime": active_reset},
                    ],
                }
            ],
            "buckets": [{"bucketId": "disabled-b", "window": "5h", "disabled": True}],
        }
        windows = hu.parse_antigravity_quota_summary(payload, now=NOW)
        by_id = {w.id: w for w in windows}
        self.assertEqual(by_id["pro-5h"].used_percent, 0.0)
        self.assertIsNone(by_id["pro-5h"].resets_at)
        self.assertEqual(by_id["pro-weekly"].used_percent, 65.0)
        self.assertEqual(by_id["pro-weekly"].resets_at, active_reset)
        self.assertTrue(by_id["disabled-b"].disabled)
        self.assertEqual(by_id["disabled-b"].used_percent, 100.0)

    def test_parse_available_models_aggregates_worst_fraction(self):
        payload = {
            "models": {
                "gemini-2.5-pro": {
                    "quotaInfo": {"remainingFraction": 0.8, "resetTime": "2026-11-22T15:00:00Z"},
                    "weeklyQuotaInfo": {"remainingFraction": 0.9, "resetTime": "2026-11-28T00:00:00Z"},
                },
                "gemini-3-pro": {
                    "quotaInfo": {"remainingFraction": 0.2, "resetTime": "2026-11-22T14:00:00Z"},
                },
            }
        }
        windows = hu.parse_antigravity_available_models(payload, now=NOW)
        by_id = {w.id: w for w in windows}
        self.assertEqual(by_id["antigravity-5h"].used_percent, 80.0)
        self.assertEqual(by_id["antigravity-5h"].model_id, "gemini-3-pro")
        self.assertEqual(by_id["antigravity-weekly"].used_percent, 10.0)

    def test_probe_antigravity_api_key_unmetered_and_fallback_endpoint(self):
        with tempfile.TemporaryDirectory() as tmp:
            missing = Path(tmp) / "missing-token"
            snap_api = hu.probe_antigravity(token_path=missing, env={"GEMINI_API_KEY": "test-key"}, now=NOW)
            self.assertEqual(snap_api.status, "unmetered")
            self.assertEqual(snap_api.auth_mode, "api_key")

            snap_none = hu.probe_antigravity(token_path=missing, env={}, now=NOW)
            self.assertEqual(snap_none.status, "unavailable")

            tok = Path(tmp) / "antigravity-oauth-token"
            tok.write_text(json.dumps({"token": {"access_token": "secret-access"}}), encoding="utf-8")
            calls: list[str] = []

            def fake_post(url: str, token: str, payload: dict, timeout: float) -> dict:
                calls.append(url)
                self.assertEqual(token, "secret-access")
                if "retrieveUserQuotaSummary" in url:
                    raise OSError("summary unavailable")
                return {"models": {"gemini-3-pro": {"quotaInfo": {"remainingFraction": 0.6, "resetTime": "2026-11-22T16:00:00Z"}}}}

            snap_ok = hu.probe_antigravity(token_path=tok, env={}, now=NOW, http_post=fake_post)
            self.assertEqual(snap_ok.status, "ok")
            self.assertEqual(snap_ok.min_remaining_percent(NOW), 60.0)
            self.assertTrue(any("fetchAvailableModels" in c for c in calls))

    def test_ignores_third_party_claude_and_gpt_quota_buckets(self):
        reset_time = hu.iso_utc(NOW + timedelta(hours=4))
        summary_payload = {
            "groups": [
                {
                    "label": "Gemini Models",
                    "buckets": [
                        {"bucketId": "gemini-weekly", "label": "Weekly", "window": "weekly", "remainingFraction": 0.77, "resetTime": reset_time},
                        {"bucketId": "gemini-5h", "label": "5-Hour", "window": "5h", "remainingFraction": 0.68, "resetTime": reset_time},
                    ],
                },
                {
                    "label": "Claude and GPT models",
                    "buckets": [
                        {"bucketId": "3p-weekly", "label": "Weekly", "window": "weekly", "remainingFraction": 0.0, "resetTime": reset_time},
                        {"bucketId": "3p-5h", "label": "5-Hour", "window": "5h", "disabled": True},
                    ],
                },
            ]
        }
        windows = hu.parse_antigravity_quota_summary(summary_payload, now=NOW)
        self.assertEqual([w.id for w in windows], ["gemini-weekly", "gemini-5h"])
        snap = hu.HarnessUsageSnapshot("antigravity", "ok", tuple(windows), fetched_at=hu.iso_utc(NOW))
        self.assertFalse(snap.exhausted(NOW))
        self.assertEqual(snap.min_remaining_percent(NOW), 68.0)

        models_payload = {
            "models": {
                "gemini-3-pro": {
                    "modelProvider": "MODEL_PROVIDER_GOOGLE",
                    "quotaInfo": {"remainingFraction": 0.68, "resetTime": reset_time},
                    "weeklyQuotaInfo": {"remainingFraction": 0.77, "resetTime": reset_time},
                },
                "claude-sonnet-4-6": {
                    "modelProvider": "MODEL_PROVIDER_ANTHROPIC",
                    "quotaInfo": {},
                    "weeklyQuotaInfo": {"remainingFraction": 0.0, "resetTime": reset_time},
                },
                "gpt-oss-120b-medium": {
                    "modelProvider": "MODEL_PROVIDER_OPENAI",
                    "quotaInfo": {"remainingFraction": 0.0, "resetTime": reset_time},
                },
            }
        }
        model_windows = hu.parse_antigravity_available_models(models_payload, now=NOW)
        by_id = {w.id: w for w in model_windows}
        self.assertEqual(by_id["antigravity-5h"].used_percent, 32.0)
        self.assertEqual(by_id["antigravity-weekly"].used_percent, 23.0)


class CodexParserAndProbeTest(unittest.TestCase):
    def test_parse_codex_rate_limits_prefers_codex_bucket_and_free_monthly_label(self):
        reset_epoch = int((NOW + timedelta(hours=3)).timestamp())
        payload = {
            "jsonrpc": "2.0",
            "id": 2,
            "result": {
                "rateLimitsByLimitId": {
                    "codex": {
                        "planType": "free",
                        "primary": {"usedPercent": 40, "windowDurationMins": 43200, "resetsAt": reset_epoch},
                        "secondary": {"usedPercent": 25, "windowDurationMins": 10080, "resetsAt": reset_epoch},
                        "individualLimit": {"remainingPercent": 70, "resetsAt": reset_epoch},
                    }
                }
            },
        }
        windows, plan_type = hu.parse_codex_rate_limits(payload)
        self.assertEqual(plan_type, "free")
        by_id = {w.id: w for w in windows}
        self.assertEqual(by_id["codex-primary"].label, "monthly")
        self.assertEqual(by_id["codex-primary"].used_percent, 40.0)
        self.assertEqual(by_id["codex-secondary"].used_percent, 25.0)
        self.assertEqual(by_id["codex-individual"].used_percent, 30.0)

    def test_probe_codex_stdio_jsonrpc(self):
        with tempfile.TemporaryDirectory() as tmp:
            bin_dir = Path(tmp) / "bin"
            bin_dir.mkdir()
            reset_epoch = int((NOW + timedelta(hours=4)).timestamp())
            script = (
                f"#!{sys.executable}\n"
                "import json, sys\n"
                "for line in sys.stdin:\n"
                "    msg = json.loads(line)\n"
                "    if msg.get('method') == 'initialize':\n"
                "        print(json.dumps({'jsonrpc': '2.0', 'id': msg['id'], 'result': {}}), flush=True)\n"
                "    elif msg.get('method') == 'account/rateLimits/read':\n"
                f"        print(json.dumps({{'jsonrpc': '2.0', 'id': msg['id'], 'result': {{'rateLimits': {{'planType': 'pro', 'primary': {{'usedPercent': 20, 'windowDurationMins': 300, 'resetsAt': {reset_epoch}}}}}}}}}), flush=True)\n"
                "        break\n"
            )
            _write_exec(bin_dir / "codex", script)
            home = Path(tmp) / "home"
            (home / ".codex").mkdir(parents=True)
            (home / ".codex" / "auth.json").write_text("{}", encoding="utf-8")
            env = {"PATH": str(bin_dir), "HOME": str(home)}
            snap = hu.probe_codex(timeout=3.0, env=env, now=NOW)
            self.assertEqual(snap.status, "ok")
            self.assertEqual(snap.plan_type, "pro")
            self.assertEqual(snap.min_remaining_percent(NOW), 80.0)


class ClaudeParserAndProbeTest(unittest.TestCase):
    def test_parse_claude_usage_windows(self):
        payload = {
            "type": "control_response",
            "response": {
                "request_id": "1",
                "subtype": "success",
                "response": {
                    "rate_limits": {
                        "five_hour": {"utilization": 55.5, "resets_at": "2026-11-22T15:00:00Z"},
                        "seven_day": {"utilization": 30.0, "resets_at": "2026-11-28T00:00:00Z"},
                        "seven_day_sonnet": {"utilization": 12.0, "resets_at": "2026-11-28T00:00:00Z"},
                    },
                    "extra_usage": {"is_enabled": True, "utilization": 100.0},
                },
            },
        }
        windows = hu.parse_claude_usage(payload)
        by_id = {w.id: w for w in windows}
        self.assertEqual(by_id["claude-five_hour"].used_percent, 55.5)
        self.assertEqual(by_id["claude-seven_day"].used_percent, 30.0)
        self.assertEqual(by_id["claude-seven_day_sonnet"].model_id, "sonnet")
        self.assertTrue(by_id["claude-extra-usage"].is_extra_usage)

    def test_probe_claude_stream_json_control_request(self):
        with tempfile.TemporaryDirectory() as tmp:
            bin_dir = Path(tmp) / "bin"
            bin_dir.mkdir()
            script = (
                f"#!{sys.executable}\n"
                "import json, sys\n"
                "for line in sys.stdin:\n"
                "    msg = json.loads(line)\n"
                "    if msg.get('type') == 'control_request':\n"
                "        resp = {'type': 'control_response', 'response': {'request_id': msg['request_id'], 'subtype': 'success', 'response': {'rate_limits': {'five_hour': {'utilization': 15, 'resets_at': '2026-11-22T16:00:00Z'}}}}}\n"
                "        print(json.dumps(resp), flush=True)\n"
                "        break\n"
            )
            _write_exec(bin_dir / "claude", script)
            env = {"PATH": str(bin_dir), "HOME": tmp, "CLAUDE_CODE_OAUTH_TOKEN": "tok"}
            snap = hu.probe_claude(timeout=3.0, env=env, now=NOW)
            self.assertEqual(snap.status, "ok")
            self.assertEqual(snap.min_remaining_percent(NOW), 85.0)

    def test_probe_claude_falls_back_to_oauth_usage_api_when_cli_omits_rate_limits(self):
        with tempfile.TemporaryDirectory() as tmp:
            bin_dir = Path(tmp) / "bin"
            bin_dir.mkdir()
            script = (
                f"#!{sys.executable}\n"
                "import json, sys\n"
                "for line in sys.stdin:\n"
                "    msg = json.loads(line)\n"
                "    if msg.get('type') == 'control_request':\n"
                "        resp = {'type': 'control_response', 'response': {'request_id': msg['request_id'], 'subtype': 'success', 'response': {'rate_limits_available': False, 'rate_limits': None}}}\n"
                "        print(json.dumps(resp), flush=True)\n"
                "        break\n"
            )
            _write_exec(bin_dir / "claude", script)
            env = {"PATH": str(bin_dir), "HOME": tmp, "CLAUDE_CODE_OAUTH_TOKEN": "oauth-secret"}
            seen: list[tuple[str, str]] = []

            def fake_get(url: str, token: str, timeout: float) -> dict:
                seen.append((url, token))
                return {
                    "five_hour": {"utilization": 8.0, "resets_at": "2026-11-22T16:00:00Z"},
                    "seven_day": {"utilization": 42.0, "resets_at": "2026-11-28T00:00:00Z"},
                }

            snap = hu.probe_claude(timeout=3.0, env=env, now=NOW, http_get=fake_get)
            self.assertEqual(snap.status, "ok")
            self.assertEqual(seen, [(hu.CLAUDE_OAUTH_USAGE_URL, "oauth-secret")])
            self.assertEqual(snap.min_remaining_percent(NOW), 58.0)


class RankingTest(unittest.TestCase):
    def _snap(self, provider: str, used: float | None, status: str = "ok", auth_mode: str = "subscription") -> hu.HarnessUsageSnapshot:
        future = hu.iso_utc(NOW + timedelta(hours=2))
        windows = (hu.UsageWindow(f"{provider}-5h", "5h", used_percent=used, resets_at=future),) if used is not None else ()
        return hu.HarnessUsageSnapshot(provider=provider, status=status, windows=windows, auth_mode=auth_mode, fetched_at=hu.iso_utc(NOW))

    def test_skips_exhausted_and_picks_highest_headroom_with_order_tiebreak(self):
        snaps = {
            "claude": self._snap("claude", 98.0),  # exhausted
            "codex": self._snap("codex", 40.0),    # 60% remaining
            "antigravity": self._snap("antigravity", 20.0),  # 80% remaining
        }
        eligible, meta = hu.rank_providers_by_quota(["claude", "codex", "antigravity"], snaps, now=NOW)
        self.assertEqual(eligible, ["antigravity", "codex"])
        self.assertIn("claude", meta["skipped"])
        self.assertTrue(meta["has_live_quota"])
        self.assertFalse(meta["all_exhausted"])

        # Tie-break preserves original candidate order
        tied = {
            "claude": self._snap("claude", 25.0),
            "codex": self._snap("codex", 25.0),
        }
        eligible_tied, _ = hu.rank_providers_by_quota(["claude", "codex"], tied, now=NOW)
        self.assertEqual(eligible_tied, ["claude", "codex"])

    def test_fail_open_preserves_order_when_all_probes_error(self):
        snaps = {
            "claude": self._snap("claude", None, status="error"),
            "codex": self._snap("codex", None, status="unavailable"),
        }
        eligible, meta = hu.rank_providers_by_quota(["claude", "codex"], snaps, now=NOW)
        self.assertEqual(eligible, ["claude", "codex"])
        self.assertFalse(meta["has_live_quota"])
        self.assertFalse(meta["all_exhausted"])

    def test_all_exhausted_returns_empty_eligible(self):
        snaps = {
            "claude": self._snap("claude", 99.0),
            "codex": self._snap("codex", 96.0),
        }
        eligible, meta = hu.rank_providers_by_quota(["claude", "codex"], snaps, now=NOW)
        self.assertEqual(eligible, [])
        self.assertTrue(meta["all_exhausted"])
        self.assertEqual(set(meta["skipped"]), {"claude", "codex"})


class QuotaCacheTest(unittest.TestCase):
    def test_reuses_quota_until_expiry_or_account_change(self):
        from unittest.mock import patch

        with tempfile.TemporaryDirectory() as tmp, patch.object(hu, "probe_provider") as probe:
            probe.side_effect = [
                hu.HarnessUsageSnapshot("codex", "ok", (hu.UsageWindow("5h", "5h", used),))
                for used in (8, 17, 30)
            ]
            env = {"HOME": tmp, "OPENAI_API_KEY": "first"}
            options = {"cache_dir": Path(tmp), "env": env}
            self.assertEqual(hu.probe_all(["codex"], now=NOW, **options)["codex"].min_remaining_percent(NOW), 92)
            self.assertEqual(hu.probe_all(["codex"], now=NOW, **options)["codex"].min_remaining_percent(NOW), 92)
            env["OPENAI_API_KEY"] = "second"
            self.assertEqual(hu.probe_all(["codex"], now=NOW, **options)["codex"].min_remaining_percent(NOW), 83)
            later = NOW + timedelta(minutes=2)
            self.assertEqual(hu.probe_all(["codex"], now=later, **options)["codex"].min_remaining_percent(later), 70)


class QuotaErrorTest(unittest.TestCase):
    def test_provider_usage_limit_signals_and_resets(self):
        cases = [
            ("You've hit your limit · resets 4pm (Europe/Oslo)", "2026-11-22T15:00:00Z"),
            ({"code": "usage_limit_reached", "resets_at": NOW.timestamp() + 3600}, "2026-11-22T13:00:00Z"),
            ({"code": 429, "status": "RESOURCE_EXHAUSTED", "message": "Quota exceeded",
              "details": [{"metadata": {"quotaResetTimeStamp": "2026-11-22T16:00:00+01:00"}}]},
             "2026-11-22T15:00:00Z"),
            ("Usage limit reached. Try again in 1h 30m", "2026-11-22T13:30:00Z"),
            ("2026-11-22T12:00:01Z Usage limit reached.\nResets at 2026-11-22T13:00:00Z", "2026-11-22T13:00:00Z"),
            ("unexpected status 429 Too Many Requests", None),
            ("insufficient_quota", None),
        ]
        for error, reset in cases:
            with self.subTest(error=error):
                expected = {"failure_kind": "quota_exhausted"}
                if reset:
                    expected["resets_at"] = reset
                self.assertEqual(hu.quota_error_details(error, now=NOW), expected)

    def test_generic_failures_are_not_usage_limits(self):
        for error in ("quota probe credential missing", "HTTP 401", "failure at line 429", "disk quota exceeded"):
            with self.subTest(error=error):
                self.assertEqual(hu.quota_error_details(error, now=NOW), {})


class ResolveStepRouteQuotaTest(unittest.TestCase):
    def test_resolve_step_route_prefers_highest_headroom_and_skips_exhausted(self):
        import agentctl  # noqa: E402

        workflow = {"id": "implement-issue", "permissions": {"filesystem": "workspace-write", "network": "none", "git": "branch-write", "github": "none"}}
        step = {"id": "implement", "role": "engineer", "prompt": "implement feature"}
        specs = agentctl.provider_specs()
        router = agentctl.load_json(agentctl.ROUTER)
        future = hu.iso_utc(hu.utc_now() + timedelta(hours=2))
        snaps = {
            "claude": hu.HarnessUsageSnapshot("claude", "ok", (hu.UsageWindow("c5", "5h", 97.0, resets_at=future),)),
            "codex": hu.HarnessUsageSnapshot("codex", "ok", (hu.UsageWindow("x5", "5h", 45.0, resets_at=future),)),
            "antigravity": hu.HarnessUsageSnapshot("antigravity", "ok", (hu.UsageWindow("a5", "5h", 15.0, resets_at=future),)),
        }
        decision, _, reason = agentctl.resolve_step_route(
            workflow, step, ["claude", "codex", "antigravity"], specs, router, quota_snapshots=snaps,
        )
        self.assertIsNotNone(decision)
        assert decision is not None
        self.assertEqual(decision.provider, "antigravity")
        self.assertEqual(decision.source, "quota-headroom")
        self.assertIn("quota-headroom:antigravity:85pct", reason)

    def test_resolve_step_route_returns_none_when_all_exhausted(self):
        import agentctl  # noqa: E402

        workflow = {"id": "implement-issue", "permissions": {"filesystem": "workspace-write", "network": "none", "git": "branch-write", "github": "none"}}
        step = {"id": "implement", "role": "engineer", "prompt": "implement feature"}
        specs = agentctl.provider_specs()
        router = agentctl.load_json(agentctl.ROUTER)
        future = hu.iso_utc(hu.utc_now() + timedelta(hours=2))
        snaps = {
            "claude": hu.HarnessUsageSnapshot("claude", "ok", (hu.UsageWindow("c5", "5h", 99.0, resets_at=future),)),
            "codex": hu.HarnessUsageSnapshot("codex", "ok", (hu.UsageWindow("x5", "5h", 98.0, resets_at=future),)),
        }
        decision, _, reason = agentctl.resolve_step_route(
            workflow, step, ["claude", "codex"], specs, router, quota_snapshots=snaps,
        )
        self.assertIsNone(decision)
        self.assertEqual(reason, "all-providers-quota-exhausted")


if __name__ == "__main__":
    unittest.main()
