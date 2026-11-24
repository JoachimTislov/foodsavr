#!/usr/bin/env python3
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from unittest.mock import patch, call

sys.path.insert(0, str(Path(__file__).resolve().parent))
import humanctl as hc  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]


class MenuResolvesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.registry = hc.load_registry()
        cls.entries = hc.all_entries(cls.registry)
        cls.targets = hc.make_targets()

    def test_every_entry_resolves_to_a_make_target_or_script(self):
        self.assertEqual(hc.check_entries(self.registry, self.entries, self.targets), [])

    def test_catch_all_rule_is_not_a_target(self):
        self.assertNotIn("%", self.targets)
        self.assertNotIn("definitely-not-a-target", self.targets)

    def test_every_script_under_scripts_human_is_in_the_menu(self):
        on_disk = {p.relative_to(ROOT).as_posix() for p in (ROOT / "scripts/human").glob("*/*.sh")}
        in_menu = {e.target for e in self.entries if e.kind == "script"}
        self.assertEqual(on_disk, in_menu)

    def test_every_bypass_target_is_in_the_menu(self):
        listed = {e.target for e in self.entries if e.kind == "make"}
        for target in hc.declared_bypass_targets():
            self.assertTrue(target in listed or target in self.registry.excluded, target)

    def test_named_entries_exist(self):
        listed = {e.target for e in self.entries if e.kind == "make"}
        required = {
            "setup", "infra-github-apply", "infra-gcp-apply", "secrets-rotate", "pr-merge", "validate", "promote",
            "deploy-web", "deploy-firestore-rules", "release-candidate", "android-apk", "docs-publish",
            "deployment-poll", "monitor-web", "merge-gate",
        }
        self.assertEqual(required - listed, set())

    def test_list_output_names_every_entry(self):
        text = hc.render_list(self.registry, self.entries)
        for entry in self.entries:
            self.assertIn(entry.id, text)

    def test_list_runs_without_a_terminal(self):
        out = subprocess.run(["make", "human", "LIST=1"], cwd=ROOT, capture_output=True, text=True, stdin=subprocess.DEVNULL)
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("make pr-merge PR=", out.stdout)

    def test_interactive_menu_refuses_without_a_terminal(self):
        out = subprocess.run(["python3", str(ROOT / "scripts/human/humanctl.py")], capture_output=True, text=True,
                             stdin=subprocess.DEVNULL)
        self.assertEqual(out.returncode, 2)
        self.assertIn("interactive only", out.stderr)


class CheckEntriesTest(unittest.TestCase):
    def registry(self):
        return hc.Registry([("g", "Group")], [])

    def test_missing_make_target_and_script_are_reported(self):
        entries = [
            hc.Entry("a", "g", "A", "make", "gone"),
            hc.Entry("b", "g", "B", "script", "scripts/human/none/missing.sh"),
            hc.Entry("c", "nogroup", "C", "make", "present"),
            hc.Entry("a", "g", "dup", "make", "present"),
        ]
        errors = hc.check_entries(self.registry(), entries, {"present"})
        text = "\n".join(errors)
        self.assertIn("make target 'gone' does not exist", text)
        self.assertIn("script scripts/human/none/missing.sh does not exist", text)
        self.assertIn("unknown group nogroup", text)
        self.assertIn("duplicate id a", text)

    def test_unlisted_bypass_target_is_reported(self):
        errors = hc.check_entries(self.registry(), [], set())
        self.assertTrue(any("is not in scripts/human/menu.toml" in e for e in errors))

    def test_excluded_bypass_target_is_accepted(self):
        registry = hc.Registry([("g", "Group")], [], excluded=hc.declared_bypass_targets())
        self.assertEqual(hc.check_entries(registry, [], set()), [])


class ParsingTest(unittest.TestCase):
    def test_confirmed_apply_overrides_dry_run_with_an_empty_assignment(self):
        entry = hc.Entry("x", "g", "X", "make", "secrets-rotate", dry_assign="DRY_RUN=1", apply_assign="DRY_RUN=")
        with patch.object(hc, "ask", return_value="yes"), patch.object(hc.subprocess, "run") as run:
            run.return_value.returncode = 0
            with redirect_stdout(StringIO()):
                hc.run_entry(entry)
        self.assertEqual(run.call_args_list, [
            call(["make", "secrets-rotate", "DRY_RUN=1"], cwd=hc.ROOT),
            call(["make", "secrets-rotate", "DRY_RUN="], cwd=hc.ROOT),
        ])

    def test_script_header_with_continuation(self):
        text = "#!/usr/bin/env bash\n#\n# Intent: login\n# Domain: firebase\n# Area: cli-token\n# Secrets: X\n# Why human: needs\n#   a browser.\n#\nset -e\n"
        header = hc.script_header(text)
        self.assertEqual(header["Intent"], "login")
        self.assertEqual(header["Why human"], "needs a browser.")

    def test_discovery_reads_headers(self):
        with tempfile.TemporaryDirectory() as tmp:
            human = Path(tmp) / "scripts/human"
            (human / "dom").mkdir(parents=True)
            (human / "dom/rotate-key.sh").write_text("#!/bin/bash\n# Intent: rotate\n# Domain: dom\n# Area: key\n# Why human: console\n")
            (entry,) = hc.discover_scripts(human, Path(tmp))
        self.assertEqual(entry.id, "dom/rotate-key")
        self.assertEqual(entry.target, "scripts/human/dom/rotate-key.sh")
        self.assertEqual(entry.needs, "console")

    def test_command_building(self):
        make = hc.Entry("x", "g", "X", "make", "pr-merge")
        self.assertEqual(hc.command(make, {"PR": "7", "APPLY": ""}, ("APPLY=1",)), ["make", "pr-merge", "PR=7", "APPLY=1"])
        script = hc.Entry("y", "g", "Y", "script", "scripts/human/a/b.sh", args="--role release-gate")
        self.assertEqual(hc.command(script, {}), ["bash", "scripts/human/a/b.sh", "--role", "release-gate"])


if __name__ == "__main__":
    unittest.main()
