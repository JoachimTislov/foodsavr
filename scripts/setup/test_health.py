import json
from unittest import TestCase

import health

INSTANCE = {
    "environments": {
        "test": {
            "provisioned": True,
            "firebase": {"projectId": "demo-test", "siteId": "demo-test"},
            "channels": {"develop": "demo-test", "daily": "demo-test-daily"},
        },
        "production": {"provisioned": False, "firebase": {"projectId": "demo-prod"}},
    }
}


class FakeLive:
    def __init__(self, statuses=None, run=None, annotations=(), scripts=None):
        self.statuses, self.run, self._annotations = statuses or {}, run, list(annotations)
        self.scripts = scripts or {}

    def http_status(self, url):
        return self.statuses.get(url, 200)

    def latest_run(self, workflow, event, branch, run_name=None):
        return self.run

    def annotations(self, run_id):
        return self._annotations

    def script(self, argv):
        return self.scripts.get(argv[0], (True, ""))


def probe(**variables):
    return {
        "tools": {"terraform": True, "gcloud": True},
        "local_files": {"dotenv": True, "google_services": True, "hooks_configured": True},
        "local_config": {},
        "github": {
            "authenticated": True,
            "is_admin": True,
            "target_repo": "o/r",
            "branches": ["develop"],
            "variables": {
                "DEPLOY_INSTANCE": json.dumps(INSTANCE),
                "GCP_WORKLOAD_IDENTITY_PROVIDER_TEST": "projects/1/providers/p",
                "GCP_DEPLOY_SERVICE_ACCOUNT_TEST": "deploy@demo-test.iam.gserviceaccount.com",
                "AGENT_APP_ID": "1",
                "RELEASE_GATE_APP_ID": "2",
                **variables,
            },
            "secret_names": ["AGENT_APP_PRIVATE_KEY", "RELEASE_GATE_APP_PRIVATE_KEY", "CODEX_AUTH_JSON_B64"],
            "event_policy": {"state": "match", "detail": "matches"},
        },
    }


def evaluate(state, live=None, profile="full-cloud"):
    ctx = health.Context(state, profile, "single", ["develop"], "develop", live)
    return health.evaluate(ctx)


def checks(report):
    return {check["name"]: check for check in report["checks"]}


class HealthTest(TestCase):
    def test_every_check_uses_a_known_kind_and_profile(self):
        config = health.load()
        kinds = {"probe", "branches", "github", "github-any", "event-policy", "environments",
                 "wif", "site", "workflow-run", "script", "registry"}
        ids = [check["id"] for check in config["check"]]
        self.assertEqual(len(ids), len(set(ids)))
        for check in config["check"]:
            self.assertIn(check["kind"], kinds, check["id"])
            self.assertTrue(set(check["profiles"]) <= {"local-dev", "fork-agents", "full-cloud"}, check["id"])
            self.assertTrue(check["fix"] and check["detail"], check["id"])

    def test_healthy_platform_is_ready(self):
        report = evaluate(probe(), FakeLive(run={"id": 1, "conclusion": "success", "html_url": "u"}))
        self.assertTrue(report["ready"], [c for c in report["checks"] if not c["ok"]])
        self.assertIn("site-demo-test-daily", checks(report))
        self.assertIn("gcp-wif-test", checks(report))
        self.assertNotIn("gcp-wif-production", checks(report))

    def test_offline_live_checks_are_not_probed(self):
        report = checks(evaluate(probe()))
        self.assertFalse(report["site-demo-test"]["ok"])
        self.assertIn("not probed", report["hosting-cd"]["detail"])
        self.assertTrue(report["gcp-wif-test"]["ok"])

    def test_deploy_account_of_another_project_fails(self):
        state = probe(GCP_DEPLOY_SERVICE_ACCOUNT_TEST="deploy@old.iam.gserviceaccount.com")
        self.assertFalse(checks(evaluate(state))["gcp-wif-test"]["ok"])

    def test_successful_run_that_deployed_nothing_fails(self):
        live = FakeLive(run={"id": 1, "conclusion": "success", "html_url": "u"},
                        annotations=["SA belongs to another project, so nothing was deployed."])
        result = checks(evaluate(probe(), live))["hosting-cd"]
        self.assertFalse(result["ok"])
        self.assertIn("nothing was deployed", result["detail"])

    def test_unreachable_site_names_its_deploy_command(self):
        live = FakeLive(statuses={"https://demo-test-daily.web.app": 404},
                        run={"id": 1, "conclusion": "success", "html_url": "u"})
        result = checks(evaluate(probe(), live))["site-demo-test-daily"]
        self.assertFalse(result["ok"])
        self.assertEqual(result["remediation"], "make deploy-web ENV=test CHANNEL=daily YES=1")

    def test_declined_archive_is_skipped_and_advisories_do_not_block(self):
        state = probe()
        state["local_config"] = {"sessionArchive": {"enabled": False}}
        live = FakeLive(run={"id": 1, "conclusion": "success", "html_url": "u"},
                        scripts={"scripts/agents/agentctl": (False, "missing: bucket")})
        report = evaluate(state, live)
        self.assertNotIn("session-archive", checks(report))
        self.assertNotIn("workflow-secrets", checks(report))
        self.assertTrue(report["ready"])

    def test_declined_step_becomes_a_note(self):
        state = probe()
        state["local_config"] = {"declinedSteps": ["social-sign-in"]}
        live = FakeLive(run={"id": 1, "conclusion": "success", "html_url": "u"},
                        scripts={"scripts/setup/social_auth.sh": (False, "9 items")})
        report = evaluate(state, live)
        self.assertNotIn("social-auth", checks(report))
        self.assertTrue(any(note.startswith("social-auth: declined") for note in report["notes"]))
        self.assertTrue(report["ready"])

    def test_declined_steps_name_real_wizard_steps(self):
        source = (health.ROOT / "scripts/setup/wizard.py").read_text(encoding="utf-8")
        for check in health.load()["check"]:
            if "declined_step" in check:
                self.assertIn(f'"{check["declined_step"]}"', source, check["id"])

    def test_local_dev_needs_no_github(self):
        report = evaluate(probe(), profile="local-dev")
        self.assertEqual(set(checks(report)), {"local-stubs", "git-hooks"})

    def test_script_checks_bind_to_target_repository_and_reject_mismatched_checkout(self):
        recorded = []

        class RecordingLive(FakeLive):
            def script(self, argv, env=None):
                recorded.append((list(argv), dict(env or {})))
                return True, ""

        state = probe()
        report = evaluate(state, RecordingLive(run={"id": 1, "conclusion": "success", "html_url": "u"}))
        self.assertTrue(report["ready"])
        fc_call = next(argv for argv, _ in recorded if "scripts/infra/firebase_config.py" in argv)
        self.assertEqual(
            fc_call,
            ["python3", "scripts/infra/firebase_config.py", "check", "--project", "demo-test", "--sites", '["demo-test-daily"]'],
        )
        self.assertTrue(all(env.get("GH_REPO") == "o/r" and "DEPLOY_INSTANCE" in env for _, env in recorded))

        mismatched = probe()
        mismatched["origin_repo"] = "other/repo"
        report = checks(evaluate(mismatched, RecordingLive(run={"id": 1, "conclusion": "success", "html_url": "u"})))
        self.assertFalse(report["firebase-config"]["ok"])
        self.assertIn("checkout is bound to other/repo", report["firebase-config"]["detail"])
        self.assertFalse(report["monitoring"]["ok"])
