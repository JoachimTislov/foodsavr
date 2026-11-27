variable "project_id" {
  description = "Firebase project of the environment (from deploy/instance.yaml via scripts/infra/apply.sh)."
  type        = string
}

variable "region" {
  description = "Default GCP/Firebase region from deploy/instance.yaml."
  type        = string
  default     = "europe-north1"
}

variable "firestore_location" {
  description = "Location of the existing Firestore (default) database when adopted; empty uses var.region."
  type        = string
  default     = ""
}

variable "github_repository" {
  description = "owner/repo allowed to authenticate via Workload Identity Federation."
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must be in owner/repo format."
  }
}

variable "release_topology" {
  description = "Release branch topology (single, two-stage, full-channels); controls default deploy branch when deploy_branch is unset."
  type        = string
  default     = "full-channels"
  validation {
    condition     = contains(["single", "two-stage", "full-channels"], var.release_topology)
    error_message = "release_topology must be single, two-stage, or full-channels."
  }
}

variable "deploy_branch" {
  description = "Optional branch override allowed to impersonate github-deploy-live (defaults to develop in single topology, else stable)."
  type        = string
  default     = ""
}

variable "deploy_branches" {
  description = "Release channels (branches) this environment deploys, from deploy/instance.yaml; each may impersonate github-deploy-live with github_environment. Empty falls back to deploy_branch."
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for b in var.deploy_branches : can(regex("^[a-z0-9][a-z0-9-]*$", b))])
    error_message = "deploy_branches must be branch names (lower-kebab-case)."
  }
}

variable "hosting_sites" {
  description = "Extra Firebase Hosting sites (one per release channel) created in the project; the default site is not managed."
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for s in var.hosting_sites : can(regex("^[a-z0-9][a-z0-9-]{4,28}[a-z0-9]$", s))])
    error_message = "hosting_sites must be valid Hosting site ids."
  }
}

variable "telemetry_branch" {
  description = "Branch allowed to impersonate github-telemetry-ro for scheduled telemetry and deployment-level polling."
  type        = string
  default     = "develop"
}

variable "github_environment" {
  description = "GitHub Environment name required in OIDC tokens impersonating github-deploy-live."
  type        = string
  default     = "production"
}

variable "allow_preview_refs" {
  description = "When true (non-production staging environments only), allows any branch deploying to github_environment to impersonate github-deploy-live."
  type        = bool
  default     = false
}

variable "web_app_id" {
  type = string
}

variable "web_api_key_id" {
  type = string
}

variable "app_check_enforcement" {
  description = "ENFORCED | UNENFORCED for Firestore and Storage. apply.sh keeps the live mode unless APP_CHECK_ENFORCEMENT is set. Every client needs a valid App Check token once ENFORCED (web: reCAPTCHA Enterprise key in the build; Android: Play Integrity)."
  type        = string
  default     = "UNENFORCED"
  validation {
    condition     = contains(["UNENFORCED", "ENFORCED"], var.app_check_enforcement)
    error_message = "Must be UNENFORCED or ENFORCED."
  }
}

variable "app_check_auth_enforcement" {
  description = "UNENFORCED | ENFORCED for Firebase Authentication (preview; needs the Identity Platform upgrade)."
  type        = string
  default     = "UNENFORCED"
  validation {
    condition     = contains(["UNENFORCED", "ENFORCED"], var.app_check_auth_enforcement)
    error_message = "Must be UNENFORCED or ENFORCED."
  }
}

variable "android_app_id" {
  description = "Firebase Android app id (package com.foodsavr.app) for Play Integrity; discovered by scripts/infra/adopt.py firebase. Empty: no Android App Check config."
  type        = string
  default     = ""
}

variable "firebase_plan" {
  description = "Firebase billing plan for this instance: spark (free) or blaze (pay-as-you-go)."
  type        = string
  default     = "spark"
  validation {
    condition     = contains(["spark", "blaze"], var.firebase_plan)
    error_message = "Must be spark or blaze."
  }
}

# Firebase's auto-created allow-list for the browser key.
variable "web_api_key_services" {
  type = list(string)
  default = [
    "firebasedatabase.googleapis.com", "firebasehosting.googleapis.com", "firebaserules.googleapis.com",
    "sqladmin.googleapis.com", "cloudconfig.googleapis.com", "datastore.googleapis.com",
    "fcmregistrations.googleapis.com", "firebase.googleapis.com", "firebaseappcheck.googleapis.com",
    "firebaseappdistribution.googleapis.com", "firebaseapphosting.googleapis.com",
    "firebaseapptesters.googleapis.com", "firebasedataconnect.googleapis.com",
    "firebaseinappmessaging.googleapis.com", "firebaseinstallations.googleapis.com",
    "firebaseml.googleapis.com", "firebaseremoteconfig.googleapis.com",
    "firebaseremoteconfigrealtime.googleapis.com", "firebasestorage.googleapis.com",
    "firebasevertexai.googleapis.com", "firestore.googleapis.com", "identitytoolkit.googleapis.com",
    "logging.googleapis.com", "mlkit.googleapis.com", "play.googleapis.com", "securetoken.googleapis.com",
  ]
}

# Deployment level of this environment (deploy/instance.yaml, ADR 0005).
variable "level" {
  description = "Firebase deployment level: firebase-spark (free) or firebase-blaze (pay-as-you-go, budget required)."
  type        = string
  default     = "firebase-spark"
  validation {
    condition     = contains(["firebase-spark", "firebase-blaze"], var.level)
    error_message = "Must be firebase-spark or firebase-blaze; other levels are spec-ahead."
  }
}

# Linking the billing account to the project stays a manual owner step.
variable "billing_account" {
  description = "Billing account id (XXXXXX-XXXXXX-XXXXXX) for the budget; required on firebase-blaze."
  type        = string
  default     = ""
}

variable "monthly_budget_usd" {
  description = "Monthly budget on firebase-blaze (alerts only; Blaze has no hard cap)."
  type        = number
  default     = 0
}

variable "deploy_service_account_id" {
  description = "Deployment service account ID. Local state recovery can adopt the legacy Hosting deploy account."
  type        = string
  default     = "github-deploy-live"
}

variable "local_recovery" {
  description = "Records local recovery provenance in saved plans for apply.sh."
  type        = bool
  default     = false
}

# apply.sh sets both to the tracked repository files; the defaults serve
# `terraform validate` in place.
variable "firestore_rules_file" {
  description = "Path of the tracked firestore.rules (ADR 0010) released to the (default) database."
  type        = string
  default     = ""
}

variable "firestore_indexes_file" {
  description = "Path of the tracked firestore.indexes.json whose composite indexes are deployed."
  type        = string
  default     = ""
}

variable "identity_providers" {
  description = "Sign-in providers to manage (google.com, facebook.com) with their public client ids; apply.sh lists those whose credentials are present."
  type        = map(object({ client_id = string }))
  default     = {}
  validation {
    condition     = alltrue([for idp in keys(var.identity_providers) : contains(["google.com", "facebook.com"], idp)])
    error_message = "identity_providers supports google.com and facebook.com."
  }
}

variable "identity_provider_secrets" {
  description = "Client secret per identity_providers key, only via TF_VAR_identity_provider_secrets (never tfvars or argv)."
  type        = map(string)
  default     = {}
  sensitive   = true
}
