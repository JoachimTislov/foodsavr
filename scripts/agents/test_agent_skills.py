#!/usr/bin/env python3
"""Tests for the canonical skill catalog and its harness projections."""

from __future__ import annotations

import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_skills  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def skill(name: str, audience: str, extra: str = "", body: str = "Body.\n") -> str:
    user_only = "disable-model-invocation: true\n" if audience == "human" else ""
    return f"---\nname: {name}\ndescription: \"Does {name}.\"\n{user_only}metadata:\n  audience: {audience}\n{extra}---\n\n{body}"


class SkillCatalogTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        write(self.root / ".agents/skills/build/SKILL.md", skill("build", "agent", body="Call the Skill tool with \"plan\".\n"))
        write(self.root / ".agents/skills/build/refs/notes.md", "Notes.\n")
        write(self.root / ".agents/skills/plan/SKILL.md", skill("plan", "agent", "  interactive: true\n"))
        write(self.root / ".agents/skills/retro/SKILL.md", skill("retro", "human"))
        write(self.root / "AGENTS.md", "See [catalog](.agents/skills/README.md).\n")
        os.symlink("AGENTS.md", self.root / "CLAUDE.md")
        os.symlink("AGENTS.md", self.root / "GEMINI.md")

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def catalog(self) -> list[agent_skills.Skill]:
        return agent_skills.discover(self.root)

    def test_sync_projects_by_audience_and_check_is_clean(self) -> None:
        skills = self.catalog()
        self.assertEqual([], agent_skills.validation_errors(self.root, skills))
        agent_skills.sync(self.root, skills)
        self.assertEqual([], agent_skills.drift(self.root, skills))
        self.assertEqual([], agent_skills.context_errors(self.root))
        claude = self.root / ".claude/skills/build/refs/notes.md"
        self.assertTrue(claude.is_symlink())
        self.assertEqual("Notes.\n", claude.read_text(encoding="utf-8"))
        self.assertTrue((self.root / ".claude/skills/retro/SKILL.md").is_symlink())
        self.assertFalse((self.root / ".gemini/skills/retro").exists())
        self.assertIn(".agents/skills/retro/SKILL.md", (self.root / ".gemini/commands/retro.toml").read_text(encoding="utf-8"))
        self.assertIn("allow_implicit_invocation: false", (self.root / ".agents/skills/retro/agents/openai.yaml").read_text(encoding="utf-8"))
        self.assertFalse((self.root / ".agents/skills/build/agents/openai.yaml").exists())
        readme = (self.root / ".agents/skills/README.md").read_text(encoding="utf-8")
        self.assertLess(readme.index("[build]"), readme.index("## Human skills"))
        self.assertGreater(readme.index("`/retro`"), readme.index("## Human skills"))

    def test_path_scoped_skills_project_to_copilot_instructions(self) -> None:
        write(self.root / ".agents/skills/dart/SKILL.md", skill("dart", "agent", '  paths: "lib/**"\n', body="See [spec](../../../specs/a.md).\n"))
        skills = self.catalog()
        agent_skills.sync(self.root, skills)
        scoped = (self.root / ".github/instructions/dart.instructions.md").read_text(encoding="utf-8")
        self.assertTrue(scoped.startswith('---\napplyTo: "lib/**"\n---'))
        self.assertIn("](../../specs/a.md)", scoped)
        self.assertIn("instructions/dart.instructions.md", (self.root / ".github/copilot-instructions.md").read_text(encoding="utf-8"))
        self.assertFalse((self.root / ".github/instructions/build.instructions.md").exists())
        self.assertEqual([], agent_skills.drift(self.root, skills))

    def test_drift_detects_stale_and_orphaned_projections(self) -> None:
        skills = self.catalog()
        agent_skills.sync(self.root, skills)
        write(self.root / ".agents/skills/build/extra.md", "New.\n")
        os.symlink("../../../nowhere", self.root / ".claude/skills/orphan")
        problems = "\n".join(agent_skills.drift(self.root, self.catalog()))
        self.assertIn(".claude/skills/build/extra.md: projection missing or stale", problems)
        self.assertIn(".claude/skills/orphan: not derived from a skill", problems)

    def test_validation_rejects_mislabelled_and_dangling_skills(self) -> None:
        write(self.root / ".agents/skills/bad/SKILL.md", skill("bad", "human").replace("disable-model-invocation: true\n", "") + "Use the `gone` skill.\n")
        errors = "\n".join(agent_skills.validation_errors(self.root, self.catalog()))
        self.assertIn("human skills set disable-model-invocation: true", errors)
        self.assertIn("references unknown skill gone", errors)

    def test_workflows_accept_only_autonomous_agent_skills(self) -> None:
        errors = agent_skills.workflow_skill_errors(self.root, ["build", "plan", "retro", "missing"])
        self.assertEqual([
            "skill plan needs a human in the loop and cannot run in a workflow",
            "skill retro is human-invoked and cannot run in a workflow",
            "unknown skill: missing",
        ], errors)

    def test_context_requires_symlinked_entrypoints(self) -> None:
        (self.root / "GEMINI.md").unlink()
        write(self.root / "GEMINI.md", "Divergent copy.\n")
        self.assertIn("GEMINI.md: must be a symlink to AGENTS.md", agent_skills.context_errors(self.root))

    def test_repository_catalog_is_valid_and_synced(self) -> None:
        skills = agent_skills.discover(ROOT)
        self.assertEqual([], agent_skills.validation_errors(ROOT, skills))
        self.assertEqual([], agent_skills.context_errors(ROOT))
        self.assertEqual([], agent_skills.drift(ROOT, skills))


if __name__ == "__main__":
    unittest.main()
