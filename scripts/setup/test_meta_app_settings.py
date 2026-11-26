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

    def test_unreadable_domains_prevent_writes(self):
        request = Mock(return_value={**self.current, "app_domains": None})
        with self.assertRaises(ValueError):
            sync(self.project, self.app_id, self.token, False, request)
        self.assertEqual(request.call_count, 1)

    def test_write_must_be_verified(self):
        request = Mock(side_effect=[self.current, {"success": True}, self.current])
        with self.assertRaises(ValueError):
            sync(self.project, self.app_id, self.token, False, request)
