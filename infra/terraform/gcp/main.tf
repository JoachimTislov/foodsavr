# Firebase / Google Cloud configuration for one environment of the instance
# declared in deploy/instance.yaml (ADR 0005, ADR 0008).
# Apply with scripts/infra/apply.sh (uses your gcloud login; GCS state on Blaze
# or worktree-safe XDG local state on Spark).

terraform {
  required_version = ">= 1.6"
  required_providers {
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 7.0"
    }
  }
  backend "gcs" {
    prefix = "firebase"
  }
}

provider "google-beta" {
  project               = var.project_id
  user_project_override = true
  billing_project       = var.project_id
}

data "google_project" "this" {
  provider = google-beta
}

locals {
  project_number = data.google_project.this.number
  # Default site plus one site per release channel (deploy/instance.yaml).
  hosting_sites = distinct(concat([var.project_id], var.hosting_sites))
  live_domains = flatten([
    for site in local.hosting_sites : ["${site}.web.app", "${site}.firebaseapp.com"]
  ])
  is_blaze   = var.firebase_plan == "blaze"
  paid_level = var.level == "firebase-blaze"

  effective_deploy_branch = (
    var.deploy_branch != ""
    ? var.deploy_branch
    : (var.release_topology == "single" ? "develop" : "stable")
  )

  # Release channels this environment deploys (deploy/instance.yaml); the
  # first keeps the original binding, the others get their own.
  deploy_branches = (
    length(var.deploy_branches) > 0
    ? var.deploy_branches
    : [local.effective_deploy_branch]
  )
  extra_deploy_branches = toset(slice(local.deploy_branches, 1, length(local.deploy_branches)))

  deploy_wif_member = (
    var.allow_preview_refs
    ? "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repo_env/${var.github_repository}:${var.github_environment}"
    : "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repo_ref_env/${var.github_repository}:refs/heads/${local.deploy_branches[0]}:${var.github_environment}"
  )

  telemetry_wif_member = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repo_ref/${var.github_repository}:refs/heads/${var.telemetry_branch}"

  base_apis = [
    "apikeys.googleapis.com",
    "recaptchaenterprise.googleapis.com",
    "firebaseappcheck.googleapis.com",
    "firebasehosting.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
  ]
  blaze_apis = local.is_blaze ? [
    "firebasetelemetry.googleapis.com",
    "firebasetelemetryadmin.googleapis.com",
  ] : []
  web_api_key_services = distinct(concat(
    var.web_api_key_services,
    local.is_blaze ? ["firebasetelemetry.googleapis.com"] : [],
  ))
}

resource "google_project_service" "apis" {
  provider           = google-beta
  for_each           = toset(concat(local.base_apis, local.blaze_apis))
  service            = each.key
  disable_on_destroy = false
}

# ---------------------------------------------------------------------------
# Web app (existing; imported)
# ---------------------------------------------------------------------------

import {
  to = google_firebase_web_app.web
  id = "projects/${var.project_id}/webApps/${var.web_app_id}"
}

resource "google_firebase_web_app" "web" {
  provider        = google-beta
  display_name    = "app (web)"
  api_key_id      = var.web_api_key_id
  deletion_policy = "ABANDON"
}

# ---------------------------------------------------------------------------
# Hosting sites of the release channels (multiple sites work on Spark). The
# default site (project id) already exists and is not managed here. A web app
# links to at most one site, so channel sites stay unlinked (the web config
# comes from the app, not the site).
# ---------------------------------------------------------------------------

resource "google_firebase_hosting_site" "channel" {
  provider   = google-beta
  for_each   = toset([for site in var.hosting_sites : site if site != var.project_id])
  project    = var.project_id
  site_id    = each.key
  depends_on = [google_project_service.apis]
}

# ---------------------------------------------------------------------------
# Browser API key: keep Firebase's API allow-list, add referrer restriction.
# ---------------------------------------------------------------------------

import {
  to = google_apikeys_key.web
  id = "projects/${var.project_id}/locations/global/keys/${var.web_api_key_id}"
}

resource "google_apikeys_key" "web" {
  provider     = google-beta
  name         = var.web_api_key_id
  display_name = "Browser key (auto created by Firebase)"

  restrictions {
    browser_key_restrictions {
      allowed_referrers = concat(
        [for d in local.live_domains : "https://${d}/*"],
        [for site in local.hosting_sites : "https://${site}--*.web.app/*"], # Hosting preview channels
        ["http://localhost:*/*", "http://127.0.0.1:*/*"],
      )
    }

    dynamic "api_targets" {
      for_each = local.web_api_key_services
      content {
        service = api_targets.value
      }
    }
  }
}

# ---------------------------------------------------------------------------
# App Check: reCAPTCHA Enterprise for web (v3 no longer accepted for new
# setups); enforcement per service.
# ---------------------------------------------------------------------------

resource "google_recaptcha_enterprise_key" "web" {
  provider     = google-beta
  display_name = "FoodSavr web (App Check)"

  web_settings {
    integration_type  = "SCORE"
    allow_all_domains = false
    # Preview channels (<site>--<channel>.web.app) are not covered; App Check
    # tokens fail there, which only matters once enforcement is ENFORCED.
    allowed_domains = concat(local.live_domains, ["localhost", "127.0.0.1"])
  }

  depends_on = [google_project_service.apis]
}

resource "google_firebase_app_check_recaptcha_enterprise_config" "web" {
  provider  = google-beta
  app_id    = google_firebase_web_app.web.app_id
  site_key  = google_recaptcha_enterprise_key.web.name
  token_ttl = "3600s"
}

resource "google_firebase_app_check_service_config" "enforcement" {
  provider         = google-beta
  for_each         = toset(["firestore.googleapis.com", "identitytoolkit.googleapis.com", "firebasestorage.googleapis.com"])
  service_id       = each.key
  enforcement_mode = var.app_check_enforcement
}

# ---------------------------------------------------------------------------
# GitHub Actions -> Google Cloud without keys (scoped Workload Identity, ADR 0008).
# Split into two least-privilege service accounts:
#   1. github-deploy-live  — write deploy permissions, bound to repo + branch + env
#   2. github-telemetry-ro — read-only telemetry/levels polling, bound to repo + default branch
# ---------------------------------------------------------------------------

resource "google_iam_workload_identity_pool" "github" {
  provider                  = google-beta
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"
  depends_on                = [google_project_service.apis]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  provider                           = google-beta
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.ref"              = "assertion.ref"
    "attribute.environment"      = "has(assertion.environment) ? assertion.environment : ''"
    "attribute.job_workflow_ref" = "assertion.job_workflow_ref"
    "attribute.repo_ref"         = "assertion.repository + ':' + assertion.ref"
    "attribute.repo_env"         = "assertion.repository + ':' + (has(assertion.environment) ? assertion.environment : '')"
    "attribute.repo_ref_env"     = "assertion.repository + ':' + assertion.ref + ':' + (has(assertion.environment) ? assertion.environment : '')"
  }
  # Only tokens minted for this repository are accepted.
  attribute_condition = "assertion.repository == '${var.github_repository}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "deploy_live" {
  provider     = google-beta
  account_id   = var.deploy_service_account_id
  display_name = "GitHub Actions: Firebase Hosting deploy (scoped)"

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_project_iam_member" "deploy_live" {
  provider = google-beta
  for_each = toset([
    "roles/firebasehosting.admin",             # deploy live + preview channels
    "roles/firebase.viewer",                   # read web SDK config at build time
    "roles/firebaseauth.admin",                # add preview domains to Auth
    "roles/serviceusage.apiKeysViewer",        # resolve web API key
    "roles/serviceusage.serviceUsageConsumer", # call Firebase APIs
  ])
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.deploy_live.email}"
}

resource "google_service_account_iam_member" "github_impersonates_deploy_live" {
  provider           = google-beta
  service_account_id = google_service_account.deploy_live.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.deploy_wif_member

  lifecycle {
    precondition {
      condition     = !(var.allow_preview_refs && var.github_environment == "production")
      error_message = "allow_preview_refs would let any branch deploy production; keep it for non-production environments."
    }
  }
}

# Further release channels of the same environment (e.g. daily and weekly
# beside develop in the test project), each bound to branch + environment.
resource "google_service_account_iam_member" "github_impersonates_deploy_live_channels" {
  provider           = google-beta
  for_each           = var.allow_preview_refs ? toset([]) : local.extra_deploy_branches
  service_account_id = google_service_account.deploy_live.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repo_ref_env/${var.github_repository}:refs/heads/${each.key}:${var.github_environment}"
}

resource "google_service_account" "telemetry_ro" {
  provider     = google-beta
  account_id   = "github-telemetry-ro"
  display_name = "GitHub Actions: Firebase telemetry & levels poll (read-only)"

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_project_iam_member" "telemetry_ro" {
  provider = google-beta
  for_each = toset(concat([
    "roles/datastore.viewer",                  # Spark-safe read-only Firestore runtime_errors polling
    "roles/monitoring.viewer",                 # levels poll: Firestore op counts
    "roles/firebaseauth.viewer",               # levels poll: user count
    "roles/firebase.viewer",                   # read Firebase project metadata
    "roles/serviceusage.serviceUsageConsumer", # quota project header on API calls
  ], local.is_blaze ? ["roles/logging.viewer"] : []))
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.telemetry_ro.email}"
}

resource "google_service_account_iam_member" "github_impersonates_telemetry_ro" {
  provider           = google-beta
  service_account_id = google_service_account.telemetry_ro.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.telemetry_wif_member
}

# ---------------------------------------------------------------------------
# Paid level guard (ADR 0005): firebase-blaze must have a budget. Budgets only
# alert (Pub/Sub costAmount messages); they never cap spend.
# ---------------------------------------------------------------------------

resource "google_project_service" "billing_budgets" {
  provider           = google-beta
  count              = local.paid_level ? 1 : 0
  service            = "billingbudgets.googleapis.com"
  disable_on_destroy = false
}

resource "google_billing_budget" "monthly" {
  provider        = google-beta
  count           = local.paid_level ? 1 : 0
  billing_account = var.billing_account
  display_name    = "${var.project_id} monthly (${var.level})"

  budget_filter {
    projects = ["projects/${local.project_number}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.monthly_budget_usd)
    }
  }

  dynamic "threshold_rules" {
    for_each = [0.5, 0.9, 1.0]
    content {
      threshold_percent = threshold_rules.value
    }
  }

  lifecycle {
    precondition {
      condition     = var.billing_account != "" && var.monthly_budget_usd > 0
      error_message = "firebase-blaze needs billing_account and monthly_budget_usd > 0 (budget in deploy/instance.yaml)."
    }
  }

  depends_on = [google_project_service.billing_budgets]
}
