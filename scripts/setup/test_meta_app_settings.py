import unittest
from unittest.mock import Mock

from meta_app_settings import sync


class MetaAppSettingsTest(unittest.TestCase):
    project = "example-project"
    app_id = "123"
    token = "app-token"
    current = {"id": app_id, "app_domains": ["existing.example"]}
    desired = {
        "app_domains": [
            "existing.example",
            "example-project.web.app",
        ],
        "website_url": "https://example-project.web.app/",
        "privacy_policy_url": "https://example-project.web.app/privacy",
        "terms_of_service_url": "https://example-project.web.app/terms",
    }

    def test_check_reports_drift_without_writing(self):
        request = Mock(return_value=self.current)
        self.assertEqual(sync(self.project, self.app_id, self.token, True, request), 1)
        request.assert_called_once_with(
            f"https://graph.facebook.com/v27.0/{self.app_id}", self.token
        )

    def test_apply_preserves_existing_domains_and_is_idempotent(self):
        updated = {**self.current, **self.desired}
        request = Mock(side_effect=[self.current, {"success": True}, updated, updated])

        self.assertEqual(sync(self.project, self.app_id, self.token, False, request), 0)
        self.assertEqual(request.call_args_list[1].args[2], self.desired)

        self.assertEqual(sync(self.project, self.app_id, self.token, False, request), 0)
        self.assertEqual(len(request.call_args_list[3].args), 2)

    def test_legal_urls_follow_the_live_site(self):
        request = Mock(return_value=self.current)
        sync(self.project, self.app_id, self.token, True, request, site="example-live.web.app")
        from meta_app_settings import changed_settings
        updates = changed_settings(self.current, self.project, "example-live.web.app")
        self.assertEqual(updates["privacy_policy_url"], "https://example-live.web.app/privacy")
        self.assertIn("example-live.web.app", updates["app_domains"])

    def test_live_site_prefers_the_default_site_among_channel_sites(self):
        import json
        import os
        import sys
        from pathlib import Path
        sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
        import instance_local

        def overlay(channels):
            return {"DEPLOY_INSTANCE": json.dumps({"environments": {"test": {
                "firebase": {"projectId": "example-project"}, "channels": channels}}})}

        root = Path(os.devnull)
        both = overlay({"daily": "example-project-daily", "develop": "example-project"})
        self.assertEqual(instance_local.site_url(root, environ=both), "https://example-project.web.app")
        self.assertEqual(instance_local.site_url(root, channel="daily", environ=both), "https://example-project-daily.web.app")
        only = overlay({"weekly": "example-project-weekly", "daily": "example-project-daily"})
        self.assertEqual(instance_local.site_url(root, environ=only), "https://example-project-daily.web.app")

    def test_unreadable_domains_prevent_writes(self):
        request = Mock(return_value={**self.current, "app_domains": None})
        with self.assertRaises(ValueError):
            sync(self.project, self.app_id, self.token, False, request)
        self.assertEqual(request.call_count, 1)

    def test_write_must_be_verified(self):
        request = Mock(side_effect=[self.current, {"success": True}, self.current])
        with self.assertRaises(ValueError):
            sync(self.project, self.app_id, self.token, False, request)
