variable "project_id" {
  description = "Firebase project of the environment (from deploy/instance.yaml via scripts/infra/apply.sh)."
  type        = string
}

variable "region" {
  description = "Default GCP/Firebase region from deploy/instance.yaml."
  type        = string
  default     = "europe-north1"
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
  description = "UNENFORCED | ENFORCED for Firestore, Auth, Storage. Register every client (incl. Android Play Integrity) before ENFORCED."
  type        = string
  default     = "UNENFORCED"
  validation {
    condition     = contains(["UNENFORCED", "ENFORCED"], var.app_check_enforcement)
    error_message = "Must be UNENFORCED or ENFORCED."
  }
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
