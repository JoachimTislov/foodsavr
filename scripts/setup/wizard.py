"""Interactive setup. Each step checks current state before offering a change."""

from collections.abc import Callable
from dataclasses import dataclass
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tomllib
from tempfile import TemporaryDirectory
from urllib.request import Request, urlopen

from setupctl import (
    HARNESS_AUTH_SECRETS,
    UPSTREAM_REPO,
    PROFILES,
    ROOT,
    TOPOLOGY_BRANCHES,
    ensure_branches,
    fork_repository,
    is_unattended_agent_env,
    probe_environment,
    scaffold_local,
    save_instance_local,
)


@dataclass
class Step:
    title: str
    ready: bool
    action: Callable[[], bool] | None = None
    next_action: str = ""


def choose(question, options, default):
    while True:
        answer = input(f"{question} ({'/'.join(options)}) [{default}]: ").strip()
        if answer in options or not answer:
            return answer or default


def confirm(question):
    return choose(question, ("y", "n"), "n") == "y"


def run(*args, env=None, quiet=False):
    output = subprocess.DEVNULL if quiet else None
    try:
        return subprocess.run(args, cwd=ROOT, env=env, stdout=output, stderr=output).returncode
    except OSError:
        return 1


def process(step, listing, verify=None):
    if listing:
        if not step.ready:
            print(step.title)
        return True
    if step.ready:
        print(f"{step.title} ready.", flush=True)
        return True
    if step.action is not None and step.action() and (verify is None or verify()):
        print(f"{step.title} ready.", flush=True)
        return True
    print(f"{step.title} pending. {step.next_action or 'Run make setup to resume.'}", file=sys.stderr)
    return False


def firebase_project(env):
    try:
        result = subprocess.run(
            ["dart", "run", "bin/levels.dart", "env", "--manifest", env["MANIFEST"],
             "--env", env.get("ENV", "production"), "--format", "github"],
            cwd=ROOT / "packages/foodsavr_deploy", capture_output=True, text=True, timeout=60,
        )
    except (OSError, subprocess.TimeoutExpired):
        return ""
    project = dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line).get("PROJECT_ID", "")
    return project if result.returncode == 0 and re.fullmatch(r"[a-z0-9][a-z0-9-]+", project) else ""


def anonymous_enabled(project, account):
    if not project:
        return False
    command = ["gcloud", *([f"--account={account}"] if account else []), "auth", "print-access-token"]
    try:
        token = subprocess.run(command, capture_output=True, text=True, timeout=20, check=True).stdout.strip()
        url = f"https://identitytoolkit.googleapis.com/admin/v2/projects/{project}/config"
        request = Request(url, headers={"Authorization": f"Bearer {token}", "x-goog-user-project": project})
        with urlopen(request, timeout=20) as response:
            return json.load(response).get("signIn", {}).get("anonymous", {}).get("enabled") is True
    except (OSError, subprocess.SubprocessError, ValueError):
        return False


def configure_app(repo, role):
    mode = choose("GitHub App setup", ("browser", "existing", "later"), "browser")
    if mode == "later":
        return False
    command = ["scripts/human/github/create-agent-app.sh", "--role", role, "--repo", repo]
    if mode == "existing":
        command.append("--manual-url")
    return run(*command) == 0


def configure_harness(repo):
    helpers = {
        "claude": "scripts/human/agents/login-claude-runner.sh",
        "codex": "scripts/human/agents/sync-codex-runner.sh",
        "antigravity": "scripts/human/agents/sync-antigravity-runner.sh",
    }
    choice = choose("Select a CI runner login", (*helpers, "gemini", "later"), "later")
    if choice in helpers:
        return run(helpers[choice], env={**os.environ, "GH_REPO": repo}) == 0
    return choice == "gemini" and run(
        "python3", "scripts/secrets/rotate.py", "--repo", repo, "--yes", "GEMINI_API_KEY"
    ) == 0


def terraform_step(title, script, env, listing, prerequisites):
    if not prerequisites:
        return process(Step(title), listing)
    with TemporaryDirectory(prefix="foodsavr-setup-") as directory:
        plan = str(Path(directory) / "review.tfplan")
        plan_env = {**env, "PLAN_OUT": plan, "TF_DETAILED_EXITCODE": "1"}
        cloud = script.endswith("/apply.sh")
        settings_url = (
            "https://console.cloud.google.com/iam-admin/iam" if cloud
            else f"https://github.com/{env.get('GITHUB_REPOSITORY', '')}/settings"
        )
        next_action = f"Check access at {settings_url} and resume setup."
        result = run(script, "plan", env=plan_env, quiet=True)
        if result not in (0, 2):
            return process(Step(title, False, next_action=next_action), listing)
        if result == 0 and cloud:
            # Publishing outputs can be interrupted after cloud resources are ready.
            result = 0 if env.get("SETUP_GCP_OUTPUTS_READY") == "1" else 2

        def apply():
            if not confirm(f"{title} has pending changes. Review the plan now?"):
                return False
            if run(script, "show", env={**env, "PLAN_FILE": plan}):
                return False
            if not confirm(f"Apply the reviewed {title} plan?"):
                return False
            if run(script, "apply", env={**env, "PLAN_FILE": plan}, quiet=True):
                return False
            return run(script, "plan", env=plan_env, quiet=True) == 0

        return process(Step(title, result == 0, apply, next_action), listing)


def bypass_entries():
    path = ROOT / "scripts/human/menu.toml"
    if not path.is_file():
        return []
    with path.open("rb") as handle:
        return [
            entry for entry in tomllib.load(handle).get("entry", [])
            if entry.get("target") and entry["target"] not in {"setup", "human"}
        ]


def run_bypass(entries, topology):
    by_number = {str(number): entry for number, entry in enumerate(entries, start=1)}
    for number, entry in by_number.items():
        print(f"  {number}  {entry['title']}")
    choice = choose("Select an operation", (*by_number, "back"), "back")
    if choice == "back":
        return None
    entry = by_number[choice]
    target = entry["target"]
    if not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9_.-]*", target):
        raise ValueError("Invalid make target in the operations registry.")

    assignments = []
    for variable in entry.get("vars", []):
        name = variable["name"]
        choices = variable.get("choices")
        if name == "CHANNEL":
            choices = tuple(TOPOLOGY_BRANCHES[topology][1:])
            if not choices:
                print("This topology has no promotion channels.")
                return 1
        if choices:
            default = variable.get("default")
            value = choose(variable["prompt"], (*choices, "back"), default or ("back" if variable.get("required") else ""))
            if value == "back":
                return None
        else:
            value = input(f"{variable['prompt']} [{variable.get('default', '')}]: ").strip() or variable.get("default", "")
        if variable.get("required") and not value:
            print("A value is required. Select the operation again to continue.")
            return 1
        if value:
            if not re.fullmatch(r"[A-Z_][A-Z0-9_]*", name) or not re.fullmatch(r"[-A-Za-z0-9 ./:@_+=%,~]+", value):
                print("Use a plain value without shell syntax.")
                return 1
            assignments.append(f"{name}={value}")

    apply = entry.get("apply_assign")
    dry = entry.get("dry_assign")
    if not confirm(f"{entry['title']}. {'Preview now?' if apply else 'Run now?'}"):
        return 0
    preview_flag = dry or (apply.partition("=")[0] + "=" if apply else "")
    result = run("make", target, *assignments, *([preview_flag] if preview_flag else []))
    if result == 0 and apply and confirm("Apply the operation?"):
        result = run("make", target, *assignments, apply)
    return result


def run_wizard(args):
    listing = args.list
    if not listing and (
        is_unattended_agent_env() or not sys.stdin.isatty() or not sys.stdout.isatty()
    ):
        print("Open a terminal to run make setup. Use make setup LIST=1 to see remaining steps.")
        return 2
    try:
        if not listing:
            entries = bypass_entries()
            if entries and choose("FoodSavr", ("setup", "operations"), "setup") == "operations":
                config = probe_environment(repo=args.repo, offline=True)["local_config"]
                topology = config.get("release_topology", "single")
                result = run_bypass(entries, topology if topology in TOPOLOGY_BRANCHES else "single")
                if result is not None:
                    return result
        return setup(args, listing)
    except (EOFError, KeyboardInterrupt):
        print("\nSetup paused. Run make setup to resume.", file=sys.stderr)
        return 1


def setup(args, listing):
    repo = args.repo

    def probe():
        return probe_environment(repo=repo, offline=profile == "local-dev")

    initial = probe_environment(repo=repo, offline=True)
    config = initial["local_config"]
    profile = args.profile or config.get("profile")
    if listing and profile not in PROFILES:
        print("Choose a setup profile")
        profile = "local-dev"
    elif not listing and args.profile is None:
        print("Choose local development, GitHub automation, or GitHub and Firebase.")
        profile = choose("Setup profile", PROFILES, profile if profile in PROFILES else "local-dev")
        if config.get("profile") != profile:
            save_instance_local({"profile": profile})

    state = probe()
    gh = state["github"]
    tools = state["tools"]
    repo = gh["target_repo"]
    topology = config.get("release_topology")
    firebase = profile == "full-cloud"
    cloud = profile != "local-dev"

    def scaffold():
        return scaffold_local(profile=profile, topology=topology, repo=repo)["hooks_configured"]

    for tool, url in (
        ("flutter", "https://docs.flutter.dev/install"),
        *((("gh", "https://cli.github.com"), ("terraform", "https://developer.hashicorp.com/terraform/install")) if cloud else ()),
        *((("gcloud", "https://cloud.google.com/sdk/docs/install"),) if firebase else ()),
    ):
        if not tools[tool] and not process(Step(f"Install {tool}", False, next_action=f"Open {url}."), listing):
            return 1

    if cloud:
        if not process(Step(
            "GitHub sign-in", gh["authenticated"],
            lambda: tools["gh"] and run("gh", "auth", "login", "--web") == 0,
            "Sign in at https://github.com/login/device and resume setup.",
        ), listing, lambda: probe()["github"]["authenticated"]):
            return 1
        gh = probe()["github"] if not listing else gh
        if gh["needs_fork"]:
            def fork():
                nonlocal repo
                if not confirm(f"Create a fork of {repo} for your GitHub automation?"):
                    return False
                repo = fork_repository(upstream=repo)["fork"]
                return True

            if not process(Step("Repository fork", False, fork), listing, lambda: probe()["github"]["is_admin"]):
                return 1
            gh = probe()["github"] if not listing else gh
        if not process(Step(
            "GitHub configuration access", gh["config_readable"],
            next_action=f"Check Actions access at https://github.com/{repo}/settings/actions.",
        ), listing):
            return 1
        topology = gh["variables"].get("RELEASE_TOPOLOGY") or (
            topology if config.get("profile") != "local-dev" else None
        )
        if topology not in TOPOLOGY_BRANCHES:
            default = "full-channels" if repo and repo.casefold() == UPSTREAM_REPO.casefold() else "single"
            if listing:
                print("Choose release channels")
                topology = default
            else:
                for name, branches in TOPOLOGY_BRANCHES.items():
                    print(f"  {name}  {', '.join(branches)}")
                topology = choose("Release channels", tuple(TOPOLOGY_BRANCHES), default)
    else:
        topology = "single"

    config_ready = (
        all(state["local_files"].values())
        and config.get("profile") == profile
        and config.get("release_topology") == topology
        and config.get("repo") == repo
    )
    if not process(Step("Local development files", config_ready, scaffold), listing):
        return 1
    if not cloud:
        return 0

    def branches_ready():
        return set(TOPOLOGY_BRANCHES[topology]) <= set(probe()["github"]["branches"])

    def create_branches():
        if not repo or not confirm(f"Create missing release branches for {repo}?"):
            return False
        ensure_branches(repo=repo, topology=topology, default_branch=TOPOLOGY_BRANCHES[topology][0])
        return True

    if not process(Step(
        "Release branches", set(TOPOLOGY_BRANCHES[topology]) <= set(gh["branches"]), create_branches,
    ), listing, branches_ready):
        return 1

    for role, prefix in (("agent", "AGENT_APP"), ("release-gate", "RELEASE_GATE_APP")):
        def configure():
            if f"{prefix}_PRIVATE_KEY" in gh["secret_names"] and f"{prefix}_ID" in gh["secret_names"]:
                print("Find the existing App ID at https://github.com/settings/apps.")
                app_id = input("App ID: ").strip()
                return bool(app_id.isdecimal() and run(
                    "gh", "variable", "set", f"{prefix}_ID", "--repo", repo, "--body", app_id, quiet=True,
                ) == 0)
            return configure_app(repo, role)

        def app_ready(info):
            return f"{prefix}_PRIVATE_KEY" in info["secret_names"] and (
                str(info["variables"].get(f"{prefix}_ID", "")).isdecimal()
            )

        if not process(Step(
            f"GitHub {role} App", app_ready(gh), configure,
            f"Check App credentials and installation at https://github.com/{repo}/settings/installations.",
        ), listing, lambda: app_ready(probe()["github"])):
            return 1

    def harness_ready(info):
        return bool(set(HARNESS_AUTH_SECRETS) & set(info["secret_names"]))

    if not process(Step(
        "CI runner login", harness_ready(gh), lambda: configure_harness(repo),
    ), listing, lambda: harness_ready(probe()["github"])):
        return 1

    gh = probe()["github"] if not listing else gh
    env = {
        **os.environ,
        "GITHUB_REPOSITORY": repo or "",
        "GH_REPO": repo or "",
        "RELEASE_TOPOLOGY": topology,
        "AGENT_APP_ID": gh["variables"].get("AGENT_APP_ID", ""),
        "RELEASE_GATE_APP_ID": gh["variables"].get("RELEASE_GATE_APP_ID", ""),
    }
    github_ready = gh["config_readable"] and tools["terraform"] and set(TOPOLOGY_BRANCHES[topology]) <= set(gh["branches"])
    if not terraform_step("GitHub configuration", "scripts/infra/apply-github.sh", env, listing, github_ready):
        return 1

    if firebase:
        def cloud_login():
            return tools["gcloud"] and run("gcloud", "auth", "print-access-token", quiet=True) == 0

        cloud_ready = cloud_login()
        if not process(Step(
            "Google Cloud sign-in", cloud_ready, lambda: run("gcloud", "auth", "login") == 0,
            "Check your account at https://console.cloud.google.com/.",
        ), listing, cloud_login):
            return 1
        manifest = env.get("MANIFEST") or config.get("manifest")
        if gh["is_fork"] and not manifest:
            if listing:
                print("Select the Firebase deployment manifest")
            else:
                print(f"Choose the deployment manifest for {repo}. See deploy/examples/firebase-free-web.yaml.")
                path = Path(input("Deployment manifest path: ").strip()).expanduser()
                if not path.is_file():
                    print("Choose an existing deployment manifest and resume setup.")
                    return 1
                manifest = str(path.resolve())
                save_instance_local({"manifest": manifest})
        env["MANIFEST"] = str(Path(manifest or ROOT / "deploy/instance.yaml").resolve())
        env["SETUP_GCP_OUTPUTS_READY"] = str(int(all(
            gh["variables"].get(name) for name in (
                "GCP_WORKLOAD_IDENTITY_PROVIDER", "GCP_DEPLOY_SERVICE_ACCOUNT",
                "GCP_TELEMETRY_SERVICE_ACCOUNT", "RECAPTCHA_ENTERPRISE_SITE_KEY",
            )
        )))
        if not terraform_step("Firebase configuration", "scripts/infra/apply.sh", env, listing, tools["terraform"] and (cloud_ready or not listing)):
            return 1

        project = firebase_project(env) if cloud_ready and tools["dart"] else ""
        auth_url = f"https://console.firebase.google.com/project/{project}/authentication/providers" if project else (
            "https://console.firebase.google.com/"
        )

        def anonymous_ready():
            return anonymous_enabled(project, env.get("GCLOUD_ACCOUNT"))

        def enable_anonymous():
            print(f"Enable Anonymous at {auth_url}.")
            return confirm("Verify Firebase sign-in now?")

        if not process(Step(
            "Anonymous sign-in", anonymous_ready(), enable_anonymous, f"Open {auth_url}.",
        ), listing, anonymous_ready):
            return 1

        def sync_firebase_options():
            options = ROOT / "lib/firebase_options.dart"
            if "foodsavr-local-dev" in options.read_text():
                if not confirm("Generate app configuration with FlutterFire now?"):
                    return False
                if not project or run("flutterfire", "configure", "--project", project):
                    return False
            if "foodsavr-local-dev" in options.read_text():
                return False
            return run(
                "python3", "scripts/secrets/rotate.py", "--repo", repo, "--yes", "FIREBASE_OPTIONS_B64", quiet=True,
            ) == 0

        if not process(Step(
            "Firebase app configuration for CI", "FIREBASE_OPTIONS_B64" in gh["secret_names"],
            sync_firebase_options, "Check your app configuration in https://console.firebase.google.com/.",
        ), listing, lambda: "FIREBASE_OPTIONS_B64" in probe()["github"]["secret_names"]):
            return 1

    if gh["is_fork"]:
        permissions = ["gh", "api", f"repos/{repo}/actions/permissions"]
        def actions_ready():
            return run(*permissions, "--jq", "if .enabled then true else error(\"disabled\") end", quiet=True) == 0

        if not process(Step(
            "GitHub Actions", actions_ready(),
            lambda: confirm("Enable GitHub Actions now?") and run(
                *permissions, "-X", "PUT", "-F", "enabled=true", quiet=True,
            ) == 0,
            f"Open https://github.com/{repo}/settings/actions.",
        ), listing, actions_ready):
            return 1
    return 0
