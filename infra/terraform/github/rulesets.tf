# Split release-channel rulesets per ADR 0007 and ADR 0008:
#
#   1. foodsavr-release-channels-integrity:
#      ZERO bypass actors. Enforces deletion protection, no force-pushes, and
#      linear history on every active channel branch.
#
#   2. foodsavr-release-channels-pr-gate:
#      Requires pull requests on active channel branches. Only repository admins
#      and the trusted ${OWNER}-${REPO}-release-gate App may bypass (to perform
#      fast-forward promotions and automated merge-gate integrations). The
#      untrusted ${OWNER}-${REPO}-agent App must NEVER be listed here.

resource "github_repository_ruleset" "release_channels_integrity" {
  count       = var.enable_rulesets ? 1 : 0
  name        = "foodsavr-release-channels-integrity"
  repository  = data.github_repository.this.name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = local.channel_refs
      exclude = []
    }
  }

  rules {
    deletion                = true
    non_fast_forward        = true
    required_linear_history = true
  }
}

resource "github_repository_ruleset" "release_channels_pr_gate" {
  count       = var.enable_rulesets ? 1 : 0
  name        = "foodsavr-release-channels-pr-gate"
  repository  = data.github_repository.this.name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = local.channel_refs
      exclude = []
    }
  }

  # Repository Admin role (built-in role ID 5) for owner emergency access.
  bypass_actors {
    actor_id    = 5
    actor_type  = "RepositoryRole"
    bypass_mode = "always"
  }

  dynamic "bypass_actors" {
    for_each = var.release_gate_app_id > 0 ? [var.release_gate_app_id] : []
    content {
      actor_id    = bypass_actors.value
      actor_type  = "Integration"
      bypass_mode = "always"
    }
  }

  rules {
    pull_request {
      dismiss_stale_reviews_on_push     = false
      require_code_owner_review         = false
      require_last_push_approval        = false
      required_approving_review_count   = 0
      required_review_thread_resolution = false
    }
  }
}
