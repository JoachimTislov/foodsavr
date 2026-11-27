# Deployment environments and non-secret Actions variables (ADR 0008).

locals {
  flat_environment_variables = merge([
    for env_name, vars in var.environment_variables : {
      for k, v in vars : "${env_name}/${k}" => {
        environment = env_name
        name        = k
        value       = v
      }
    }
  ]...)
}

resource "github_repository_environment" "env" {
  for_each    = setunion(toset(var.environments), ["test"])
  repository  = data.github_repository.this.name
  environment = each.key

  dynamic "reviewers" {
    for_each = each.key == "production" && length(var.production_reviewers) > 0 ? [1] : []
    content {
      users = var.production_reviewers
    }
  }

  dynamic "deployment_branch_policy" {
    for_each = contains(["production", "test"], each.key) ? [1] : []
    content {
      protected_branches     = false
      custom_branch_policies = true
    }
  }
}

resource "github_repository_environment_deployment_policy" "production_release" {
  count          = contains(var.environments, "production") ? 1 : 0
  repository     = data.github_repository.this.name
  environment    = github_repository_environment.env["production"].environment
  branch_pattern = local.live_deploy_branch
}

# Test accepts branch-based previews, including feature branches with slashes.
resource "github_repository_environment_deployment_policy" "test_branches" {
  repository     = data.github_repository.this.name
  environment    = github_repository_environment.env["test"].environment
  branch_pattern = "**/*"
}

# "**/*" requires a slash, so top-level branches (develop, daily, weekly) need their own policy.
resource "github_repository_environment_deployment_policy" "test_top_level_branches" {
  repository     = data.github_repository.this.name
  environment    = github_repository_environment.env["test"].environment
  branch_pattern = "*"
}

resource "github_actions_variable" "release_topology" {
  repository    = data.github_repository.this.name
  variable_name = "RELEASE_TOPOLOGY"
  value         = var.release_topology
}

resource "github_actions_variable" "agent_app_id" {
  count         = var.agent_app_id != "" ? 1 : 0
  repository    = data.github_repository.this.name
  variable_name = "AGENT_APP_ID"
  value         = var.agent_app_id
}

resource "github_actions_variable" "release_gate_app_id" {
  count         = var.release_gate_app_id > 0 ? 1 : 0
  repository    = data.github_repository.this.name
  variable_name = "RELEASE_GATE_APP_ID"
  value         = tostring(var.release_gate_app_id)
}

resource "github_actions_variable" "custom" {
  for_each      = var.actions_variables
  repository    = data.github_repository.this.name
  variable_name = each.key
  value         = each.value
}

# Instance state (ADR 0008): the repository is stateless, so CI reads this
# clone's deployment identity and Firebase client options from variables.
resource "github_actions_variable" "instance" {
  for_each      = var.instance_variables
  repository    = data.github_repository.this.name
  variable_name = each.key
  value         = each.value

  # A rerun from a clone without the local overlay or defines passes an empty
  # map; refuse to delete the published variables CI deploys from. Removing one
  # is an explicit operator decision (terraform state rm, then delete it in GitHub).
  lifecycle {
    prevent_destroy = true
  }
}

resource "github_actions_environment_variable" "env_vars" {
  for_each      = local.flat_environment_variables
  repository    = data.github_repository.this.name
  environment   = github_repository_environment.env[each.value.environment].environment
  variable_name = each.value.name
  value         = each.value.value
}
