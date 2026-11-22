output "repository" {
  description = "Full owner/repo slug managed by this stack."
  value       = "${var.github_owner}/${data.github_repository.this.name}"
}

output "default_branch" {
  description = "Configured default integration branch."
  value       = var.default_branch
}

output "release_topology" {
  description = "Active release topology (single, two-stage, or full-channels)."
  value       = var.release_topology
}

output "live_deploy_branch" {
  description = "Branch allowed to deploy to the production GitHub Environment."
  value       = local.live_deploy_branch
}

output "managed_channel_refs" {
  description = "Branch refs covered by the split release-channel rulesets."
  value       = local.channel_refs
}

output "rulesets_enabled" {
  description = "Whether split branch rulesets are active."
  value       = var.enable_rulesets
}

output "environments" {
  description = "Managed GitHub deployment environment names."
  value       = sort(keys(github_repository_environment.env))
}
