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

    def _install_fake_gh(self, bin_dir: Path, runs_by_commit: dict[str, list[int]], jobs_by_run: dict[int, list[dict]]) -> None:
        state_file = bin_dir / "gh_state.json"
        state_file.write_text(
            json.dumps({"runs_by_commit": runs_by_commit, "jobs_by_run": {str(k): v for k, v in jobs_by_run.items()}}),
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
                    "validation.yml",
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
                    "validation.yml",
                    "lib", "web",
                ],
            )
            self.assertEqual(outputs["skip"], "false")
            self.assertEqual(outputs["skip_web"], "false")


if __name__ == "__main__":
    unittest.main()
