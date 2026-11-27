variable "github_owner" {
  description = "GitHub user or organization owning the target repository."
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+$", var.github_owner))
    error_message = "github_owner must be a single GitHub owner slug."
  }
}

variable "github_repository" {
  description = "Repository name (without owner prefix), e.g. foodsavr."
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must be the repository name without owner/."
  }
}

variable "default_branch" {
  description = "Default integration branch name."
  type        = string
  default     = "develop"
}

variable "manage_default_branch" {
  description = "Whether Terraform manages github_branch_default."
  type        = bool
  default     = true
}

variable "release_topology" {
  description = "Release channel topology: single (develop only), two-stage (develop -> stable), or full-channels (develop -> daily -> weekly -> stable)."
  type        = string
  default     = "single"
  validation {
    condition     = contains(["single", "two-stage", "full-channels"], var.release_topology)
    error_message = "release_topology must be single, two-stage, or full-channels."
  }
}

variable "channel_branches" {
  description = "Ordered branches from setup's release topology source."
  type        = list(string)
  default     = null
}

variable "enable_rulesets" {
  description = "Manage split branch rulesets. Automatically set to false on private repositories on GitHub Free."
  type        = bool
  default     = true
}

variable "manage_labels" {
  description = "Manage singular repository issue/PR labels sourced from .agents/github/labels.json."
  type        = bool
  default     = true
}

variable "labels_file" {
  description = "Path (absolute or relative to this module) to labels.json."
  type        = string
  default     = "../../../.agents/github/labels.json"
}

variable "release_gate_app_id" {
  description = "Numeric GitHub App ID for <owner>-<repo>-release-gate (0 if not yet provisioned). Never pass the untrusted agent App ID here."
  type        = number
  default     = 0
  validation {
    condition     = var.release_gate_app_id >= 0 && floor(var.release_gate_app_id) == var.release_gate_app_id
    error_message = "release_gate_app_id must be a non-negative integer."
  }
}

variable "agent_app_id" {
  description = "GitHub App ID for <owner>-<repo>-agent (stored as Actions variable AGENT_APP_ID; never granted ruleset bypass)."
  type        = string
  default     = ""
  validation {
    condition     = var.agent_app_id == "" || can(regex("^[0-9]+$", var.agent_app_id))
    error_message = "agent_app_id must be empty or a numeric GitHub App ID string."
  }
}

variable "environments" {
  description = "GitHub deployment environments to manage (production is branch-pinned to the active live deploy branch)."
  type        = list(string)
  default     = ["production"]
  validation {
    condition     = alltrue([for e in var.environments : can(regex("^[A-Za-z0-9_.-]+$", e))])
    error_message = "Environment names must match ^[A-Za-z0-9_.-]+$."
  }
}

variable "production_reviewers" {
  description = "Optional numeric GitHub user IDs required to approve deployments to the production environment."
  type        = list(number)
  default     = []
}

variable "actions_variables" {
  description = "Additional non-secret repository Actions variables. Must never include secret values or live operational kill-switches."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for k in keys(var.actions_variables) : !contains([
        "FIREBASE_HOSTING_ENABLED",
        "AUTO_HEAL_ENABLED",
        "AUTO_HEAL_MERGE",
        "AGENT_AUTO_REVIEW_ENABLED",
        "SELF_MANAGED_MERGE",
        "TELEMETRY_POLL_ENABLED",
        "MONITOR_TARGET_URL",
        "FIRESTORE_RULES_B64",
        "FIREBASE_OPTIONS_B64",
        "WEB_ENV_B64",
        "MERGE_GATE_TOKEN",
        "RELEASE_TOPOLOGY",
        "AGENT_APP_ID",
        "RELEASE_GATE_APP_ID",
      ], k)
    ])
    error_message = "actions_variables must not manage live kill-switches, secret-tier payloads, or dedicated Terraform variables (RELEASE_TOPOLOGY, AGENT_APP_ID, RELEASE_GATE_APP_ID)."
  }

  validation {
    condition = alltrue([
      for k in keys(var.actions_variables) : (
        k == "FACEBOOK_CLIENT_TOKEN" ||
        !can(regex("(_PRIVATE_KEY|_API_KEY|_OAUTH_TOKEN|_ACCESS_TOKEN|_SECRET|_SIGNING_|_SERVICE_ACCOUNT_JSON|_CREDENTIALS)$", k))
      )
    ])
    error_message = "actions_variables must only contain non-secret identifiers (no keys, private keys, or access tokens)."
  }
}

variable "environment_variables" {
  description = "Optional non-secret per-environment Actions variables keyed by environment name (e.g. production -> { GCP_WORKLOAD_IDENTITY_PROVIDER = ... })."
  type        = map(map(string))
  default     = {}

  validation {
    condition = alltrue(flatten([
      for env_name, vars in var.environment_variables : [
        for k in keys(vars) : !contains([
          "FIREBASE_HOSTING_ENABLED",
          "AUTO_HEAL_ENABLED",
          "AUTO_HEAL_MERGE",
          "AGENT_AUTO_REVIEW_ENABLED",
          "SELF_MANAGED_MERGE",
          "TELEMETRY_POLL_ENABLED",
          "MONITOR_TARGET_URL",
          "FIRESTORE_RULES_B64",
          "FIREBASE_OPTIONS_B64",
          "WEB_ENV_B64",
          "MERGE_GATE_TOKEN",
          ], k) && (
          k == "FACEBOOK_CLIENT_TOKEN" ||
          !can(regex("(_PRIVATE_KEY|_API_KEY|_OAUTH_TOKEN|_ACCESS_TOKEN|_SECRET|_SIGNING_|_SERVICE_ACCOUNT_JSON|_CREDENTIALS)$", k))
        )
      ]
    ]))
    error_message = "environment_variables must only contain non-secret, non-kill-switch identifiers."
  }
}

variable "instance_variables" {
  description = "Instance state published to CI (DEPLOY_INSTANCE overlay, FIREBASE_DEFINES_<ENV> client options), from the gitignored local state via scripts/instance_local.py ci-variables. Non-secret."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for k in keys(var.instance_variables) : k == "DEPLOY_INSTANCE" || can(regex("^FIREBASE_DEFINES(_[A-Z0-9]+)?$", k))
    ])
    error_message = "instance_variables only holds DEPLOY_INSTANCE and FIREBASE_DEFINES[_<ENV>]."
  }
}
