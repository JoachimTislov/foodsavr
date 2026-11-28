#!/usr/bin/env python3
import importlib.util
import re
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("local_ci", ROOT / "scripts/ci/local_ci.py")
ci = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules["local_ci"] = ci
spec.loader.exec_module(ci)


def first_paths(workflow: str) -> set[str]:
    """Items of the first `paths:` list in a workflow file."""
    lines = (ROOT / ".github/workflows" / workflow).read_text().splitlines()
    start = next(i for i, line in enumerate(lines) if line.strip().startswith("paths:"))
    items = []
    for line in lines[start + 1:]:
        match = re.match(r"\s*- ['\"]?(.+?)['\"]?\s*$", line)
        if not match:
            break
        items.append(match.group(1))
    return set(items)


def workflow_text(workflow: str) -> str:
    return (ROOT / ".github/workflows" / workflow).read_text()


def pathspecs(patterns: list[str]) -> set[str]:
    """Glob filter patterns as the git pathspecs already_tested.sh diffs."""
    return {p.removesuffix("/**") for p in patterns}


class LocalCiTest(unittest.TestCase):
    def test_glob_semantics_match_github_path_filters(self):
        self.assertTrue(ci.glob_re("**.dart").match("lib/a/b.dart"))
        self.assertTrue(ci.glob_re("**.dart").match("main.dart"))
        self.assertTrue(ci.glob_re("*.md").match("README.md"))
        self.assertFalse(ci.glob_re("*.md").match("doc/a.md"))
        self.assertTrue(ci.glob_re(".agents/**").match(".agents/skills/x/SKILL.md"))
        self.assertFalse(ci.glob_re("lib/**").match("library.txt"))
        # `**/` matches zero directories, like GitHub's matcher: root-level
        # dependency files must select the dependency-review suite (#531).
        self.assertTrue(ci.glob_re("android/**/build.gradle*").match("android/build.gradle"))
        self.assertTrue(ci.glob_re("android/**/build.gradle*").match("android/app/build.gradle.kts"))
        self.assertTrue(ci.glob_re("**/package.json").match("package.json"))
        self.assertTrue(ci.glob_re("**/package.json").match("web/package.json"))
        self.assertTrue(ci.ci_filters(["android/build.gradle"])["deps"])
        self.assertTrue(ci.ci_filters(["package.json"])["deps"])
        self.assertTrue(ci.ci_filters(["package-lock.json"])["deps"])

    def test_groups_for_changed_files(self):
        self.assertEqual(ci.groups_for(["lib/main.dart"]), ["dart"])
        self.assertEqual(ci.groups_for(["lib/main.dart", ".agents/events/2026/11/x.jsonl"]), ["dart"])
        self.assertEqual(ci.groups_for([".agents/events/2026/11/x.jsonl"]), [])
        self.assertEqual(ci.groups_for([".agents/events/2026/11/x.jsonl", ".agents/skills/x/SKILL.md"]), ["agents"])
        self.assertEqual(ci.groups_for(["specs/status.md"]), ["agents", "docs"])
        self.assertEqual(ci.groups_for([".github/workflows/merge-gate.yml"]), ["agents", "workflows"])
        self.assertEqual(ci.groups_for(["Makefile"]), ["agents"])
        self.assertEqual(ci.groups_for(["README.md"]), ["docs"])
        self.assertEqual(ci.groups_for(["scripts/release/prepare_android.py"]), ["release"])
        self.assertEqual(ci.groups_for(["scripts/infra/bootstrap_support.py"]), ["infra"])

    def test_pull_request_workflow_decides_suites_with_local_ci(self):
        # #496: suite path decisions come from this module, so CI and `make check` agree.
        text = workflow_text("pull-request.yml")
        self.assertIn("scripts/ci/local_ci.py --ci-filters", text)
        for group, output in (("dart", "DART"), ("release", "RELEASE"), ("agents", "AGENTS"),
                              ("docs", "DOCS"), ("infra", "INFRA"), ("web", "WEB"), ("rules", "RULES")):
            self.assertIn(f"{output}: ${{{{ steps.paths.outputs.{group} }}}}", text)
        self.assertIn("steps.paths.outputs.deps == 'true'", text)
        self.assertEqual(set(ci.ci_filters([])), set(ci.CI_GROUPS) | set(ci.CI_FILTERS))

    def test_check_names_required_by_the_ruleset_are_unchanged(self):
        text = workflow_text("pull-request.yml")
        for name in ("Decide whether to run CI", "Check & Test"):
            self.assertIn(f"\n    name: {name}\n", text)
        # A reusable-workflow job reports as `caller / job`, so the required check is a
        # verdict job that must run (never skip) whenever the suite was selected.
        verdict = text.split("\n  check:\n", 1)[1].split("\n  agents:\n", 1)[0]
        self.assertIn("needs: [gate, dart-checks]", verdict)
        self.assertIn("if: ${{ always() && needs.gate.outputs.run == 'true' }}", verdict)
        self.assertIn('test "$RESULT" = success', verdict)

    def test_self_managed_merge_validates_non_draft_prs_without_a_label(self):
        text = workflow_text("pull-request.yml")
        condition = "(vars.SELF_MANAGED_MERGE == 'true' && !github.event.pull_request.draft)"
        # The gate env and the failed-preflight condition of `validation-result`.
        self.assertEqual(text.count(condition), 2)
        self.assertIn("env.CONTENT_EVENT == 'true' && env.AUTO_VALIDATE != 'true'", text)
        self.assertIn('validate="$AUTO_VALIDATE"', text)
        self.assertNotIn("HAS_AUTO", text)
        # A draft turned ready must start Validation, without cancelling the running suites.
        self.assertIn("reopened, ready_for_review, edited, labeled]", text)
        self.assertIn("github.event.action != 'ready_for_review'", text)

    def test_post_deploy_probe_targets_the_deployed_site(self):
        text = workflow_text("release.yml")
        self.assertIn("url: ${{ steps.live.outputs.url }}", text)
        self.assertIn("(needs.hosting-deploy.outputs.url != '' || vars.MONITOR_TARGET_URL != '')", text)
        self.assertIn("target-url: ${{ needs.hosting-deploy.outputs.url || vars.MONITOR_TARGET_URL }}", text)
        self.assertIn(
            "environment: ${{ needs.hosting-deploy.outputs.url != '' && needs.plan.outputs.flavor || 'production' }}",
            text,
        )
        probe_action = (ROOT / ".github/actions/web-probe/action.yml").read_text()
        self.assertIn("  environment:\n", probe_action)
        self.assertIn("ENVIRONMENT: ${{ steps.target.outputs.environment }}", probe_action)
        self.assertIn('--environment "$ENVIRONMENT"', probe_action)

    def test_release_channel_hosting_deploys_are_gated_on_release_gate(self):
        text = workflow_text("release.yml")
        gate = text.split("\n  release-gate:\n", 1)[1].split("\n  release-web:\n", 1)[0]
        self.assertIn("needs: plan", gate)
        for branch in ("daily", "weekly", "stable"):
            self.assertIn(f"refs/heads/{branch}", gate)
        self.assertIn("passed: ${{ steps.evaluate.outputs.passed }}", gate)

        web_candidate = text.split("\n  release-web:\n", 1)[1].split("\n  # --- Firebase Hosting", 1)[0]
        self.assertIn("needs: [build-web, release-gate]", web_candidate)
        self.assertIn("github.ref == 'refs/heads/stable'", web_candidate)
        self.assertIn("needs.release-gate.outputs.release_web == 'true'", web_candidate)

        hosting = text.split("\n  hosting-deploy:\n", 1)[1].split("\n  # Post-deploy probe", 1)[0]
        self.assertIn("needs: [plan, release-gate]", hosting)
        self.assertIn("github.event_name != 'push'", hosting)
        self.assertIn("github.ref == 'refs/heads/develop'", hosting)
        self.assertIn("needs.release-gate.outputs.passed == 'true'", hosting)

    def test_daily_ci_alert_job_runs_on_daily_push_with_minimal_permissions(self):
        text = workflow_text("pull-request.yml")
        job = text.split("\n  daily-ci-alert:\n", 1)[1]
        self.assertIn("needs: [gate, check, changes, web-validation, validation-result]", job)
        self.assertIn("if: always() && github.event_name == 'push' && github.ref_name == 'daily'", job)
        self.assertIn("contents: read", job)
        self.assertIn("issues: write", job)
        self.assertIn("python3 scripts/github/daily_ci_alert.py --soft-fail", job)

    def test_suite_job_names_match_the_reuse_evidence(self):
        dart = (ROOT / ci.DART_WORKFLOW).read_text()
        web = (ROOT / ci.WEB_WORKFLOW).read_text()
        reuse = (ROOT / "scripts/ci/already_tested.sh").read_text()
        self.assertIn("'Full Dart suite' || 'Relational Dart suite'", dart)
        self.assertIn("(^| / )Full Dart suite$", workflow_text("pull-request.yml"))
        self.assertIn("'Web full E2E' || 'Web smoke test'", web)
        self.assertIn("(^| / )Web full E2E$", reuse)
        for project in ("smoke", "chromium", "mobile-chrome"):
            self.assertIn(f"--project={project}", web)
            self.assertIn(f"name: '{project}'", (ROOT / "test/e2e/playwright.config.ts").read_text())

    def test_ci_filters_follow_group_paths_without_local_extras(self):
        decisions = ci.ci_filters([".agents/events/2026/11/x.jsonl", "README.md"])
        self.assertFalse(decisions["agents"])
        self.assertTrue(decisions["docs"])
        self.assertFalse(ci.ci_filters(["scripts/setup/setupctl.py"])["infra"])
        self.assertTrue(ci.ci_filters(["deploy/instance.yaml"])["infra"])
        self.assertTrue(ci.ci_filters(["lib/main.dart"])["web"])
        self.assertTrue(ci.ci_filters(["firestore.rules"])["rules"])
        self.assertTrue(ci.ci_filters(["packages/foodsavr_core/pubspec.yaml"])["deps"])
        self.assertFalse(any(ci.ci_filters(["scripts/github/merge_gate.py"])[k] for k in ("dart", "web", "deps")))

    def test_validation_reuse_targets_match_ci_filters(self):
        text = workflow_text("pull-request.yml")
        for name in ("web", "rules"):
            match = re.search(rf"--target '{name}:([^']+)'", text)
            self.assertIsNotNone(match, name)
            self.assertEqual(set(match.group(1).split(",")), pathspecs(ci.CI_FILTERS[name]))

    def test_check_and_test_reuse_scope_covers_the_dart_group(self):
        # A synchronize that changes only `assets/logo.png` must rerun Check & Test:
        # the reuse scope keeps every dart-group path area, `assets` included (#531).
        text = workflow_text("pull-request.yml")
        block = text.split("check_and_test() {", 1)[1].split("if grep -q", 1)[0]
        invocation = block.replace("\\\n", " ").split()
        scope = invocation[invocation.index("pull-request.yml") + 1:]
        for area in ("lib", "packages", "test", "assets", "pubspec.yaml", "pubspec.lock",
                     "analysis_options.yaml", "integration_test", "test_driver", ci.DART_WORKFLOW):
            self.assertIn(area, scope)
        self.assertNotIn("assets/translations", scope)

    def test_changed_files_reads_literal_paths_and_rename_destinations(self):
        # `git diff`/`git status` NUL output: a non-ASCII path must arrive as the
        # literal name, never as Git's quoted escape sequence, and a staged rename
        # must count its destination (#531).
        import subprocess
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "-q", "-b", "main", str(root)], check=True)
            for argv in (["git", "config", "user.email", "t@t"], ["git", "config", "user.name", "t"]):
                subprocess.run(argv, cwd=root, check=True)
            (root / "assets").mkdir()
            (root / "assets" / "keep.txt").write_text("v1", encoding="utf-8")
            subprocess.run(["git", "add", "."], cwd=root, check=True)
            subprocess.run(["git", "commit", "-qm", "base"], cwd=root, check=True)
            base = subprocess.run(["git", "rev-parse", "HEAD"], cwd=root, check=True,
                                  text=True, capture_output=True).stdout.strip()
            (root / "assets" / "café.png").write_bytes(b"png")
            subprocess.run(["git", "add", "."], cwd=root, check=True)
            subprocess.run(["git", "commit", "-qm", "non-ascii"], cwd=root, check=True)
            subprocess.run(["git", "mv", "assets/keep.txt", "assets/kept.txt"], cwd=root, check=True)
            (root / "package.json").write_text("{}", encoding="utf-8")
            with patch.object(ci, "ROOT", root):
                files = ci.changed_files(base)
        self.assertIn("assets/café.png", files)
        self.assertIn("assets/kept.txt", files)
        self.assertIn("package.json", files)
        self.assertFalse(any("\\" in file or '"' in file for file in files), files)

    def test_release_push_paths_are_the_union_of_its_filters(self):
        union = set().union(*ci.RELEASE_FILTERS.values())
        self.assertEqual(first_paths("release.yml"), union)
        self.assertIn("scripts/ci/local_ci.py --release-filters", workflow_text("release.yml"))

    def test_python_tests_are_discovered_per_directory(self):
        commands = ci.GROUPS["agents"].commands
        for directory in ci.PYTHON_TEST_DIRS:
            self.assertIn(["python3", "-m", "unittest", "discover", "-s", f"scripts/{directory}", "-p", "test_*.py"],
                          commands)
            self.assertTrue(any((ROOT / "scripts" / directory).glob("test_*.py")), directory)
        self.assertIn(["python3", "-m", "unittest", "discover", "-s", "scripts", "-p", "test_*.py"], commands)
        self.assertTrue(any((ROOT / "scripts").glob("test_*.py")))
        self.assertFalse([c for c in commands if c[:3] == ["python3", "-m", "unittest"] and c[3] != "discover"])
        # Every test file in an uncovered directory must be a conscious exclusion, not an oversight.
        uncovered = {p.parent.name for p in (ROOT / "scripts").glob("*/test_*.py")} - set(ci.PYTHON_TEST_DIRS)
        self.assertEqual(uncovered, {"infra"})
        self.assertIn(["python3", "-m", "unittest", "discover", "-s", "scripts/infra", "-p", "test_*.py"],
                      ci.GROUPS["infra"].commands)

    def test_new_ci_scripts_trigger_the_agents_group(self):
        self.assertEqual(ci.groups_for(["scripts/ci/validation_status.py"]), ["agents"])
        self.assertEqual(ci.groups_for(["scripts/ci/test_validation_status.py"]), ["agents"])
        self.assertEqual(ci.groups_for(["scripts/ci/select_tests.dart"]), ["dart"])
        self.assertEqual(ci.groups_for(["scripts/setup/test_setupctl.py"]), ["agents"])
        self.assertEqual(ci.groups_for(["scripts/seed_global_catalog.py"]), ["agents"])
        self.assertEqual(ci.groups_for(["scripts/test_seed_global_catalog.py"]), ["agents"])
        self.assertTrue(ci.ci_filters(["scripts/seed_global_catalog.py"])["agents"])
        self.assertTrue(ci.ci_filters(["scripts/test_seed_global_catalog.py"])["agents"])
        self.assertTrue(ci.ci_filters(["lib/mock_data/global_products.dart"])["agents"])
        self.assertTrue(ci.ci_filters(["lib/constants/product_categories.dart"])["agents"])

    def test_workflows_run_the_same_commands(self):
        checks = workflow_text("pull-request.yml")
        for group in ("agents", "docs", "release"):
            self.assertIn(f"scripts/ci/local_ci.py --group {group}", checks)
        self.assertIn("scripts/ci/local_ci.py --group docs", workflow_text("release.yml"))
        self.assertIn(f"uses: ./{ci.DART_WORKFLOW}", checks)
        self.assertIn(f"uses: ./{ci.WEB_WORKFLOW}", checks)
        dart = (ROOT / ci.DART_WORKFLOW).read_text()
        for command in ci.GROUPS["dart"].commands:
            self.assertIn(" ".join(command), dart)
        self.assertIsNotNone(ci.ci_flutter_version())

    def test_make_check_bootstraps_and_cleans_up_after_failure(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(ci, "ROOT", Path(directory)):
            for item in ("lib", "assets"):
                (ci.ROOT / item).mkdir()
            analysis = ci.ROOT / "analysis_options.yaml"
            analysis.write_text("original")
            commands = []

            def run(command, **kwargs):
                commands.append(command)
                self.assertTrue((ci.ROOT / "assets/.env").is_file())
                if command == ["flutter", "pub", "get"]:
                    analysis.write_text("rewritten")
                else:
                    self.assertEqual(analysis.read_text(), "original")
                code = int(command[-1] == "_run-checks")
                return ci.subprocess.CompletedProcess(command, code, None)

            with patch.object(ci, "precheck", return_value=None), \
                    patch.object(ci, "dart_environment"), \
                    patch.object(ci.subprocess, "run", side_effect=run):
                self.assertEqual(ci.make_check("make"), 1)
            self.assertEqual(commands, [
                ["flutter", "pub", "get"],
                ["make", "build"],
                ["make", "-o", ".deps-stamp", "_run-checks"],
            ])
            for rel in ci.CI_FILES:
                self.assertFalse((ci.ROOT / rel).exists())
            self.assertEqual(analysis.read_text(), "original")

    def test_dart_workspace_preserves_existing_ci_files(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(ci, "ROOT", Path(directory)):
            (ci.ROOT / "assets").mkdir()
            dotenv = ci.ROOT / "assets/.env"
            dotenv.write_text("FOO=bar\n")
            with ci.dart_workspace():
                self.assertEqual(dotenv.read_text(), "FOO=bar\n")
            self.assertEqual(dotenv.read_text(), "FOO=bar\n")

    def test_flutter_bin_prints_selected_executable(self):
        import io
        from contextlib import redirect_stdout

        def fake_dart_env(env):
            env["PATH"] = "/pinned/flutter/bin:" + env.get("PATH", "")

        stdout = io.StringIO()
        with patch.object(ci, "dart_environment", side_effect=fake_dart_env), \
                patch.object(ci.shutil, "which", return_value="/pinned/flutter/bin/flutter") as which, \
                redirect_stdout(stdout):
            code = ci.main(["--flutter-bin"])
        self.assertEqual(code, 0)
        self.assertEqual(stdout.getvalue().strip(), "/pinned/flutter/bin/flutter")
        which.assert_called_once()
        self.assertTrue(which.call_args.kwargs["path"].startswith("/pinned/flutter/bin:"))

    def test_staged_runs_only_requested_groups_the_index_touches(self):
        cases = {
            ".github/workflows/agent-ops.yml": ["agents"],
            "mkdocs.yml": ["docs"],
            "scripts/docs/requirements.txt": ["docs"],
            "lib/main.dart": [],
        }
        for path, expected in cases.items():
            with self.subTest(path), tempfile.TemporaryDirectory() as directory, \
                    patch.object(ci, "STATE", Path(directory)), \
                    patch.object(ci, "git", return_value=path), \
                    patch.object(ci, "run_group", side_effect=lambda n, _: ci.Result(n, "PASS")) as run:
                code = ci.main(["--staged", "--no-cache", "--group", "agents", "--group", "docs"])
                self.assertEqual(code, 0)
                self.assertEqual([c.args[0] for c in run.call_args_list], expected)

    def test_skipped_requested_group_fails(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(ci, "STATE", Path(directory)), \
                patch.object(ci, "run_group", return_value=ci.Result("docs", "SKIP", "no tools")):
            self.assertEqual(ci.main(["--no-cache", "--group", "docs"]), 1)
            self.assertEqual(ci.main(["--no-cache", "--all"]), 0)

    def test_pre_push_runs_only_change_scoped_static_checks(self):
        files = ["lib/models/product_model.dart", "scripts/ci/local_ci.py",
                 ".github/workflows/pull-request.yml"]
        checks = dict(ci.pre_push_commands(files))
        self.assertEqual(list(checks), ["logs", "python", "actionlint", "format", "localization", "shape-sync"])
        self.assertEqual(checks["format"][-1], files[0])
        self.assertEqual(checks["python"][-1], files[1])
        self.assertEqual(checks["actionlint"], ["actionlint", files[2]])
        flat = " ".join(" ".join(command) for command in checks.values())
        for heavy in ("build_runner", "analyze", "unittest", "mkdocs", "run_tests", "flutter test"):
            self.assertNotIn(heavy, flat)

    def test_pre_push_scopes_checks_to_what_changed(self):
        self.assertEqual(ci.pre_push_commands([]), [])
        self.assertEqual([n for n, _ in ci.pre_push_commands(["README.md"])], ["logs"])
        self.assertEqual([n for n, _ in ci.pre_push_commands(["assets/translations/en-US.json"])],
                         ["logs", "localization"])
        self.assertEqual([n for n, _ in ci.pre_push_commands(["specs/schemas/product.schema.json"])],
                         ["logs", "shape-sync"])
        # A deleted Dart file is not formatted but can break keys or registry anchors.
        self.assertEqual([n for n, _ in ci.pre_push_commands(["lib/services/gone.dart"])],
                         ["logs", "localization", "shape-sync"])

    def test_pre_push_fails_on_a_dirty_tree_and_never_runs_groups(self):
        for status, expected in (("", 0), ("?? stray.txt", 1)):
            with self.subTest(status=status), tempfile.TemporaryDirectory() as directory, \
                    patch.object(ci, "STATE", Path(directory)), \
                    patch.object(ci, "changed_files", return_value=["README.md"]), \
                    patch.object(ci, "git", return_value=status), \
                    patch.object(ci, "run_fast_check", return_value=ci.Result("logs", "PASS")), \
                    patch.object(ci, "run_group") as run_group, \
                    patch.object(ci.sys.stdin, "isatty", return_value=True):
                self.assertEqual(ci.main(["--pre-push"]), expected)
                run_group.assert_not_called()

    def test_pre_push_skips_branch_deletions(self):
        zero = "0" * 40
        self.assertTrue(ci.pushes_only_deletions(f"(delete) {zero} refs/heads/x abc\n"))
        self.assertFalse(ci.pushes_only_deletions(f"refs/heads/x abc refs/heads/x {zero}\n"))


if __name__ == "__main__":
    unittest.main()
