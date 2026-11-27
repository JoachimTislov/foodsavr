#!/usr/bin/env python3
import importlib.util
import io
import json
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("merge_gate", ROOT / "scripts/github/merge_gate.py")
gate = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules["merge_gate"] = gate
spec.loader.exec_module(gate)

NOW = datetime(2026, 11, 21, 12, 0, tzinfo=timezone.utc)


def pr(number, state="CLEAN", rollup="SUCCESS", labels=(gate.LABEL,), **kw):
    head = kw.pop("head", f"{number:07d}")
    kw.setdefault("head_time", NOW - timedelta(minutes=5))
    kw.setdefault("queue_ok", gate.LABEL in labels)
    kw.setdefault("author", "owner")
    kw.setdefault("author_association", "OWNER")
    kw.setdefault("files", ["docs/guide.md"])
    kw.setdefault("changed_files", len(kw["files"]))
    kw.setdefault(
        "reviews",
        [
            {
                "state": "COMMENTED",
                "commit": head,
                "author": "github-actions[bot]",
                "bot": True,
                "author_association": "NONE",
                "body": f"<!-- agent-review: {{\"pr\": {number}, \"head_sha\": \"{head}\", \"tier\": \"deep\", \"status\": \"approved\"}} -->",
            }
        ],
    )
    return gate.PR(
        number=number,
        node_id=f"N{number}",
        title=kw.pop("title", "feat: x"),
        head=head,
        merge_state=state,
        rollup=rollup,
        labels=set(labels),
        **kw,
    )


def actions(prs, owner="", trusted_bots=gate.DEFAULT_TRUSTED_BOTS, history=()):
    return [
        (a, p.number)
        for a, p in gate.plan(prs, NOW, owner=owner, trusted_bots=trusted_bots, history=history).actions
    ]


class PlanTest(unittest.TestCase):
    def test_report_includes_review_and_threads_for_security_pr(self):
        candidate = pr(1, labels=(gate.LABEL, "risk/security"), open_threads=2, reviews=[])
        report = gate.plan([candidate], NOW, history=[]).report[0][2]
        self.assertIn("risk/security", report)
        self.assertIn("2 unresolved review thread", report)
        self.assertTrue(gate.review_blocker(candidate, history=[]) in report)

    def test_merges_oldest_green_pr_only(self):
        self.assertEqual(actions([pr(3), pr(2)]), [("merge", 2)])

    def test_unlabeled_and_blocked_prs_are_left_alone(self):
        self.assertEqual(
            actions(
                [
                    pr(1, labels=()),
                    pr(2, body="**Door:** one-way"),
                    pr(3, state="DIRTY"),
                    pr(4, open_threads=1),
                    pr(5, review_decision="CHANGES_REQUESTED"),
                    pr(6, rollup="FAILURE"),
                    pr(7, draft=True),
                    pr(8, fork=True),
                    pr(9, threads_truncated=True),
                ]
            ),
            [],
        )

    def test_only_trusted_authors_can_auto_merge(self):
        untrusted = [
            pr(1, author="stranger", author_association="NONE"),
            pr(2, author="driveby", author_association="CONTRIBUTOR"),
            pr(3, author="newcomer", author_association="FIRST_TIME_CONTRIBUTOR"),
            pr(4, author="", author_association="OWNER"),
            pr(5, author="rogue-app", bot=True, author_association="NONE"),
            pr(6, author="owner", fork=True, author_association="OWNER"),
        ]
        self.assertEqual(actions(untrusted, owner="owner"), [])
        result = gate.plan(untrusted, NOW, owner="owner")
        self.assertTrue(all(state == "blocked" for _, state, _ in result.report))

        trusted = [
            pr(10, author="owner", author_association="NONE"),
            pr(11, author="org-member", author_association="MEMBER"),
            pr(12, author="teammate", author_association="COLLABORATOR"),
            # The PR author never attests its own change, so another trusted bot reviews it.
            pr(
                13,
                author="github-actions",
                bot=True,
                author_association="NONE",
                reviews=[{
                    "state": "COMMENTED",
                    "commit": "0000013",
                    "author": "dependabot[bot]",
                    "bot": True,
                    "author_association": "NONE",
                    "body": '<!-- agent-review: {"pr": 13, "head_sha": "0000013", "tier": "deep", "status": "approved"} -->',
                }],
            ),
            pr(14, author="foodsavr-agent", bot=True, author_association="NONE"),
        ]
        bots = gate.DEFAULT_TRUSTED_BOTS | {"foodsavr-agent"}
        self.assertEqual(actions([trusted[0]], owner="owner"), [("merge", 10)])
        self.assertEqual(actions([trusted[1]], owner="owner"), [("merge", 11)])
        self.assertEqual(actions([trusted[2]], owner="owner"), [("merge", 12)])
        self.assertEqual(actions([trusted[3]], owner="owner"), [("merge", 13)])
        self.assertEqual(actions([trusted[4]], owner="owner"), [])
        self.assertEqual(actions([trusted[4]], owner="owner", trusted_bots=bots), [("merge", 14)])

    def test_ready_unlabeled_pr_is_reported_without_auto_merge(self):
        ready = pr(20, labels=(), draft=False)
        untrusted = pr(21, labels=(), draft=False, author="outsider", author_association="CONTRIBUTOR")
        draft = pr(22, labels=(), draft=True)
        held = pr(23, labels=(), draft=False, label_removed=True)
        dep_major = pr(
            24,
            labels=(),
            draft=False,
            author="dependabot[bot]",
            bot=True,
            title="bump pkg from 1.2.3 to 2.0.0",
        )
        dep_held = pr(
            25,
            labels=(),
            draft=False,
            author="dependabot[bot]",
            bot=True,
            title="bump pkg from 1.2.3 to 1.2.4",
            label_removed=True,
        )
        result = gate.plan([ready, untrusted, draft, held, dep_major, dep_held], NOW, owner="owner")
        self.assertEqual(result.actions, [])
        self.assertEqual(
            result.report,
            [
                (20, "awaiting opt-in", "ready for review; add merge/auto to integrate"),
                (21, "untrusted", "author is not trusted for auto-merge"),
                (23, "held", "merge/auto was removed; re-add to integrate"),
                (24, "awaiting opt-in", "Dependabot major bump; add merge/auto to integrate"),
                (25, "held", "merge/auto was removed; re-add to integrate"),
            ],
        )

    def test_truncated_review_threads_block_merge(self):
        truncated = pr(30, threads_truncated=True)
        result = gate.plan([truncated], NOW, owner="owner")
        self.assertEqual(result.actions, [])
        self.assertEqual(
            result.report,
            [(30, "blocked", "review threads truncated (>100); resolve or inspect manually")],
        )

    def test_dependabot_bot_suffix_normalized_for_opt_in_and_rebase(self):
        dep = pr(
            31,
            labels=(),
            author="dependabot[bot]",
            bot=True,
            title="bump a from 1.2.3 to 1.2.4",
            reviews=[],
        )
        self.assertTrue(dep.dependabot)
        self.assertEqual(actions([dep], owner="owner"), [("label", 31)])
        dep_labeled = pr(
            32,
            author="dependabot[bot]",
            bot=True,
            title="bump a from 1.2.3 to 1.2.4",
            files=["pubspec.lock"],
            reviews=[],
        )
        # Exempt tier requires no agent review attestation
        self.assertEqual(actions([dep_labeled], owner="owner"), [("merge", 32)])

    def test_adaptive_review_tier_and_head_sha_binding_enforced(self):
        # Missing review on fast-tier PR blocks merge
        no_review = pr(40, files=["docs/readme.md"], reviews=[])
        res_missing = gate.plan([no_review], NOW, owner="owner")
        self.assertEqual(res_missing.actions, [])
        self.assertIn("missing required fast review attestation", res_missing.report[0][2])

        # Stale review from older commit SHA blocks merge
        stale = pr(
            41,
            head="bbbbbbb",
            files=["docs/readme.md"],
            reviews=[
                {
                    "state": "COMMENTED",
                    "commit": "aaaaaaa",
                    "author": "github-actions[bot]",
                    "bot": True,
                    "author_association": "NONE",
                    "body": '<!-- agent-review: {"pr": 41, "head_sha": "aaaaaaa", "tier": "fast", "status": "approved"} -->',
                }
            ],
        )
        res_stale = gate.plan([stale], NOW, owner="owner")
        self.assertEqual(res_stale.actions, [])
        self.assertIn("stale review (attested for aaaaaaa, head is bbbbbbb)", res_stale.report[0][2])

        # Insufficient tier (fast attested, deep required for ADR/architecture change) blocks merge
        under_tiered = pr(
            42,
            head="ccccccc",
            files=["specs/decisions/0009-example.md"],
            reviews=[
                {
                    "state": "COMMENTED",
                    "commit": "ccccccc",
                    "author": "github-actions[bot]",
                    "bot": True,
                    "author_association": "NONE",
                    "body": '<!-- agent-review: {"pr": 42, "head_sha": "ccccccc", "tier": "fast", "status": "approved"} -->',
                }
            ],
        )
        res_under = gate.plan([under_tiered], NOW, owner="owner")
        self.assertEqual(res_under.actions, [])
        self.assertIn("insufficient review tier (fast < required deep", res_under.report[0][2])

        # Sufficient deep tier at exact head SHA merges cleanly
        deep_ok = pr(
            43,
            head="ddddddd",
            files=["specs/decisions/0009-example.md"],
            reviews=[
                {
                    "state": "COMMENTED",
                    "commit": "ddddddd",
                    "author": "github-actions[bot]",
                    "bot": True,
                    "author_association": "NONE",
                    "body": '<!-- agent-review: {"pr": 43, "head_sha": "ddddddd", "tier": "deep", "status": "approved"} -->',
                }
            ],
        )
        self.assertEqual(actions([deep_ok], owner="owner"), [("merge", 43)])

    def test_incident_history_escalates_required_review_tier_in_gate(self):
        # A single doc change normally needs only fast review
        fast_reviewed = pr(
            50,
            head="eeeeeee",
            files=["docs/guide.md"],
            reviews=[
                {
                    "state": "COMMENTED",
                    "commit": "eeeeeee",
                    "author": "github-actions[bot]",
                    "bot": True,
                    "author_association": "NONE",
                    "body": '<!-- agent-review: {"pr": 50, "head_sha": "eeeeeee", "tier": "fast", "status": "approved"} -->',
                }
            ],
        )
        self.assertEqual(actions([fast_reviewed], owner="owner", history=()), [("merge", 50)])

        # With a prior incident on docs/guide.md recommending deep tier, fast review is blocked
        incident_history = [
            {
                "type": "incident",
                "incident_id": "inc-50",
                "files": ["docs/guide.md"],
                "areas": ["docs"],
                "original_review_tier": "fast",
                "recommended_tier": "deep",
            }
        ]
        res_escalated = gate.plan([fast_reviewed], NOW, owner="owner", history=incident_history)
        self.assertEqual(res_escalated.actions, [])
        self.assertIn(
            "insufficient review tier (fast < required deep (escalated by incident history)",
            res_escalated.report[0][2],
        )

    def test_non_required_failure_or_pending_check_blocks_merge(self):
        self.assertEqual(actions([pr(1, state="UNSTABLE", rollup="FAILURE")]), [])
        self.assertEqual(actions([pr(1, state="UNSTABLE")]), [("merge", 1)])
        self.assertEqual(actions([pr(1, rollup="PENDING", state="BLOCKED")]), [])

    def test_merges_pr409_shape_cancelled_hold_superseded_by_label_run(self):
        from test_checks import pr409_sequence

        rollup = gate.rollup_state(pr409_sequence())
        self.assertEqual(rollup, "SUCCESS")
        self.assertEqual(actions([pr(409, rollup=rollup)]), [("merge", 409)])

    def test_waits_for_queue_validation_before_merging(self):
        waiting = pr(1, queue_ok=False, head_time=NOW - timedelta(hours=2), labeled_at=NOW - timedelta(minutes=2))
        self.assertEqual(actions([waiting, pr(2, state="BEHIND")]), [])
        timed_out = pr(1, queue_ok=False, head_time=NOW - timedelta(hours=2), labeled_at=NOW - timedelta(minutes=20))
        self.assertEqual(actions([timed_out, pr(2, state="BEHIND")]), [("update", 2)])

    def test_updates_one_behind_pr_when_nothing_in_flight(self):
        self.assertEqual(actions([pr(2, state="BEHIND"), pr(1, state="BEHIND")]), [("update", 1)])

    def test_waits_while_another_pr_runs_checks(self):
        self.assertEqual(actions([pr(1, state="BEHIND"), pr(2, state="BLOCKED", rollup="PENDING")]), [])

    def test_holds_ready_pr_while_up_to_date_pr_validates(self):
        self.assertEqual(actions([pr(2, files=[]), pr(1, state="BLOCKED", rollup="PENDING")]), [])
        self.assertEqual(actions([pr(2, files=["lib/a.dart"]), pr(1, state="BLOCKED", rollup="PENDING")]), [])

    def test_out_of_scope_merge_is_not_held(self):
        self.assertEqual(actions([pr(2, files=["docs/a.md"]), pr(1, state="BLOCKED", rollup="PENDING")]), [("merge", 2)])

    def test_stalled_checks_do_not_hold_the_queue(self):
        stalled = pr(2, state="BLOCKED", rollup="PENDING", head_time=NOW - timedelta(hours=2))
        self.assertEqual(actions([pr(1, state="BEHIND"), stalled]), [("update", 1)])

    def test_dependabot_rebase_request_counts_as_in_flight(self):
        bot = pr(
            1,
            state="BEHIND",
            author="dependabot",
            bot=True,
            head_time=NOW - timedelta(hours=1),
            rebase_requested=NOW - timedelta(minutes=5),
        )
        self.assertEqual(actions([bot, pr(2, state="BEHIND")]), [])
        bot.rebase_requested = NOW - timedelta(hours=2)
        self.assertEqual(actions([bot, pr(2, state="BEHIND")]), [("update", 1)])

    def test_refused_dependabot_rebase_blocks_only_that_pr(self):
        refused = pr(
            1,
            state="BEHIND",
            author="dependabot",
            bot=True,
            rebase_refused=True,
            rebase_requested=NOW - timedelta(minutes=5),
        )
        self.assertEqual(actions([refused, pr(2, state="BEHIND")]), [("update", 2)])

    def test_human_named_dependabot_is_not_dependabot(self):
        fork = pr(1, labels=(), author="dependabot", fork=True, title="bump a from 1.0.0 to 1.0.1")
        self.assertEqual(actions([fork]), [])
        fork.labels = {gate.LABEL}
        self.assertEqual(actions([fork]), [])

    def test_fork_dependabot_bot_is_never_opted_in_or_merged(self):
        spoofed = pr(1, labels=(), author="dependabot", bot=True, fork=True, title="bump a from 1.0.0 to 1.0.1")
        self.assertEqual(actions([spoofed]), [])
        spoofed.labels = {gate.LABEL}
        self.assertEqual(actions([spoofed]), [])

    def test_dependabot_minor_and_patch_opt_in_unless_label_was_removed(self):
        def bot(n, title, **kw):
            return pr(n, labels=(), author="dependabot", bot=True, title=title, **kw)

        self.assertEqual(
            actions(
                [
                    bot(1, "bump a from 1.2.3 to 1.2.4"),
                    bot(2, "bump b from 1.2.3 to 1.3.0"),
                    bot(3, "bump c from 1.2.3 to 2.0.0"),
                    bot(4, "bump d from 0.2.0 to 0.3.0"),
                    bot(5, "bump e from 1.0.0 to 1.0.1", label_removed=True),
                ]
            ),
            [("label", 1), ("label", 2)],
        )


class SelfManagedMergeTest(unittest.TestCase):
    def merges(self, candidate, self_managed=True):
        result = gate.plan([candidate], NOW, history=[], self_managed=self_managed)
        return [(a, p.number) for a, p in result.actions] == [("merge", candidate.number)]

    def test_only_exact_opt_in_enables_self_managed_merge(self):
        for value, expected in (("true", True), (" TRUE ", True), ("false", False), ("", False), (None, False)):
            with self.subTest(value=value):
                self.assertEqual(gate.is_self_managed(value), expected)

    def test_missing_attestation_blocks_only_without_self_management(self):
        self.assertFalse(self.merges(pr(1, reviews=[]), self_managed=False))
        self.assertTrue(self.merges(pr(1, reviews=[])))
        self.assertIsNone(gate.blocker(pr(1, reviews=[]), history=[], self_managed=True))
        train = gate.plan_train([pr(1, reviews=[])], [], history=[], self_managed=True)
        self.assertEqual([slot.pr.number for slot in train.slots], [1])

    def test_structural_blockers_stay(self):
        cases = {
            "risk/security": {"labels": (gate.LABEL, gate.SECURITY_LABEL)},
            "security-sensitive": {"files": [".github/workflows/merge-gate.yml"]},
            "unresolved review thread": {"open_threads": 1},
            "check failed": {"rollup": "FAILURE"},
            "conflicts": {"state": "DIRTY"},
            "changes requested": {"review_decision": "CHANGES_REQUESTED"},
            "fork": {"fork": True},
            "not trusted": {"author": "stranger", "author_association": "NONE"},
            "one-way": {"body": "**Door:** one-way"},
        }
        for reason, kwargs in cases.items():
            with self.subTest(reason):
                candidate = pr(1, reviews=[], **kwargs)
                self.assertFalse(self.merges(candidate))
                report = gate.plan([candidate], NOW, history=[], self_managed=True).report[0][2]
                self.assertIn(reason, report)

    def test_explicit_human_holds_and_truncated_files_still_need_approval(self):
        for kwargs in (
            {"labels": (gate.LABEL, "review/human")},
            {"labels": (gate.LABEL, "door/one-way")},
            {"files_truncated": True},
            {"changed_files": 101},
        ):
            with self.subTest(**kwargs):
                candidate = pr(1, reviews=[], **kwargs)
                self.assertFalse(self.merges(candidate))
                self.assertEqual(gate.plan_train([candidate], [], history=[], self_managed=True).slots, [])

    def test_running_review_is_waited_for(self):
        candidate = pr(1, reviews=[], state="BEHIND", review_running=True, review_started_at=NOW)
        result = gate.plan([candidate], NOW, history=[], self_managed=True)
        self.assertEqual(result.actions, [])
        self.assertEqual(result.report[0][1:], ("in flight", "Agent review running"))


class SupersessionTest(unittest.TestCase):
    def run_(self, id, status="in_progress", event="workflow_run", actor="owner"):
        return {"id": id, "status": status, "event": event, "actor": {"login": actor}}

    def test_newest_run_acts_after_older_ones(self):
        self.assertEqual(gate.supersession([self.run_(5), self.run_(7)], 5), "exit")
        self.assertEqual(gate.supersession([self.run_(5), self.run_(7)], 7), "wait")
        self.assertIsNone(gate.supersession([self.run_(5, "completed"), self.run_(7)], 7))

    def test_runs_that_never_execute_the_gate_are_ignored(self):
        runs = [self.run_(9, event="pull_request_target"), self.run_(8, actor="dependabot[bot]"), self.run_(5)]
        self.assertIsNone(gate.supersession(runs, 5))


class ParseTest(unittest.TestCase):
    def test_rollup_state(self):
        run = lambda status, conclusion=None: {
            "__typename": "CheckRun",
            "name": "c",
            "status": status,
            "conclusion": conclusion,
        }
        self.assertIsNone(gate.rollup_state([]))
        self.assertEqual(gate.rollup_state([run("COMPLETED", "SUCCESS"), run("QUEUED")]), "PENDING")
        self.assertEqual(gate.rollup_state([run("COMPLETED", "CANCELLED"), run("QUEUED")]), "FAILURE")
        self.assertEqual(
            gate.rollup_state([run("COMPLETED", "NEUTRAL"), {"__typename": "StatusContext", "state": "EXPECTED"}]),
            "PENDING",
        )

    def test_queue_check_state_ignores_skipped_runs_and_untrusted_apps(self):
        self.assertEqual(gate.queue_check_state([
            {"__typename": "CheckRun", "name": gate.QUEUE_CHECK, "status": "COMPLETED", "conclusion": "SKIPPED"},
        ]), (False, False))
        self.assertEqual(gate.queue_check_state([
            {"__typename": "CheckRun", "name": gate.QUEUE_CHECK, "status": "COMPLETED", "conclusion": "SUCCESS",
             "checkSuite": {"app": {"slug": "evil-app"}}},
        ]), (False, False))
        self.assertEqual(gate.queue_check_state([
            {"__typename": "CheckRun", "name": gate.QUEUE_CHECK, "status": "COMPLETED", "conclusion": "SUCCESS",
             "checkSuite": {"app": {"slug": "github-actions"}}},
        ]), (True, False))

    def test_trusted_bot_set_normalizes_suffix(self):
        bots = gate.trusted_bot_set(["My-Agent[bot]"])
        self.assertIn("my-agent", bots)
        self.assertIn("dependabot", bots)
        self.assertIn("github-actions", bots)

    def test_security_label_and_sensitive_paths_block_auto_merge(self):
        self.assertEqual(actions([
            pr(1, labels=(gate.LABEL, "risk/security")),
            pr(2, files=["infra/terraform/main.tf"]),
            pr(3, files=[".github/workflows/pull-request.yml"]),
            pr(4, files=[".agents/policies/default.json"]),
        ]), [])

    def test_from_node(self):
        node = {
            "id": "N",
            "number": 9,
            "title": "t",
            "body": None,
            "isDraft": False,
            "isCrossRepository": False,
            "mergeStateStatus": "BEHIND",
            "authorAssociation": "CONTRIBUTOR",
            "reviewDecision": None,
            "headRefOid": "abc",
            "additions": 12,
            "deletions": 3,
            "changedFiles": 1,
            "author": {"__typename": "Bot", "login": "dependabot[bot]"},
            "labels": {"nodes": [{"name": gate.LABEL}]},
            "files": {"pageInfo": {"hasNextPage": False}, "nodes": [{"path": "pubspec.lock"}]},
            "reviewThreads": {
                "pageInfo": {"hasNextPage": True},
                "nodes": [{"isResolved": False, "isOutdated": True}, {"isResolved": False, "isOutdated": False}],
            },
            "reviews": {
                "nodes": [
                    {
                        "state": "APPROVED",
                        "body": "LGTM",
                        "submittedAt": "2026-11-21T11:30:00Z",
                        "authorAssociation": "OWNER",
                        "commit": {"oid": "abc"},
                        "author": {"__typename": "User", "login": "owner"},
                    }
                ]
            },
            "commits": {
                "nodes": [
                    {
                        "commit": {
                            "committedDate": "2026-11-21T10:00:00Z",
                            "statusCheckRollup": {
                                "contexts": {
                                    "nodes": [
                                        {
                                            "__typename": "CheckRun",
                                            "name": "Check & Test",
                                            "status": "COMPLETED",
                                            "conclusion": "SKIPPED",
                                        },
                                        {
                                            "__typename": "CheckRun",
                                            "name": "sync",
                                            "status": "IN_PROGRESS",
                                            "conclusion": None,
                                            "checkSuite": {
                                                "workflowRun": {"workflow": {"name": "Synchronize GitHub labels"}}
                                            },
                                        },
                                        {"__typename": "StatusContext", "context": "x", "state": "SUCCESS"},
                                    ]
                                }
                            },
                        }
                    }
                ]
            },
            "timelineItems": {"nodes": [{"label": {"name": "other"}}]},
            "comments": {
                "nodes": [
                    {"body": "@dependabot rebase", "createdAt": "2026-11-21T11:00:00Z", "author": {"login": "owner"}},
                    {
                        "body": "Looks like this PR has been edited by someone other than Dependabot.",
                        "createdAt": "2026-11-21T11:00:05Z",
                        "author": {"login": "dependabot[bot]"},
                    },
                ]
            },
        }
        p = gate.from_node(node)
        self.assertEqual(
            (
                p.open_threads,
                p.threads_truncated,
                p.label_removed,
                p.dependabot,
                p.rollup,
                p.rebase_refused,
                p.author_association,
                p.files,
                len(p.reviews),
            ),
            (1, True, False, True, "SUCCESS", True, "CONTRIBUTOR", ["pubspec.lock"], 1),
        )
        self.assertEqual(p.rebase_requested, datetime(2026, 11, 21, 11, 0, tzinfo=timezone.utc))


class PatchEquivalentMergeGateTest(unittest.TestCase):
    def test_needs_patch_id_only_when_prior_head_has_patch_id_attestation(self):
        old_comment = {
            "body": '<!-- agent-review: {"pr": 10, "head_sha": "oldhead", "tier": "fast", "status": "approved", "patch_id": "sha256:abc"} -->',
            "author": {"__typename": "Bot", "login": "github-actions[bot]"},
        }
        p_needs = pr(10, head="newhead", reviews=[], comments=[old_comment])
        self.assertTrue(gate.needs_patch_id(p_needs))

        p_untrusted_current = pr(
            10,
            head="newhead",
            reviews=[],
            comments=[
                old_comment,
                {
                    "body": '<!-- agent-review: {"pr": 10, "head_sha": "newhead", "tier": "deep", "status": "approved"} -->',
                    "author": {"__typename": "User", "login": "stranger"},
                    "authorAssociation": "NONE",
                },
            ],
        )
        self.assertTrue(gate.needs_patch_id(p_untrusted_current))

        p_exact = pr(10, head="oldhead", reviews=[], comments=[old_comment])
        self.assertFalse(gate.needs_patch_id(p_exact))

        p_unlabeled = pr(10, head="newhead", labels=(), reviews=[], comments=[old_comment])
        self.assertFalse(gate.needs_patch_id(p_unlabeled))

        p_no_patch = pr(
            10,
            head="newhead",
            reviews=[],
            comments=[
                {
                    "body": '<!-- agent-review: {"pr": 10, "head_sha": "oldhead", "tier": "fast", "status": "approved"} -->',
                    "author": {"__typename": "Bot", "login": "github-actions[bot]"},
                }
            ],
        )
        self.assertFalse(gate.needs_patch_id(p_no_patch))

    def test_populate_patch_ids_uses_immutable_compare_diff_and_fails_closed_without_base(self):
        old_comment = {
            "body": '<!-- agent-review: {"pr": 10, "head_sha": "oldhead", "tier": "fast", "status": "approved", "patch_id": "sha256:old"} -->',
            "author": {"__typename": "Bot", "login": "github-actions[bot]"},
        }
        p_with_base = pr(10, head="head123", base="base123", reviews=[], comments=[old_comment])
        p_no_base = pr(11, head="head456", base="", reviews=[], comments=[old_comment])
        gh = gate.GitHub("owner/repo", apply=False)
        calls: list[tuple[str, ...]] = []

        def fake_run(*args: str, stdin: str | None = None) -> str:
            calls.append(args)
            return "diff --git a/a.txt b/a.txt\n@@ -1 +1 @@\n-a\n+b\n"

        gh.run = fake_run  # type: ignore[method-assign]
        gh.populate_patch_ids([p_with_base, p_no_base])

        self.assertEqual(
            calls,
            [("api", "-H", "Accept: application/vnd.github.v3.diff", "repos/owner/repo/compare/base123...head123")],
        )
        self.assertIsNotNone(p_with_base.patch_id)
        self.assertIsNone(p_no_base.patch_id)

    def test_plan_merges_when_patch_id_matches_prior_approved_head(self):
        old_comment = {
            "body": '<!-- agent-review: {"pr": 12, "head_sha": "1111111", "tier": "fast", "status": "approved", "patch_id": "sha256:same"} -->',
            "author": {"__typename": "Bot", "login": "github-actions[bot]"},
        }
        # Matching patch_id passes the review gate without re-running the model
        p_ok = pr(12, head="2222222", reviews=[], comments=[old_comment], patch_id="sha256:same")
        self.assertEqual(actions([p_ok], owner="owner"), [("merge", 12)])

        # Changed patch_id stays blocked
        p_changed = pr(12, head="2222222", reviews=[], comments=[old_comment], patch_id="sha256:different")
        self.assertEqual(actions([p_changed], owner="owner"), [])

        # Missing patch_id fails closed
        p_missing = pr(12, head="2222222", reviews=[], comments=[old_comment], patch_id=None)
        self.assertEqual(actions([p_missing], owner="owner"), [])


class FreezePriorityAndRaceTest(unittest.TestCase):
    def test_running_agent_review_prevents_concurrent_rebase_of_behind_pr(self):
        reviewing = pr(1, state="CLEAN", rollup="SUCCESS", reviews=[], review_running=True)
        behind = pr(2, state="BEHIND")
        result = gate.plan([reviewing, behind], NOW, owner="owner")
        self.assertEqual(result.actions, [])
        states = {n: s for n, s, _ in result.report}
        self.assertEqual(states[1], "in flight")

        # Old head commit (> STALL_AFTER) with a freshly started Agent review still stays in flight
        fresh_review_on_old_head = pr(
            1,
            state="CLEAN",
            rollup="SUCCESS",
            reviews=[],
            review_running=True,
            head_time=NOW - timedelta(hours=3),
            review_started_at=NOW - timedelta(minutes=5),
        )
        res_fresh = gate.plan([fresh_review_on_old_head, behind], NOW, owner="owner")
        self.assertEqual(res_fresh.actions, [])
        self.assertEqual({n: s for n, s, _ in res_fresh.report}[1], "in flight")

        # Old head commit with freshly labeled queued review (startedAt not yet set) also stays in flight
        queued_after_label = pr(
            1,
            state="CLEAN",
            rollup="SUCCESS",
            reviews=[],
            review_running=True,
            head_time=NOW - timedelta(hours=3),
            labeled_at=NOW - timedelta(minutes=3),
            review_started_at=None,
        )
        self.assertEqual(actions([queued_after_label, behind], owner="owner"), [])

        # Fresh head commit whose Agent review check run itself stalled past STALL_AFTER unblocks behind PR
        stalled_check_run = pr(
            1,
            state="CLEAN",
            rollup="SUCCESS",
            reviews=[],
            review_running=True,
            head_time=NOW - timedelta(minutes=5),
            review_started_at=NOW - timedelta(hours=2),
        )
        self.assertEqual(actions([stalled_check_run, behind], owner="owner"), [("update", 2)])

        # Once stalled past STALL_AFTER without review_started_at, it no longer blocks the behind PR
        stalled_review = pr(
            1, state="CLEAN", rollup="SUCCESS", reviews=[], review_running=True,
            head_time=NOW - timedelta(hours=2),
        )
        self.assertEqual(actions([stalled_review, behind], owner="owner"), [("update", 2)])

        # A hard structural blocker (e.g. FAILURE rollup) stays blocked even while review_running=True
        failed_review = pr(1, state="CLEAN", rollup="FAILURE", reviews=[], review_running=True)
        self.assertEqual(actions([failed_review, behind], owner="owner"), [("update", 2)])

    def test_older_or_priority_ready_pr_not_held_behind_newer_validating_pr(self):
        older_ready = pr(1, files=["lib/a.dart"])
        newer_validating = pr(2, state="BLOCKED", rollup="PENDING", files=["lib/b.dart"])
        self.assertEqual(actions([older_ready, newer_validating], owner="owner"), [("merge", 1)])

        # Priority PR #10 jumps ahead of normal validating PR #1
        prio_ready = pr(10, labels=(gate.LABEL, gate.PRIORITY_LABEL), files=["lib/p.dart"])
        normal_validating = pr(1, state="BLOCKED", rollup="PENDING", files=["lib/a.dart"])
        self.assertEqual(actions([prio_ready, normal_validating], owner="owner"), [("merge", 10)])

        # Normal PR #10 IS held behind priority validating PR #20
        prio_validating = pr(20, labels=(gate.LABEL, gate.PRIORITY_LABEL), state="BLOCKED", rollup="PENDING", files=["lib/p.dart"])
        normal_ready = pr(10, files=["lib/a.dart"])
        self.assertEqual(actions([prio_validating, normal_ready], owner="owner"), [])

    def test_resolve_freeze_mode_variants_and_fail_closed(self):
        self.assertEqual(gate.resolve_freeze_mode("", []), ("none", ""))
        self.assertEqual(gate.resolve_freeze_mode("none", []), ("none", ""))
        mode, reason = gate.resolve_freeze_mode("", [{"number": 455, "title": "Epic"}])
        self.assertEqual(mode, "batch")
        self.assertIn("#455", reason)
        self.assertEqual(gate.resolve_freeze_mode("batch", [])[0], "batch")
        self.assertEqual(gate.resolve_freeze_mode("all", [])[0], "all")
        self.assertEqual(gate.resolve_freeze_mode("true", [])[0], "all")
        # Unknown values fail closed to all
        self.assertEqual(gate.resolve_freeze_mode("weird-value", [])[0], "all")
        # Failed freeze-issue lookup fails closed to all when env does not override it
        err_mode, err_reason = gate.resolve_freeze_mode("", [], lookup_error="502 Bad Gateway")
        self.assertEqual(err_mode, "all")
        self.assertIn("502 Bad Gateway", err_reason)
        # Explicit MERGE_GATE_FREEZE=batch still overrides a failed issue lookup
        self.assertEqual(gate.resolve_freeze_mode("batch", [], lookup_error="502")[0], "batch")

    def test_freeze_batch_and_all_preserve_normal_prs_and_allow_priority_under_batch(self):
        normal = pr(1, files=["docs/a.md"])
        prio = pr(5, labels=(gate.LABEL, gate.PRIORITY_LABEL), files=["docs/b.md"])
        dep = pr(
            6,
            labels=(),
            author="dependabot[bot]",
            bot=True,
            title="bump pkg from 1.0.0 to 1.0.1",
            reviews=[],
        )

        # Under batch freeze: priority PR merges, normal PR & Dependabot opt-in are frozen
        res_batch = gate.plan([normal, prio, dep], NOW, owner="owner", freeze_mode="batch", freeze_reason="epic #455")
        self.assertEqual([(a, p.number) for a, p in res_batch.actions], [("merge", 5)])
        by_pr = {n: (s, d) for n, s, d in res_batch.report}
        self.assertEqual(by_pr[1][0], "frozen")
        self.assertEqual(by_pr[6][0], "frozen")

        # Under all freeze: nothing merges or labels, all reported frozen
        res_all = gate.plan([normal, prio, dep], NOW, owner="owner", freeze_mode="all", freeze_reason="emergency")
        self.assertEqual(res_all.actions, [])
        by_pr_all = {n: s for n, s, _ in res_all.report}
        self.assertEqual(by_pr_all, {5: "frozen", 1: "frozen", 6: "frozen"})

        # Unfrozen: priority PR still integrates before older normal PR
        res_open = gate.plan([normal, prio], NOW, owner="owner", freeze_mode="none")
        self.assertEqual([(a, p.number) for a, p in res_open.actions], [("merge", 5)])


class SpeculativeMergeTrainTest(unittest.TestCase):
    def test_resolve_train_depth(self):
        self.assertEqual(gate.resolve_train_depth(None), gate.DEFAULT_TRAIN_DEPTH)
        self.assertEqual(gate.resolve_train_depth(""), gate.DEFAULT_TRAIN_DEPTH)
        self.assertEqual(gate.resolve_train_depth("0"), 0)
        self.assertEqual(gate.resolve_train_depth("2"), 2)
        self.assertEqual(gate.resolve_train_depth(99), gate.MAX_TRAIN_DEPTH)
        self.assertEqual(gate.resolve_train_depth(-3), 0)
        self.assertEqual(gate.resolve_train_depth("bogus"), 0)

    def test_plan_train_orders_priority_retains_slot0_and_deletes_stale(self):
        prs = [
            pr(10, state="BEHIND", rollup="SUCCESS"),
            pr(11, state="BEHIND", rollup="SUCCESS"),
            pr(12, state="BEHIND", rollup="SUCCESS"),
            pr(20, state="CLEAN", rollup="PENDING", labels=(gate.LABEL, gate.PRIORITY_LABEL)),
        ]
        existing = [
            "merge-train/pr-20",  # slot 0 existing ref must be retained while open
            "merge-train/pr-10",
            "merge-train/pr-12",  # outside depth=2 (slots: 20, 10, 11)
            "merge-train/pr-99",  # merged/stale ref
        ]
        tp = gate.plan_train(prs, existing, depth=2, owner="owner", history=[])
        self.assertEqual([(s.pr.number, s.push) for s in tp.slots], [(20, False), (10, True), (11, True)])
        self.assertEqual(tp.delete_refs, ["merge-train/pr-12", "merge-train/pr-99"])

    def test_plan_train_respects_batch_and_all_freeze(self):
        normal = pr(10, state="BEHIND")
        prio1 = pr(20, state="CLEAN", rollup="PENDING", labels=(gate.LABEL, gate.PRIORITY_LABEL))
        prio2 = pr(21, state="BEHIND", labels=(gate.LABEL, gate.PRIORITY_LABEL))
        existing = ["merge-train/pr-10", "merge-train/pr-21"]

        batch_plan = gate.plan_train([normal, prio1, prio2], existing, depth=3, freeze_mode="batch", owner="owner", history=[])
        self.assertEqual([(s.pr.number, s.push) for s in batch_plan.slots], [(20, False), (21, True)])
        self.assertEqual(batch_plan.delete_refs, ["merge-train/pr-10"])

        all_plan = gate.plan_train([normal, prio1, prio2], existing, depth=3, freeze_mode="all", owner="owner", history=[])
        self.assertEqual(all_plan.slots, [])
        self.assertEqual(all_plan.delete_refs, ["merge-train/pr-10", "merge-train/pr-21"])

        disabled = gate.plan_train([normal, prio1, prio2], existing, depth=0, freeze_mode="none", owner="owner", history=[])
        self.assertEqual(disabled.slots, [])
        self.assertEqual(disabled.delete_refs, ["merge-train/pr-10", "merge-train/pr-21"])

    def test_plan_train_excludes_unreviewed_forks_and_security_prs(self):
        unreviewed = pr(10, state="CLEAN", reviews=[])
        fork_pr = pr(11, state="CLEAN", fork=True)
        sec_pr = pr(12, state="CLEAN", labels=(gate.LABEL, gate.SECURITY_LABEL))
        ok1 = pr(13, state="CLEAN")
        ok2 = pr(14, state="BEHIND")
        tp = gate.plan_train([unreviewed, fork_pr, sec_pr, ok1, ok2], [], depth=3, owner="owner", history=[])
        self.assertEqual([(s.pr.number, s.push) for s in tp.slots], [(13, False), (14, True)])

    def test_sync_train_linear_replay_idempotent_push_conflict_ejection_and_cleanup(self):
        def _git(cwd: Path, *args: str) -> str:
            res = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, check=True)
            return res.stdout.strip()

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            origin = root / "origin.git"
            seed = root / "seed"
            origin.mkdir()
            seed.mkdir()
            _git(origin, "init", "--bare")
            _git(seed, "init", "-b", "develop")
            _git(seed, "config", "user.name", "Test")
            _git(seed, "config", "user.email", "test@example.com")
            _git(seed, "remote", "add", "origin", str(origin))

            (seed / "shared.txt").write_text("base\n", encoding="utf-8")
            (seed / "other.txt").write_text("base\n", encoding="utf-8")
            _git(seed, "add", ".")
            _git(seed, "commit", "-m", "base")
            base_sha = _git(seed, "rev-parse", "HEAD")
            _git(seed, "push", "origin", "HEAD:refs/heads/develop")
            # Seed a stale train ref to verify cleanup
            _git(seed, "push", "origin", "HEAD:refs/heads/merge-train/pr-99")

            # PR #10 modifies shared.txt
            _git(seed, "checkout", "-q", "-B", "pr10", base_sha)
            (seed / "shared.txt").write_text("from-pr-10\n", encoding="utf-8")
            _git(seed, "add", "shared.txt")
            _git(seed, "commit", "-m", "pr 10")
            sha10 = _git(seed, "rev-parse", "HEAD")
            _git(seed, "push", "origin", f"{sha10}:refs/pull/10/head")

            # PR #20 conflicts with PR #10 on shared.txt
            _git(seed, "checkout", "-q", "-B", "pr20", base_sha)
            (seed / "shared.txt").write_text("from-pr-20-conflict\n", encoding="utf-8")
            _git(seed, "add", "shared.txt")
            _git(seed, "commit", "-m", "pr 20")
            sha20 = _git(seed, "rev-parse", "HEAD")
            _git(seed, "push", "origin", f"{sha20}:refs/pull/20/head")

            # PR #30 modifies other.txt (clean against PR #10!)
            _git(seed, "checkout", "-q", "-B", "pr30", base_sha)
            (seed / "other.txt").write_text("from-pr-30\n", encoding="utf-8")
            _git(seed, "add", "other.txt")
            _git(seed, "commit", "-m", "pr 30")
            sha30 = _git(seed, "rev-parse", "HEAD")
            _git(seed, "push", "origin", f"{sha30}:refs/pull/30/head")

            p10 = pr(10, head=sha10, state="CLEAN")
            p20 = pr(20, head=sha20, state="BEHIND")
            p30 = pr(30, head=sha30, state="BEHIND")
            tp = gate.plan_train([p10, p20, p30], ["merge-train/pr-99"], depth=3, owner="owner", history=[])
            gh = gate.GitHub("owner/repo", apply=True)

            notes1 = gh.sync_train(tp, remote_url=str(origin))
            self.assertTrue(any("train #20: ejected" in n for n in notes1), notes1)
            self.assertTrue(any("train #30: pushed merge-train/pr-30" in n for n in notes1), notes1)
            self.assertTrue(any("train cleanup: deleted merge-train/pr-99" in n for n in notes1), notes1)

            # Verify origin refs: pr-30 exists, pr-20 and pr-99 do not, and pr-30 is strictly linear with both changes
            refs = _git(origin, "for-each-ref", "--format=%(refname)", "refs/heads/merge-train/").splitlines()
            self.assertEqual(refs, ["refs/heads/merge-train/pr-30"])
            train30_sha = _git(origin, "rev-parse", "refs/heads/merge-train/pr-30")
            self.assertEqual(_git(origin, "show", "refs/heads/merge-train/pr-30:shared.txt"), "from-pr-10")
            self.assertEqual(_git(origin, "show", "refs/heads/merge-train/pr-30:other.txt"), "from-pr-30")
            self.assertEqual(_git(origin, "rev-list", "--merges", f"{base_sha}..{train30_sha}"), "")
            self.assertEqual(len(_git(origin, "rev-list", f"{base_sha}..{train30_sha}").splitlines()), 2)

            # Second sync with identical state must NOT push merge-train/pr-30 again
            tp2 = gate.plan_train([p10, p20, p30], ["merge-train/pr-30"], depth=3, owner="owner", history=[])
            notes2 = gh.sync_train(tp2, remote_url=str(origin))
            self.assertTrue(any("train #30: merge-train/pr-30 unchanged" in n for n in notes2), notes2)
            self.assertEqual(_git(origin, "rev-parse", "refs/heads/merge-train/pr-30"), train30_sha)

    def test_sync_train_ejects_failed_tree_without_poisoning_downstream_and_retries_on_fix(self):
        def _git(cwd: Path, *args: str) -> str:
            res = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, check=True)
            return res.stdout.strip()

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            origin = root / "origin.git"
            seed = root / "seed"
            origin.mkdir()
            seed.mkdir()
            _git(origin, "init", "--bare")
            _git(seed, "init", "-b", "develop")
            _git(seed, "config", "user.name", "Test")
            _git(seed, "config", "user.email", "test@example.com")
            _git(seed, "remote", "add", "origin", str(origin))

            (seed / "a.txt").write_text("base\n", encoding="utf-8")
            (seed / "b.txt").write_text("base\n", encoding="utf-8")
            (seed / "c.txt").write_text("base\n", encoding="utf-8")
            _git(seed, "add", ".")
            _git(seed, "commit", "-m", "base")
            base_sha = _git(seed, "rev-parse", "HEAD")
            _git(seed, "push", "origin", "HEAD:refs/heads/develop")

            _git(seed, "checkout", "-q", "-B", "pr10", base_sha)
            (seed / "a.txt").write_text("from-10\n", encoding="utf-8")
            _git(seed, "add", "a.txt")
            _git(seed, "commit", "-m", "pr 10")
            sha10 = _git(seed, "rev-parse", "HEAD")
            _git(seed, "push", "origin", f"{sha10}:refs/pull/10/head")

            _git(seed, "checkout", "-q", "-B", "pr20", base_sha)
            (seed / "b.txt").write_text("from-20-broken\n", encoding="utf-8")
            _git(seed, "add", "b.txt")
            _git(seed, "commit", "-m", "pr 20")
            sha20 = _git(seed, "rev-parse", "HEAD")
            _git(seed, "push", "origin", f"{sha20}:refs/pull/20/head")

            _git(seed, "checkout", "-q", "-B", "pr30", base_sha)
            (seed / "c.txt").write_text("from-30\n", encoding="utf-8")
            _git(seed, "add", "c.txt")
            _git(seed, "commit", "-m", "pr 30")
            sha30 = _git(seed, "rev-parse", "HEAD")
            _git(seed, "push", "origin", f"{sha30}:refs/pull/30/head")

            p10 = pr(10, head=sha10, state="CLEAN")
            p20 = pr(20, head=sha20, state="BEHIND")
            p30 = pr(30, head=sha30, state="BEHIND")
            gh = gate.GitHub("owner/repo", apply=True)

            # Initial sync pushes both merge-train/pr-20 and merge-train/pr-30 (with #20 included)
            tp1 = gate.plan_train([p10, p20, p30], [], depth=3, owner="owner", history=[])
            gh.sync_train(tp1, remote_url=str(origin))
            failed_tree20 = _git(origin, "rev-parse", "refs/heads/merge-train/pr-20^{tree}")
            self.assertEqual(_git(origin, "show", "refs/heads/merge-train/pr-30:b.txt"), "from-20-broken")

            # Next run observes merge-train/pr-20 failed at failed_tree20 -> ejects #20 from train_tip,
            # keeps tombstone ref, and replays #30 cleanly WITHOUT #20's changes!
            tp2 = gate.plan_train(
                [p10, p20, p30],
                ["merge-train/pr-20", "merge-train/pr-30"],
                depth=3,
                owner="owner",
                history=[],
            )
            notes2 = gh.sync_train(
                tp2,
                remote_url=str(origin),
                failed_train_trees={"merge-train/pr-20": failed_tree20},
            )
            self.assertTrue(any("train #20: ejected (merge-train/pr-20 failed checks" in n for n in notes2), notes2)
            self.assertTrue(any("train #30: pushed merge-train/pr-30" in n for n in notes2), notes2)
            # Tombstone ref stays present so subsequent runs remember the failed tree
            self.assertEqual(_git(origin, "rev-parse", "refs/heads/merge-train/pr-20^{tree}"), failed_tree20)
            # Downstream #30 now contains #10 + #30 only (b.txt reverted to base!)
            self.assertEqual(_git(origin, "show", "refs/heads/merge-train/pr-30:a.txt"), "from-10")
            self.assertEqual(_git(origin, "show", "refs/heads/merge-train/pr-30:b.txt"), "base")
            self.assertEqual(_git(origin, "show", "refs/heads/merge-train/pr-30:c.txt"), "from-30")

            # Once PR #20 pushes a fix (different tree), it automatically rejoins the train!
            _git(seed, "checkout", "-q", "-B", "pr20", base_sha)
            (seed / "b.txt").write_text("from-20-fixed\n", encoding="utf-8")
            _git(seed, "add", "b.txt")
            _git(seed, "commit", "-m", "pr 20 fixed")
            sha20_fixed = _git(seed, "rev-parse", "HEAD")
            _git(seed, "push", "--force", "origin", f"{sha20_fixed}:refs/pull/20/head")

            p20_fixed = pr(20, head=sha20_fixed, state="BEHIND")
            tp3 = gate.plan_train(
                [p10, p20_fixed, p30],
                ["merge-train/pr-20", "merge-train/pr-30"],
                depth=3,
                owner="owner",
                history=[],
            )
            notes3 = gh.sync_train(
                tp3,
                remote_url=str(origin),
                failed_train_trees={"merge-train/pr-20": failed_tree20},
            )
            self.assertTrue(any("train #20: pushed merge-train/pr-20" in n for n in notes3), notes3)
            self.assertEqual(_git(origin, "show", "refs/heads/merge-train/pr-30:b.txt"), "from-20-fixed")

    def test_train_ref_states_parses_graphql_prefix_and_rollup(self):
        gh = gate.GitHub("owner/repo", apply=False)
        payload = {
            "data": {
                "repository": {
                    "refs": {
                        "nodes": [
                            {
                                "name": "pr-20",
                                "prefix": "refs/heads/merge-train/",
                                "target": {
                                    "oid": "1111111",
                                    "tree": {"oid": "tree20"},
                                    "statusCheckRollup": {
                                        "contexts": {
                                            "nodes": [
                                                {
                                                    "__typename": "CheckRun",
                                                    "name": "Check & Test",
                                                    "status": "COMPLETED",
                                                    "conclusion": "FAILURE",
                                                    "startedAt": "2026-11-21T12:00:00Z",
                                                    "checkSuite": {
                                                        "app": {"slug": "github-actions"},
                                                        "workflowRun": {"databaseId": 1, "workflow": {"name": "CI"}},
                                                    },
                                                }
                                            ]
                                        }
                                    },
                                },
                            }
                        ]
                    }
                }
            }
        }
        gh.run = lambda *args, **kwargs: json.dumps(payload)  # type: ignore[method-assign]
        states = gh.train_ref_states()
        self.assertIn("merge-train/pr-20", states)
        self.assertEqual(states["merge-train/pr-20"].tree_oid, "tree20")
        self.assertEqual(states["merge-train/pr-20"].rollup, "FAILURE")


class MainFreezeSafetyTest(unittest.TestCase):
    def test_main_fails_closed_and_writes_summary_when_freeze_issues_lookup_fails(self):
        ready_pr = pr(10, files=["docs/a.md"])
        executed: list[tuple[str, int]] = []

        class FakeGitHub(gate.GitHub):
            def prs(self):
                return [ready_pr]

            def freeze_issues(self):
                raise RuntimeError("gh api failed: 502 Bad Gateway")

            def populate_patch_ids(self, prs):
                pass

            def execute(self, action, p):
                executed.append((action, p.number))
                return "merged"

            def train_ref_states(self):
                raise AssertionError("train_ref_states should be skipped on freeze lookup error")

        stdout = io.StringIO()
        with mock.patch.object(gate, "GitHub", FakeGitHub), mock.patch.object(gate, "serialize", return_value=True):
            with redirect_stdout(stdout):
                rc = gate.main(["--repo", "owner/repo", "--apply"])

        self.assertEqual(rc, 0)
        self.assertEqual(executed, [])
        out = stdout.getvalue()
        self.assertIn("**Integration freeze active:** `all`", out)
        self.assertIn("freeze-issue lookup failed", out)
        self.assertIn("train sync skipped", out)

    def test_main_rechecks_live_freeze_state_before_executing_merge(self):
        normal_pr = pr(10, files=["docs/a.md"])
        executed: list[tuple[str, int]] = []
        freeze_calls = 0

        class FakeGitHub(gate.GitHub):
            def prs(self):
                return [normal_pr]

            def freeze_issues(self):
                nonlocal freeze_calls
                freeze_calls += 1
                # First lookup (before planning) is unfrozen; second lookup (right before merge) sees #455!
                return [] if freeze_calls == 1 else [{"number": 455, "title": "Urgent freeze"}]

            def populate_patch_ids(self, prs):
                pass

            def execute(self, action, p):
                executed.append((action, p.number))
                return "merged"

            def train_ref_states(self):
                return {}

            def sync_train(self, train_plan, **kwargs):
                return []

        stdout = io.StringIO()
        with mock.patch.object(gate, "GitHub", FakeGitHub), mock.patch.object(gate, "serialize", return_value=True):
            with redirect_stdout(stdout):
                rc = gate.main(["--repo", "owner/repo", "--apply"])

        self.assertEqual(rc, 0)
        self.assertEqual(executed, [])
        self.assertGreaterEqual(freeze_calls, 2)
        out = stdout.getvalue()
        self.assertIn("#10: merge skipped — integration freeze (batch:", out)
        self.assertIn("#455", out)


if __name__ == "__main__":
    unittest.main()


