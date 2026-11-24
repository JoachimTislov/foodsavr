output "workload_identity_provider" {
  description = "Full Workload Identity Provider resource name for google-github-actions/auth."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "deploy_service_account" {
  description = "Scoped deploy service account email (github-deploy-live) for Firebase Hosting deploys."
  value       = google_service_account.deploy_live.email
}

output "telemetry_service_account" {
  description = "Read-only telemetry service account email (github-telemetry-ro) for monitoring and deployment-level polling."
  value       = google_service_account.telemetry_ro.email
}

output "recaptcha_enterprise_site_key" {
  description = "Public reCAPTCHA Enterprise site key resource name for App Check web."
  value       = google_recaptcha_enterprise_key.web.name
}

output "firebase_plan" {
  description = "Configured Firebase billing plan (spark or blaze)."
  value       = var.firebase_plan
}

output "deploy_branch" {
  description = "Primary branch bound to github-deploy-live WIF impersonation."
  value       = local.deploy_branches[0]
}

output "deploy_branches" {
  description = "All release channels bound to github-deploy-live WIF impersonation."
  value       = var.allow_preview_refs ? [] : local.deploy_branches
}

output "hosting_sites" {
  description = "Hosting sites the environment deploys to (default site first)."
  value       = local.hosting_sites
}

output "github_environment" {
  description = "GitHub Environment bound to github-deploy-live WIF impersonation."
  value       = var.github_environment
}
