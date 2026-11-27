# ---------------------------------------------------------------------------
# Firebase Auth sign-in providers with client secrets (Google, Facebook).
# Email/Password, Anonymous and the authorized domains are not here:
# scripts/infra/firebase_config.py applies them (no billing needed, runtime
# preview domains kept). Creating the Google OAuth web client and the Meta app
# has no API; scripts/human/google and scripts/human/meta do that.
#
# The secrets come from TF_VAR_identity_provider_secrets (scripts/infra/apply.sh,
# from .env). They are redacted in plans but stored in state, which is private
# (0600, outside git; ADR 0008 amendment 2026-11-27). A provider without
# credentials is not managed; apply.sh refuses to plan when a managed one loses
# its credentials, so a missing .env value never removes sign-in.
# ---------------------------------------------------------------------------

resource "google_identity_platform_default_supported_idp_config" "idp" {
  provider        = google-beta
  for_each        = var.identity_providers
  idp_id          = each.key
  client_id       = each.value.client_id
  client_secret   = lookup(var.identity_provider_secrets, each.key, "")
  enabled         = true
  deletion_policy = "ABANDON"
  depends_on      = [google_project_service.apis]

  lifecycle {
    precondition {
      condition     = nonsensitive(lookup(var.identity_provider_secrets, each.key, "") != "")
      error_message = "Every identity_providers entry needs a client secret in TF_VAR_identity_provider_secrets."
    }
  }
}
