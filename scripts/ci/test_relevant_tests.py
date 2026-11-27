#!/usr/bin/env python3
import importlib.util
import io
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("relevant_tests", ROOT / "scripts/ci/relevant_tests.py")
rt = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules["relevant_tests"] = rt
spec.loader.exec_module(rt)

TREE = {
    "pubspec.yaml": "name: app\n",
    "lib/models/item.dart": "class Item {}\n",
    "lib/services/item_service.dart": "import '../models/item.dart';\n",
    "lib/services/other.dart": "",
    "lib/io.dart": "",
    "lib/web.dart": "",
    "lib/platform.dart": "export 'io.dart'\n    if (dart.library.html) 'web.dart';\n",
    "test/helpers/fakes.dart": "import 'package:app/services/item_service.dart';\n",
    "test/uses_fakes_test.dart": "import 'helpers/fakes.dart';\n",
    "test/platform_test.dart": "import 'package:app/platform.dart';\n",
    "test/services/other_test.dart": "import 'package:flutter_test/flutter_test.dart';\n",
    "packages/core/pubspec.yaml": "name: core\n",
    "packages/core/lib/core.dart": "",
    "packages/core/test/core_test.dart": "import 'package:core/core.dart';\n",
    "scripts/ci/thing.py": "",
    "scripts/ci/helper.sh": "",
    "scripts/ci/test_thing.py": "",
    "scripts/ci/test_importer.py": "import thing\n",
    "scripts/ci/test_workflow.py": "read('ci.yml')\nrun('helper.sh')\n",
    "scripts/ci/test_unrelated.py": "read('other-ci.yml')\n",
    "scripts/release/prepare_test.py": "",
    "test/e2e/tests/app.smoke.spec.ts": "",
    "test/e2e/tests/about.spec.ts": "",
    "test/e2e/tests/collections.spec.ts": "",
    "test/e2e/tests/landing.spec.ts": "",
}


class RelevantTestsTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name).resolve()
        for name, content in TREE.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
        patcher = patch.object(rt, "ROOT", self.root)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_dart_selection_follows_the_transitive_import_closure(self):
        self.assertEqual(rt.dart_tests(["lib/models/item.dart"]), {"": ["test/uses_fakes_test.dart"]})
        self.assertEqual(rt.dart_tests(["lib/web.dart"]), {"": ["test/platform_test.dart"]})
        self.assertEqual(rt.dart_tests(["test/platform_test.dart"]), {"": ["test/platform_test.dart"]})

    def test_dart_selection_matches_names_and_deleted_files(self):
        self.assertEqual(rt.dart_tests(["lib/services/other.dart"]), {"": ["test/services/other_test.dart"]})
        (self.root / "lib/models/item.dart").unlink()
        self.assertEqual(rt.dart_tests(["lib/models/item.dart"]), {"": ["test/uses_fakes_test.dart"]})

    def test_package_tests_run_inside_their_package(self):
        for changed in ("packages/core/lib/core.dart", "packages/core/pubspec.yaml"):
            with self.subTest(changed):
                self.assertEqual(rt.commands_for([changed]),
                                 [rt.Command(("dart", "test", "test/core_test.dart"), "packages/core")])

    def test_python_selection_uses_names_imports_and_references(self):
        self.assertEqual(rt.python_tests(["scripts/ci/thing.py"]),
                         ["scripts/ci/test_importer.py", "scripts/ci/test_thing.py"])
        self.assertEqual(rt.python_tests([".github/workflows/ci.yml"]), ["scripts/ci/test_workflow.py"])
        self.assertEqual(rt.python_tests(["scripts/ci/helper.sh"]), ["scripts/ci/test_workflow.py"])
        self.assertEqual(rt.python_tests(["scripts/release/prepare_test.py"]), ["scripts/release/prepare_test.py"])
        self.assertEqual(rt.python_tests([".agents/events/2026/11/x.jsonl", "README.md"]), [])

    def test_playwright_selection(self):
        self.assertEqual(rt.playwright_specs(["test/e2e/tests/about.spec.ts"]), ["tests/about.spec.ts"])
        self.assertEqual(len(rt.playwright_specs(["test/e2e/tests/helpers.ts"])), 4)
        self.assertEqual(rt.playwright_specs(["web/about/index.html"]), ["tests/about.spec.ts"])
        self.assertEqual(rt.playwright_specs(["web/sw.js"]),
                         ["tests/app.smoke.spec.ts", "tests/landing.spec.ts"])
        self.assertEqual(rt.playwright_specs(["lib/views/inventory_view.dart"]),
                         ["tests/app.smoke.spec.ts", "tests/collections.spec.ts"])
        self.assertEqual(rt.playwright_specs(["scripts/ci/thing.py", "test/platform_test.dart"]), [])

    def test_every_mapped_spec_exists_in_the_repository(self):
        specs = {p.name for p in (ROOT / rt.E2E / "tests").glob("*.spec.ts")}
        self.assertLessEqual({rt.SMOKE_SPEC, *rt.SPEC_KEYWORDS}, specs)

    def test_print_is_the_default_and_never_runs(self):
        out = io.StringIO()
        with patch.object(rt.Path, "cwd", return_value=self.root), \
                patch.object(rt, "run") as run, redirect_stdout(out):
            self.assertEqual(rt.main(["lib/models/item.dart"]), 0)
        run.assert_not_called()
        self.assertIn("flutter test test/uses_fakes_test.dart", out.getvalue())
        self.assertNotIn("--coverage", out.getvalue())

    def test_run_executes_every_command_and_reports_failure(self):
        commands = [rt.Command(("python3", "a")), rt.Command(("python3", "b"))]
        results = [rt.subprocess.CompletedProcess([], 1), rt.subprocess.CompletedProcess([], 0)]
        with patch.object(rt.subprocess, "run", side_effect=results) as run, \
                redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
            self.assertEqual(rt.run(commands), 1)
        self.assertEqual(run.call_count, 2)

    def test_paths_outside_the_repository_are_rejected(self):
        with self.assertRaises(ValueError):
            rt.input_files(["/etc/hosts"], "origin/develop")


if __name__ == "__main__":
    unittest.main()
