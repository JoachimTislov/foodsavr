# Repository-scoped GitHub configuration for FoodSavr (ADR 0008).
# Manages split rulesets, deployment environments, non-secret Actions variables,
# singular labels (from .agents/github/labels.json), and default branch.
#
# Invariants:
#   - Never manages github_repository (read-only data source; cannot destroy repo).
#   - Never manages github_branch (channel refs are created via GitHub Refs API).
#   - Never stores secret values or overwrites live operational kill-switches.
#   - Uses worktree-safe XDG local state via scripts/infra/apply-github.sh.

terraform {
  required_version = ">= 1.6"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
  backend "local" {}
}

provider "github" {
  owner = var.github_owner
}

data "github_repository" "this" {
  name = var.github_repository
}

locals {
  live_deploy_branch = var.release_topology == "single" ? var.default_branch : "stable"

  channel_branches = (
    var.release_topology == "single"
    ? [var.default_branch]
    : (
      var.release_topology == "two-stage"
      ? [var.default_branch, "stable"]
      : [var.default_branch, "daily", "weekly", "stable"]
    )
  )

  channel_refs = [for b in local.channel_branches : "refs/heads/${b}"]

  labels_path = (
    startswith(var.labels_file, "/")
    ? var.labels_file
    : "${path.module}/${var.labels_file}"
  )

  raw_labels = var.manage_labels ? jsondecode(file(local.labels_path)).labels : []
  managed_labels = {
    for lbl in local.raw_labels : lbl.name => {
      color       = lbl.color
      description = try(lbl.description, "")
    }
  }
}

resource "github_branch_default" "default" {
  count      = var.manage_default_branch ? 1 : 0
  repository = data.github_repository.this.name
  branch     = var.default_branch
}

# Singular label resources avoid wiping custom/user labels on forks.
resource "github_issue_label" "managed" {
  for_each    = local.managed_labels
  repository  = data.github_repository.this.name
  name        = each.key
  color       = each.value.color
  description = each.value.description
}
