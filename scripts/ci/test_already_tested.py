#!/usr/bin/env python3
"""Unit tests for scripts/ci/already_tested.sh."""

from __future__ import annotations

import json
import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/ci/already_tested.sh"


def _git(cwd: Path, *args: str) -> str:
    res = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, check=True)
    return res.stdout.strip()


class AlreadyTestedScriptTest(unittest.TestCase):
    def _init_repo(self, root: Path) -> tuple[Path, Path]:
        origin = root / "origin.git"
        work = root / "work"
        origin.mkdir()
        work.mkdir()
        _git(origin, "init", "--bare")
        _git(work, "init", "-b", "develop")
        _git(work, "config", "user.name", "Test")
        _git(work, "config", "user.email", "test@example.com")
        _git(work, "remote", "add", "origin", str(origin))
        return origin, work

    def _install_fake_gh(
        self,
        bin_dir: Path,
        runs_by_commit: dict[str, list[int]],
        jobs_by_run: dict[int, list[dict]],
        runs_by_branch: dict[str, list[dict]] | None = None,
    ) -> None:
        state_file = bin_dir / "gh_state.json"
        state_file.write_text(
            json.dumps(
                {
                    "runs_by_commit": runs_by_commit,
                    "runs_by_branch": runs_by_branch or {},
                    "jobs_by_run": {str(k): v for k, v in jobs_by_run.items()},
                }
            ),
            encoding="utf-8",
        )
        gh_path = bin_dir / "gh"
        gh_path.write_text(
            f"""#!/usr/bin/env python3
import json, sys
from pathlib import Path
state = json.loads(Path({str(state_file)!r}).read_text())
args = sys.argv[1:]
if args[:2] == ["run", "list"]:
    if "--branch" in args:
        branch = args[args.index("--branch") + 1]
        runs = state["runs_by_branch"].get(branch, [])
        if "--jq" in args:
            for r in runs:
                print(f"{{r['databaseId']}} {{r['headSha']}}")
        else:
            print(json.dumps(runs))
    else:
        commit = args[args.index("--commit") + 1] if "--commit" in args else ""
        ids = state["runs_by_commit"].get(commit, [])
        if "--jq" in args:
            jq = args[args.index("--jq") + 1]
            if jq == "length":
                print(len(ids))
            else:
                for i in ids:
                    print(i)
        else:
            print(json.dumps([{{"databaseId": i}} for i in ids]))
elif args[:1] == ["api"]:
    endpoint = args[1]
    parts = endpoint.split("/")
    if len(parts) >= 6 and parts[4] == "runs" and parts[6] == "jobs":
        run_id = parts[5]
        jobs = state["jobs_by_run"].get(run_id, [])
        print(json.dumps({{"jobs": jobs}}))
    else:
        print("{{}}")
else:
    sys.exit(1)
""",
            encoding="utf-8",
        )
        gh_path.chmod(gh_path.stat().st_mode | stat.S_IXUSR)

    def _run_script(
        self,
        work: Path,
        bin_dir: Path,
        event_name: str,
        event_payload: dict,
        args: list[str],
        sha: str = "",
    ) -> dict[str, str]:
        event_file = work / ".event.json"
        out_file = work / ".github_output"
        event_file.write_text(json.dumps(event_payload), encoding="utf-8")
        out_file.write_text("", encoding="utf-8")
        env = {
            **os.environ,
            "PATH": f"{bin_dir}:{os.environ['PATH']}",
            "GITHUB_REPOSITORY": "owner/repo",
            "GITHUB_EVENT_NAME": event_name,
            "GITHUB_EVENT_PATH": str(event_file),
            "GITHUB_OUTPUT": str(out_file),
            "GITHUB_SHA": sha,
            "GH_TOKEN": "fake",
        }
        subprocess.run(["bash", str(SCRIPT), *args], cwd=work, env=env, check=True, capture_output=True, text=True)
        outputs: dict[str, str] = {}
        for line in out_file.read_text(encoding="utf-8").splitlines():
            if "=" in line:
                k, v = line.split("=", 1)
                outputs[k] = v
        return outputs

    def test_per_target_synchronize_skips_untouched_targets_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _, work = self._init_repo(root)
            bin_dir = root / "bin"
            bin_dir.mkdir()

            (work / "lib").mkdir()
            (work / "web").mkdir()
            (work / "android").mkdir()
            (work / "lib/app.dart").write_text("void main() {}\n", encoding="utf-8")
            (work / "web/index.html").write_text("<html>v1</html>\n", encoding="utf-8")
            (work / "android/build.gradle").write_text("// v1\n", encoding="utf-8")
            _git(work, "add", ".")
            _git(work, "commit", "-m", "initial")
            before = _git(work, "rev-parse", "HEAD")
            _git(work, "push", "origin", "develop")

            # Rebased commit changes only web/index.html (e.g. web-only PR merged to develop)
            (work / "web/index.html").write_text("<html>v2</html>\n", encoding="utf-8")
            _git(work, "add", "web/index.html")
            _git(work, "commit", "-m", "web tweak")
            new = _git(work, "rev-parse", "HEAD")
            _git(work, "push", "origin", "develop")

            self._install_fake_gh(
                bin_dir,
                runs_by_commit={before: [101]},
                jobs_by_run={101: [{"name": "Validation status (result)", "conclusion": "success"}]},
            )
            outputs = self._run_script(
                work,
                bin_dir,
                "pull_request",
                {"action": "synchronize", "before": before, "pull_request": {"head": {"sha": new}}},
                [
                    "--push-only-reuse",
                    "--require-job", r"Validation status \(result\)",
                    "--target", "web:lib,web",
                    "--target", "android:lib,android",
                    "--target", "rules:firestore.rules",
                    "pull-request.yml",
                    "lib", "web", "android", "firestore.rules",
                ],
            )
            self.assertEqual(outputs["skip"], "false")
            self.assertEqual(outputs["skip_web"], "false")
            self.assertEqual(outputs["skip_android"], "true")
            self.assertEqual(outputs["skip_rules"], "true")

    def test_require_job_fails_closed_on_hold_only_prior_run(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _, work = self._init_repo(root)
            bin_dir = root / "bin"
            bin_dir.mkdir()

            (work / "docs").mkdir()
            (work / "docs/a.md").write_text("v1\n", encoding="utf-8")
            _git(work, "add", ".")
            _git(work, "commit", "-m", "v1")
            before = _git(work, "rev-parse", "HEAD")
            _git(work, "push", "origin", "develop")

            (work / "docs/a.md").write_text("v2\n", encoding="utf-8")
            _git(work, "add", ".")
            _git(work, "commit", "-m", "v2")
            new = _git(work, "rev-parse", "HEAD")
            _git(work, "push", "origin", "develop")

            # Prior run only executed Validation status (hold), NOT Validation status (result)
            self._install_fake_gh(
                bin_dir,
                runs_by_commit={before: [202]},
                jobs_by_run={202: [{"name": "Validation status (hold)", "conclusion": "success"}]},
            )
            outputs = self._run_script(
                work,
                bin_dir,
                "pull_request",
                {"action": "synchronize", "before": before, "pull_request": {"head": {"sha": new}}},
                [
                    "--require-job", r"Validation status \(result\)",
                    "--target", "web:lib,web",
                    "pull-request.yml",
                    "lib", "web",
                ],
            )
            self.assertEqual(outputs["skip"], "false")
            self.assertEqual(outputs["skip_web"], "false")

    def _two_heads(self, root: Path) -> tuple[Path, str, str]:
        _, work = self._init_repo(root)
        (work / "lib").mkdir()
        (work / "docs").mkdir()
        (work / "lib/app.dart").write_text("void main() {}\n", encoding="utf-8")
        (work / "docs/a.md").write_text("v1\n", encoding="utf-8")
        _git(work, "add", ".")
        _git(work, "commit", "-m", "v1")
        before = _git(work, "rev-parse", "HEAD")
        (work / "docs/a.md").write_text("v2\n", encoding="utf-8")
        _git(work, "add", ".")
        _git(work, "commit", "-m", "v2")
        new = _git(work, "rev-parse", "HEAD")
        _git(work, "push", "origin", "develop")
        return work, before, new

    PR_REUSE = ["--require-job", "^Check & Test$", "--substantive-job", "^Check & Test$",
                "--pr-reuse-jobs", "^(Decide whether to run CI|Check & Test)$", "pull-request.yml", "lib"]

    def test_pr_reuse_jobs_follow_the_suite_not_the_whole_run(self):
        # #496: one workflow holds several suites; only the gate and Check & Test decide reuse.
        cases = {
            "reused through an earlier reuse (skipped)": (
                [("Decide whether to run CI", "success"), ("Check & Test", "skipped"),
                 ("Build documentation", "failure")], "true"),
            "green": ([("Decide whether to run CI", "success"), ("Check & Test", "success")], "true"),
            "failed suite": ([("Decide whether to run CI", "success"), ("Check & Test", "failure")], "false"),
            "failed preflight": ([("Decide whether to run CI", "failure"), ("Check & Test", "skipped")], "false"),
            "cancelled suite": ([("Decide whether to run CI", "success"), ("Check & Test", "cancelled")], "false"),
            "no gate job": ([("Build documentation", "success")], "false"),
        }
        for label, (jobs, expected) in cases.items():
            with self.subTest(label), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                work, before, new = self._two_heads(root)
                bin_dir = root / "bin"
                bin_dir.mkdir()
                self._install_fake_gh(
                    bin_dir,
                    runs_by_commit={before: [301]},
                    jobs_by_run={301: [{"name": n, "conclusion": c} for n, c in jobs]},
                )
                outputs = self._run_script(
                    work, bin_dir, "pull_request",
                    {"action": "synchronize", "before": before, "pull_request": {"head": {"sha": new}}},
                    self.PR_REUSE,
                )
                self.assertEqual(outputs["skip"], expected)

    def test_push_reuse_requires_the_suites_own_job(self):
        # A green docs-only job in the shared workflow must not stand in for Check & Test.
        for jobs, expected in (
            ([("Decide whether to run CI", "success"), ("Build documentation", "success")], "false"),
            ([("Decide whether to run CI", "success"), ("Check & Test", "success")], "true"),
        ):
            with self.subTest(jobs=jobs), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                work, _, new = self._two_heads(root)
                bin_dir = root / "bin"
                bin_dir.mkdir()
                self._install_fake_gh(
                    bin_dir,
                    runs_by_commit={new: [401]},
                    jobs_by_run={401: [{"name": n, "conclusion": c} for n, c in jobs]},
                )
                outputs = self._run_script(
                    work, bin_dir, "push", {"before": new, "commits": []},
                    ["--require-job", "^Check & Test$", "--substantive-job", "^Check & Test$",
                     "pull-request.yml", "lib"],
                    sha=new,
                )
                self.assertEqual(outputs["skip"], expected)

    def test_push_only_reuse_needs_a_validation_target_job(self):
        for jobs, expected in (
            ([("Validation status (result)", "success"), ("Check & Test", "success")], "false"),
            # A smoke run on the same SHA is not evidence for a release push.
            ([("Validation status (result)", "success"), ("Web validation / Web smoke test", "success")], "false"),
            ([("Validation status (result)", "success"), ("Web validation / Web full E2E", "success")], "true"),
        ):
            with self.subTest(jobs=jobs), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                work, _, new = self._two_heads(root)
                bin_dir = root / "bin"
                bin_dir.mkdir()
                self._install_fake_gh(
                    bin_dir,
                    runs_by_commit={new: [501]},
                    jobs_by_run={501: [{"name": n, "conclusion": c} for n, c in jobs]},
                )
                outputs = self._run_script(
                    work, bin_dir, "push", {"before": new, "commits": []},
                    ["--push-only-reuse", "--require-job", r"Validation status \(result\)",
                     "--substantive-job", "^(Web smoke test|Android smoke test|Firestore security rules)$",
                     "--target", "web:lib", "pull-request.yml", "lib"],
                    sha=new,
                )
                self.assertEqual(outputs["skip"], expected)

    def test_push_only_reuse_is_decided_per_validation_target(self):
        # A prior push run that passed Web but never ran rules may reuse Web only;
        # its overall pass must not set skip for a target it did not test (#531).
        for jobs, expected in (
            (
                {"Validation status (result)": "success", "Web validation / Web full E2E": "success",
                 "Web validation / Firestore security rules": "skipped"},
                {"skip": "false", "skip_web": "true", "skip_rules": "false"},
            ),
            (
                {"Validation status (result)": "success", "Web validation / Web full E2E": "success",
                 "Web validation / Firestore security rules": "success"},
                {"skip": "true", "skip_web": "true", "skip_rules": "true"},
            ),
            (
                {"Validation status (result)": "success", "Web validation / Firestore security rules": "success"},
                {"skip": "false", "skip_web": "false", "skip_rules": "true"},
            ),
        ):
            with self.subTest(expected=expected), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                work, _, new = self._two_heads(root)
                bin_dir = root / "bin"
                bin_dir.mkdir()
                self._install_fake_gh(
                    bin_dir,
                    runs_by_commit={new: [601]},
                    jobs_by_run={601: [{"name": name, "conclusion": conclusion}
                                       for name, conclusion in jobs.items()]},
                )
                outputs = self._run_script(
                    work, bin_dir, "push", {"before": new, "commits": []},
                    ["--push-only-reuse", "--require-job", r"Validation status \(result\)",
                     "--substantive-job", "^(Web smoke test|Android smoke test|Firestore security rules)$",
                     "--target", "web:lib", "--target", "rules:firestore.rules",
                     "pull-request.yml", "lib"],
                    sha=new,
                )
                self.assertEqual(outputs, expected)

    def test_full_dart_reuse_rejects_relational_runs(self):
        for name, expected in (("Dart checks / Relational Dart suite", "false"),
                               ("Dart checks / Full Dart suite", "true")):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                work, _, new = self._two_heads(root)
                bin_dir = root / "bin"
                bin_dir.mkdir()
                self._install_fake_gh(
                    bin_dir,
                    runs_by_commit={new: [701]},
                    jobs_by_run={701: [{"name": name, "conclusion": "success"},
                                       {"name": "Check & Test", "conclusion": "success"}]},
                )
                outputs = self._run_script(
                    work, bin_dir, "push", {"before": new, "commits": []},
                    ["--push-only-reuse", "--require-job", "(^| / )Full Dart suite$",
                     "--substantive-job", "(^| / )Full Dart suite$", "pull-request.yml"],
                    sha=new,
                )
                self.assertEqual(outputs["skip"], expected)

    def test_speculative_train_tree_match_skips_pr_and_fails_closed_on_fork_or_mismatch(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _, work = self._init_repo(root)
            bin_dir = root / "bin"
            bin_dir.mkdir()

            (work / "lib").mkdir()
            (work / "lib/app.dart").write_text("void main() {}\n", encoding="utf-8")
            _git(work, "add", ".")
            _git(work, "commit", "-m", "base")
            base = _git(work, "rev-parse", "HEAD")
            _git(work, "push", "origin", "develop")

            # Speculative train commit with exact tree of PR #42 after rebase
            _git(work, "checkout", "-q", "-B", "merge-train/pr-42", base)
            (work / "lib/app.dart").write_text("void main() { print('v2'); }\n", encoding="utf-8")
            _git(work, "add", "lib/app.dart")
            _git(work, "commit", "-m", "speculative train replay")
            train_sha = _git(work, "rev-parse", "HEAD")
            _git(work, "push", "origin", "merge-train/pr-42")

            # Actual PR #42 rebased commit: different commit SHA, identical tree!
            _git(work, "checkout", "-q", "-B", "pr-42", base)
            (work / "lib/app.dart").write_text("void main() { print('v2'); }\n", encoding="utf-8")
            _git(work, "add", "lib/app.dart")
            _git(work, "commit", "-m", "rebased PR #42 commit")
            pr_sha = _git(work, "rev-parse", "HEAD")
            self.assertNotEqual(train_sha, pr_sha)
            self.assertEqual(_git(work, "rev-parse", f"{train_sha}^{{tree}}"), _git(work, "rev-parse", f"{pr_sha}^{{tree}}"))
            _git(work, "push", "origin", "pr-42")

            # Different tree commit for mismatch test
            _git(work, "checkout", "-q", "-B", "pr-42-diff", base)
            (work / "lib/app.dart").write_text("void main() { print('v3'); }\n", encoding="utf-8")
            _git(work, "add", "lib/app.dart")
            _git(work, "commit", "-m", "different tree")
            diff_sha = _git(work, "rev-parse", "HEAD")
            _git(work, "push", "origin", "pr-42-diff")

            val_args = [
                "--push-only-reuse",
                "--require-job", r"Validation status \(result\)",
                "--target", "web:lib,web",
                "--target", "android:lib,android",
                "pull-request.yml",
                "lib", "web", "android",
            ]

            # 0. Skipped-only validation train run (only control/status jobs, no substantive job) -> MUST fail closed
            self._install_fake_gh(
                bin_dir,
                runs_by_commit={},
                runs_by_branch={"merge-train/pr-42": [{"databaseId": 302, "headSha": train_sha}]},
                jobs_by_run={
                    302: [
                        {"name": "Detect changed areas", "conclusion": "success"},
                        {"name": "Validation status (result)", "conclusion": "success"},
                    ]
                },
            )
            skipped_only_out = self._run_script(
                work,
                bin_dir,
                "pull_request",
                {
                    "action": "synchronize",
                    "before": base,
                    "pull_request": {
                        "number": 42,
                        "head": {"sha": pr_sha, "repo": {"full_name": "owner/repo"}},
                    },
                },
                val_args,
            )
            self.assertEqual(skipped_only_out["skip"], "false")
            self.assertEqual(skipped_only_out["skip_web"], "false")
            self.assertEqual(skipped_only_out["skip_android"], "false")

            self._install_fake_gh(
                bin_dir,
                runs_by_commit={},
                runs_by_branch={"merge-train/pr-42": [{"databaseId": 303, "headSha": train_sha}]},
                jobs_by_run={
                    303: [
                        {"name": "Detect changed areas", "conclusion": "success"},
                        {"name": "Android smoke test", "conclusion": "success"},
                        {"name": "Validation status (result)", "conclusion": "success"},
                    ]
                },
            )

            # 1. Trusted same-repo PR with matching tree and substantive executed job -> skip=true for all targets!
            ok_out = self._run_script(
                work,
                bin_dir,
                "pull_request",
                {
                    "action": "synchronize",
                    "before": base,
                    "pull_request": {
                        "number": 42,
                        "head": {"sha": pr_sha, "repo": {"full_name": "owner/repo"}},
                    },
                },
                val_args,
            )
            self.assertEqual(ok_out["skip"], "true")
            self.assertEqual(ok_out["skip_web"], "true")
            self.assertEqual(ok_out["skip_android"], "true")

            # 2. Fork PR with identical tree -> MUST fail closed (skip=false)
            fork_out = self._run_script(
                work,
                bin_dir,
                "pull_request",
                {
                    "action": "synchronize",
                    "before": base,
                    "pull_request": {
                        "number": 42,
                        "head": {"sha": pr_sha, "repo": {"full_name": "attacker/repo"}},
                    },
                },
                val_args,
            )
            self.assertEqual(fork_out["skip"], "false")
            self.assertEqual(fork_out["skip_web"], "false")

            # 3. Same-repo PR with different tree -> MUST fail closed (skip=false)
            diff_out = self._run_script(
                work,
                bin_dir,
                "pull_request",
                {
                    "action": "synchronize",
                    "before": base,
                    "pull_request": {
                        "number": 42,
                        "head": {"sha": diff_sha, "repo": {"full_name": "owner/repo"}},
                    },
                },
                val_args,
            )
            self.assertEqual(diff_out["skip"], "false")

            # 4. pull-request.yml skipped-only run (only "Decide whether to run CI") -> fail closed
            self._install_fake_gh(
                bin_dir,
                runs_by_commit={},
                runs_by_branch={"merge-train/pr-42": [{"databaseId": 404, "headSha": train_sha}]},
                jobs_by_run={404: [{"name": "Decide whether to run CI", "conclusion": "success"}]},
            )
            ci_skipped_out = self._run_script(
                work,
                bin_dir,
                "pull_request",
                {
                    "action": "synchronize",
                    "before": base,
                    "pull_request": {
                        "number": 42,
                        "head": {"sha": pr_sha, "repo": {"full_name": "owner/repo"}},
                    },
                },
                ["pull-request.yml", "lib"],
            )
            self.assertEqual(ci_skipped_out["skip"], "false")

            # 5. pull-request.yml executed run ("Check & Test") -> skip=true
            self._install_fake_gh(
                bin_dir,
                runs_by_commit={},
                runs_by_branch={"merge-train/pr-42": [{"databaseId": 405, "headSha": train_sha}]},
                jobs_by_run={
                    405: [
                        {"name": "Decide whether to run CI", "conclusion": "success"},
                        {"name": "Check & Test", "conclusion": "success"},
                    ]
                },
            )
            ci_ok_out = self._run_script(
                work,
                bin_dir,
                "pull_request",
                {
                    "action": "synchronize",
                    "before": base,
                    "pull_request": {
                        "number": 42,
                        "head": {"sha": pr_sha, "repo": {"full_name": "owner/repo"}},
                    },
                },
                ["pull-request.yml", "lib"],
            )
            self.assertEqual(ci_ok_out["skip"], "true")


if __name__ == "__main__":
    unittest.main()

