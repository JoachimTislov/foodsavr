#!/usr/bin/env python3
import importlib.util
import sys
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

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
            files=["specs/source-of-truth/decisions/0009-example.md"],
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
            files=["specs/source-of-truth/decisions/0009-example.md"],
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
            pr(3, files=[".github/workflows/ci-checks.yml"]),
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


if __name__ == "__main__":
    unittest.main()
