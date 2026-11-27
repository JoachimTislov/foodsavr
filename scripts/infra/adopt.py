"""Discover existing infrastructure for Terraform import blocks, using read-only APIs."""

import json
import os
from pathlib import Path
import subprocess
import sys
from urllib.error import HTTPError
from urllib.request import Request, urlopen


def hcl_string(value):
    return json.dumps(value).replace("${", "$${").replace("%{", "%%{")


def imports_file(directory, resources, name="adopt.tf", extra=()):
    # Import blocks leave state untouched until apply.
    blocks = [f"import {{\n  to = {address}\n  id = {hcl_string(resource_id)}\n}}\n" for address, resource_id in resources.items()]
    (Path(directory) / name).write_text("\n".join([*blocks, *extra]))


def command_json(*argv):
    result = subprocess.run(argv, text=True, capture_output=True, timeout=90)
    if result.returncode:
        raise ValueError(f"Cannot read {argv[0]} inventory for {argv[1]}. Check account permissions.")
    return json.loads(result.stdout)


def github_resources(directory, repo, enable_rulesets):
    def pages(path, key=None):
        result = command_json("gh", "api", "--paginate", "--slurp", f"repos/{repo}/{path}")
        return [item for page in result for item in (page[key] if key else page)]

    labels = {label["name"].casefold(): label["name"] for label in pages("labels?per_page=100")}
    variables = {item["name"]: item["value"] for item in pages("actions/variables?per_page=100", "variables")}
    environments = {item["name"]: item for item in pages("environments?per_page=100", "environments")}
    production = environments.get("production", {})
    policies = {}
    if (production.get("deployment_branch_policy") or {}).get("custom_branch_policies"):
        policies = {
            row["name"]: str(row["id"])
            for row in pages("environments/production/deployment-branch-policies?per_page=100", "branch_policies")
            if row.get("type", "branch") == "branch"
        }
    rulesets = {}
    if enable_rulesets == "true":
        existing_rulesets = pages("rulesets?includes_parents=false&per_page=100")
        for name in ("integrity", "pr-gate"):
            item = lookup(
                existing_rulesets,
                lambda item: item["name"] == f"foodsavr-release-channels-{name}",
                f"{name} rulesets",
            )
            if item:
                rulesets[name] = str(item["id"])

    def local(name, data):
        encoded = json.dumps(json.dumps(data)).replace("${", "$${").replace("%{", "%%{")
        return f"  {name} = jsondecode({encoded})\n"

    def import_block(address, suffix, items):
        return f"""import {{
  for_each = {items}
  to = {address}
  id = "${{var.github_repository}}:{suffix}"
}}
"""

    blocks = ["locals {\n" + local("existing_labels", labels) + local("existing_rulesets", rulesets)
              + local("existing_variables", sorted(variables)) + local("existing_environments", sorted(environments))
              + local("existing_production_policies", policies) + "}\n"]
    blocks.append(import_block(
        "github_issue_label.managed[each.key]", "${each.value}",
        "{ for name in keys(local.managed_labels) : name => local.existing_labels[lower(name)] if contains(keys(local.existing_labels), lower(name)) }",
    ))
    blocks.append("""import {
  for_each = var.manage_default_branch ? { existing = true } : {}
  to = github_branch_default.default[0]
  id = var.github_repository
}
""")
    blocks.append(import_block(
        "github_repository_environment.env[each.key]", "${each.key}",
        "setintersection(toset(var.environments), toset(local.existing_environments))",
    ))
    blocks.append(import_block(
        "github_repository_environment_deployment_policy.production_release[0]", "production:${each.value}",
        '{ for branch, id in local.existing_production_policies : branch => id if branch == local.live_deploy_branch && contains(var.environments, "production") }',
    ))
    for key, field, enabled in (
        ("RELEASE_TOPOLOGY", "release_topology", "true"),
        ("AGENT_APP_ID", "agent_app_id[0]", 'var.agent_app_id != ""'),
        ("RELEASE_GATE_APP_ID", "release_gate_app_id[0]", "var.release_gate_app_id > 0"),
    ):
        blocks.append(import_block(
            f"github_actions_variable.{field}", key,
            f'({enabled}) && contains(local.existing_variables, "{key}") ? {{ existing = true }} : {{}}',
        ))
    blocks.append(import_block(
        "github_actions_variable.instance[each.key]", "${each.key}",
        "{ for name in keys(var.instance_variables) : name => name if contains(local.existing_variables, name) }",
    ))
    for name in rulesets:
        blocks.append(import_block(
            f"github_repository_ruleset.release_channels_{name.replace('-', '_')}[0]", "${each.value}",
            f'var.enable_rulesets ? {{ existing = local.existing_rulesets["{name}"] }} : {{}}',
        ))
    (Path(directory) / "adopt.tf").write_text("\n".join(blocks))
    print(json.dumps({name: variables.get(name, "") for name in ("AGENT_APP_ID", "RELEASE_GATE_APP_ID", "RELEASE_TOPOLOGY")}))


BASE_APIS = {
    "apikeys.googleapis.com", "recaptchaenterprise.googleapis.com", "firebaseappcheck.googleapis.com",
    "firebasehosting.googleapis.com", "firebaserules.googleapis.com", "firestore.googleapis.com",
    "iam.googleapis.com", "iamcredentials.googleapis.com", "identitytoolkit.googleapis.com",
    "playintegrity.googleapis.com", "sts.googleapis.com",
}
BLAZE_APIS = {"firebasetelemetry.googleapis.com", "firebasetelemetryadmin.googleapis.com"}
APP_CHECK_SERVICES = {"firestore.googleapis.com", "identitytoolkit.googleapis.com", "firebasestorage.googleapis.com"}
DEPLOY_ROLES = {
    "roles/firebasehosting.admin", "roles/firebase.viewer", "roles/firebaseauth.admin",
    "roles/serviceusage.apiKeysViewer", "roles/serviceusage.serviceUsageConsumer",
}
TELEMETRY_ROLES = {
    "roles/datastore.viewer", "roles/monitoring.viewer", "roles/firebaseauth.viewer",
    "roles/firebase.viewer", "roles/serviceusage.serviceUsageConsumer",
}


def google_get(project, url, label, *, missing_ok=False):
    """GET a Google API resource; 404 is {} when missing_ok. Callers keep only names."""
    request = Request(url, headers={
        "Authorization": f"Bearer {os.environ['GOOGLE_OAUTH_ACCESS_TOKEN']}",
        "x-goog-user-project": project,
    })
    try:
        with urlopen(request, timeout=30) as response:
            return json.load(response)
    except HTTPError as error:
        error.close()
        if missing_ok and error.code == 404:
            return {}
        raise ValueError(f"Cannot read {label}. Check permissions in the Firebase console.") from None


def app_check_get(project, path, *, missing_ok=False):
    return google_get(project, f"https://firebaseappcheck.googleapis.com/v1beta/{path}", "Firebase App Check", missing_ok=missing_ok)


def hosting_sites(project):
    request = Request(f"https://firebasehosting.googleapis.com/v1beta1/projects/{project}/sites?pageSize=100", headers={
        "Authorization": f"Bearer {os.environ['GOOGLE_OAUTH_ACCESS_TOKEN']}",
        "x-goog-user-project": project,
    })
    try:
        with urlopen(request, timeout=30) as response:
            return json.load(response).get("sites", [])
    except HTTPError:
        raise ValueError("Cannot list Firebase Hosting sites. Check permissions in the Firebase console.") from None


def lookup(items, matches, label):
    found = [item for item in items if matches(item)]
    if len(found) > 1:
        raise ValueError(f"Multiple {label} match. Resolve the duplicate before continuing.")
    return found[0] if found else None


def gcp_resources(directory, project, app, repo, environment, deploy_branch, integration_branch, preview, level, billing, account):
    def cloud(*args):
        account_arg = (f"--account={account}",) if account else ()
        return command_json("gcloud", *account_arg, *args, f"--project={project}", "--format=json")

    def import_item(address, item):
        if item:
            resources[address] = item["name"]

    def members(policy):
        return {
            (binding["role"], member)
            for binding in policy.get("bindings", []) if not binding.get("condition")
            for member in binding.get("members", [])
        }

    resources = {}
    project_info = cloud("projects", "describe", project)
    project_number = project_info["projectNumber"]
    project_path = f"projects/{project_number}"
    enabled = {item["config"]["name"] for item in cloud("services", "list", "--enabled")}
    blaze = level == "firebase-blaze"

    def indexed(address, key):
        return f"{address}[{json.dumps(key)}]"

    for api in sorted(enabled & (BASE_APIS | (BLAZE_APIS if blaze else set()))):
        resources[indexed("google_project_service.apis", api)] = f"{project}/{api}"

    config = {}
    if "firebaseappcheck.googleapis.com" in enabled:
        path = f"{project_path}/apps/{app}/recaptchaEnterpriseConfig"
        config = app_check_get(project, path, missing_ok=True)
        if config.get("siteKey"):
            resources["google_firebase_app_check_recaptcha_enterprise_config.web"] = path
        for service in sorted(APP_CHECK_SERVICES):
            path = f"{project_path}/services/{service}"
            if app_check_get(project, path, missing_ok=True).get("name"):
                resources[indexed("google_firebase_app_check_service_config.enforcement", service)] = path

    if "recaptchaenterprise.googleapis.com" in enabled:
        keys = cloud("recaptcha", "keys", "list")
        if config.get("siteKey"):
            site_key_id = config["siteKey"].rsplit("/", 1)[-1]
            key = lookup(keys, lambda item: item["name"].rsplit("/", 1)[-1] == site_key_id, "App Check keys")
            if key is None:
                raise ValueError("Cannot find the reCAPTCHA key configured for this app.")
        else:
            key = lookup(keys, lambda item: item.get("displayName") == "FoodSavr web (App Check)", "App Check keys")
        import_item("google_recaptcha_enterprise_key.web", key)
    elif config.get("siteKey"):
        raise ValueError("Enable read access to reCAPTCHA Enterprise before adopting the configured App Check key.")

    # Channel sites the manifest declares (HOSTING_SITES, a JSON list) that already exist.
    wanted = set(json.loads(os.environ.get("HOSTING_SITES") or "[]")) - {project}
    if wanted and "firebasehosting.googleapis.com" in enabled:
        for site in hosting_sites(project):
            site_id = site["name"].rsplit("/", 1)[-1]
            if site_id in wanted:
                resources[indexed("google_firebase_hosting_site.channel", site_id)] = site["name"]

    pool_path = f"{project_path}/locations/global/workloadIdentityPools/github"
    if "iam.googleapis.com" in enabled:
        pools = cloud("iam", "workload-identity-pools", "list", "--location=global")
        pool = lookup(pools, lambda item: item["name"].endswith("/github"), "GitHub identity pools")
        if pool:
            pool_path = pool["name"]
            import_item("google_iam_workload_identity_pool.github", pool)
            providers = cloud("iam", "workload-identity-pools", "providers", "list", "--location=global", "--workload-identity-pool=github")
            import_item("google_iam_workload_identity_pool_provider.github", lookup(
                providers, lambda item: item["name"].endswith("/github-oidc"), "GitHub OIDC providers",
            ))
    accounts = cloud("iam", "service-accounts", "list") if "iam.googleapis.com" in enabled else []
    by_email = {item["email"]: item for item in accounts}
    domain = f"{project}.iam.gserviceaccount.com"
    deploy_id = "github-deploy-live"
    legacy_id = "github-hosting-deploy"
    if f"{deploy_id}@{domain}" not in by_email and f"{legacy_id}@{domain}" in by_email:
        deploy_id = legacy_id
    project_members = members(cloud("projects", "get-iam-policy", project)) if accounts else set()
    principal = f"principalSet://iam.googleapis.com/{pool_path}/attribute."
    deploy_principal = f"{principal}repo_env/{repo}:{environment}" if preview == "true" else (
        f"{principal}repo_ref_env/{repo}:refs/heads/{deploy_branch}:{environment}"
    )
    for role, account_id, roles, wif_member in (
        ("deploy_live", deploy_id, DEPLOY_ROLES, deploy_principal),
        ("telemetry_ro", "github-telemetry-ro", TELEMETRY_ROLES | ({"roles/logging.viewer"} if blaze else set()),
         f"{principal}repo_ref/{repo}:refs/heads/{integration_branch}"),
    ):
        email = f"{account_id}@{domain}"
        if email not in by_email:
            continue
        service_account = by_email[email]
        import_item(f"google_service_account.{role}", service_account)
        member = f"serviceAccount:{email}"
        for grant in sorted(roles):
            if (grant, member) in project_members:
                resources[indexed(f"google_project_iam_member.{role}", grant)] = f"{project} {grant} {member}"
        impersonation = "roles/iam.workloadIdentityUser"
        if (impersonation, wif_member) in members(cloud("iam", "service-accounts", "get-iam-policy", email)):
            resources[f"google_service_account_iam_member.github_impersonates_{role}"] = (
                f"{service_account['name']} {impersonation} {wif_member}"
            )

    if blaze and "billingbudgets.googleapis.com" in enabled:
        resources["google_project_service.billing_budgets[0]"] = f"{project}/billingbudgets.googleapis.com"
        budgets = cloud("billing", "budgets", "list", f"--billing-account={billing}")
        import_item("google_billing_budget.monthly[0]", lookup(
            budgets, lambda item: item.get("displayName") == f"{project} monthly ({level})", "monthly budgets",
        ))
    imports_file(directory, resources)
    print(deploy_id)


ANDROID_PACKAGE = "com.foodsavr.app"
IDENTITY_PROVIDERS = ("google.com", "facebook.com")


def index_key(index):
    """Same key as local.firestore_indexes in infra/terraform/gcp/firestore.tf."""
    fields = [f for f in index.get("fields", []) if f.get("fieldPath") != "__name__"]
    return "/".join([index["collectionGroup"], index.get("queryScope", "COLLECTION")] + [
        f"{f['fieldPath']}:{f.get('order') or f.get('arrayConfig', '')}" for f in fields
    ])


def firebase_resources(directory, project, indexes_file, account=""):
    """Import blocks for the Firebase resources of firestore.tf, auth.tf and App Check
    that already exist; prints the Android app id (empty when none)."""
    account_arg = (f"--account={account}",) if account else ()
    enabled = {item["config"]["name"] for item in command_json(
        "gcloud", *account_arg, "services", "list", "--enabled", f"--project={project}", "--format=json")}
    resources, extra, android = {}, [], ""

    def indexed(address, key):
        return f"{address}[{json.dumps(key)}]"

    if "firestore.googleapis.com" in enabled:
        database = f"projects/{project}/databases/(default)"
        url = f"https://firestore.googleapis.com/v1/{database}"
        if google_get(project, url, "the Firestore database", missing_ok=True).get("name"):
            resources["google_firestore_database.default"] = database
            declared = {index_key(i) for i in json.loads(Path(indexes_file).read_text()).get("indexes", [])}
            token = ""
            while True:
                query = f"?pageToken={token}" if token else ""  # the API accepts no pageSize
                page = google_get(project, f"{url}/collectionGroups/-/indexes{query}", "Firestore indexes")
                for index in page.get("indexes", []):
                    group = index["name"].split("/collectionGroups/", 1)[1].split("/", 1)[0]
                    key = index_key({**index, "collectionGroup": group})
                    if key in declared:
                        resources[indexed("google_firestore_index.composite", key)] = index["name"]
                token = page.get("nextPageToken", "")
                if not token:
                    break
    if "firebaserules.googleapis.com" in enabled:
        release = google_get(project, f"https://firebaserules.googleapis.com/v1/projects/{project}/releases/cloud.firestore",
                             "the Firestore rules release", missing_ok=True)
        if release.get("name"):
            resources["google_firebaserules_release.firestore"] = release["name"]
    if "firebase.googleapis.com" in enabled:
        apps = google_get(project, f"https://firebase.googleapis.com/v1beta1/projects/{project}/androidApps?pageSize=100",
                          "Firebase Android apps").get("apps", [])
        app = lookup(apps, lambda item: item.get("packageName") == ANDROID_PACKAGE and item.get("state", "ACTIVE") == "ACTIVE",
                     "Android apps")
        android = app["appId"] if app else ""
        if android and "firebaseappcheck.googleapis.com" in enabled:
            resources["google_firebase_app_check_play_integrity_config.android[0]"] = (
                f"projects/{project}/apps/{android}/playIntegrityConfig")
    if "identitytoolkit.googleapis.com" in enabled:
        listing = google_get(project, f"https://identitytoolkit.googleapis.com/admin/v2/projects/{project}/defaultSupportedIdpConfigs",
                             "Firebase Auth providers", missing_ok=True)
        # Only names are read; client secrets in the response are discarded here.
        existing = sorted({item["name"].rsplit("/", 1)[-1] for item in listing.get("defaultSupportedIdpConfigs", [])}
                          & set(IDENTITY_PROVIDERS))
        if existing:
            extra.append(f"""import {{
  for_each = toset([for idp in {json.dumps(existing)} : idp if contains(keys(var.identity_providers), idp)])
  to       = google_identity_platform_default_supported_idp_config.idp[each.key]
  id       = "projects/${{var.project_id}}/defaultSupportedIdpConfigs/${{each.key}}"
}}
""")
    imports_file(directory, resources, "adopt_firebase.tf", extra)
    print(android)


# Replacements that keep the live service working: rulesets are immutable and
# abandoned, and the rules release is recreated for the new ruleset.
REPLACEABLE = {"google_firebaserules_ruleset.firestore", "google_firebaserules_release.firestore"}


def safe_plan(recovery="true"):
    plan = json.load(sys.stdin)
    variables = plan.get("variables", {})
    changes = plan.get("resource_changes", [])
    recovery = recovery == "true" or (
        variables.get("local_recovery", {}).get("value") in (True, "true")
        or variables.get("deploy_service_account_id", {}).get("value") == "github-hosting-deploy"
        or any(item["change"].get("importing") is not None for item in changes)
    )
    if not recovery:
        print("false")
        return
    for item in changes:
        actions = item["change"]["actions"]
        if item["address"] in REPLACEABLE and "create" in actions:
            continue
        if "delete" in actions:
            raise ValueError(f"Plan would remove or replace {item['address']}. Reconcile its state before applying.")
    print("true")


if __name__ == "__main__":
    try:
        task, *args = sys.argv[1:]
        if task == "github":
            github_resources(*args)
        elif task == "gcp":
            gcp_resources(*args)
        elif task == "firebase":
            firebase_resources(*args)
        elif task == "safe-plan":
            safe_plan(*args)
    except (ValueError, OSError, KeyError, subprocess.TimeoutExpired) as error:
        sys.exit(str(error))
