"""Interactive setup. Each step checks current state before offering a change."""

from collections.abc import Callable
from dataclasses import dataclass, replace
import json
import os
from pathlib import Path
import re
import shutil
import shlex
import subprocess
import sys
from tempfile import TemporaryDirectory
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from setupctl import (
    HARNESS_AUTH_SECRETS,
    load_instance_local,
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

sys.path.insert(0, str(ROOT / "scripts"))
from firebase_options import fingerprint, regenerate  # noqa: E402

sys.path.insert(0, str(ROOT / "scripts/infra"))
from bootstrap_support import local_state_path  # noqa: E402

PROJECT_ID = re.compile(r"[a-z][a-z0-9-]{4,28}[a-z0-9]")
CONSOLE = "https://console.firebase.google.com/project"

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


from facebook_provider import (  # noqa: E402
    enable_facebook_provider as _enable_facebook_provider,
    identity_toolkit_token,
    load_env_file,
    load_facebook_credentials,
)


def levels(*args, manifest):
    try:
        return subprocess.run(
            ["dart", "run", "bin/levels.dart", *args, "--manifest", manifest],
            cwd=ROOT / "packages/foodsavr_deploy", capture_output=True, text=True, timeout=60,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None


def manifest_environments(manifest):
    """Environments declared in the manifest, as `levels environments --json` lists them."""
    result = levels("environments", "--json", manifest=manifest)
    if result is None or result.returncode:
        return []
    try:
        environments = json.loads(result.stdout)
    except ValueError:
        return []
    return environments if isinstance(environments, list) else []


def primary_environment(environments, requested=""):
    """The environment the tracked lib/firebase_options.dart targets: test when declared."""
    if requested:
        return requested
    names = {e.get("name") for e in environments if not e.get("emulator")}
    return "test" if "test" in names else "production"


def firebase_identity(env):
    try:
        result = subprocess.run(
            ["dart", "run", "bin/levels.dart", "env", "--manifest", env["MANIFEST"],
             "--env", env.get("ENV", "production"), "--format", "dotenv"],
            cwd=ROOT / "packages/foodsavr_deploy", capture_output=True, text=True, timeout=60,
        )
    except (OSError, subprocess.TimeoutExpired):
        return "", ""
    try:
        values = {
            key: shlex.split(value)[0] for line in result.stdout.splitlines() if "=" in line
            for key, value in [line.split("=", 1)]
        }
    except (IndexError, ValueError):
        return "", ""
    project = values.get("PROJECT_ID", "")
    repo = values.get("GITHUB_REPOSITORY", "")
    if result.returncode or not re.fullmatch(r"[a-z0-9][a-z0-9-]+", project):
        return "", ""
    if repo.casefold() != env["GITHUB_REPOSITORY"].casefold():
        return "", ""
    return project, values.get("WEB_APP_ID", "")


def identity_toolkit_get(project, account, suffix):
    if not project:
        return None
    token = identity_toolkit_token(account)
    if not token:
        return None
    url = f"https://identitytoolkit.googleapis.com/admin/v2/projects/{project}/{suffix}"
    request = Request(url, headers={"Authorization": f"Bearer {token}", "x-goog-user-project": project})
    try:
        with urlopen(request, timeout=20) as response:
            return json.load(response)
    except (OSError, URLError, ValueError):
        return None


def anonymous_enabled(project, account):
    data = identity_toolkit_get(project, account, "config")
    return isinstance(data, dict) and data.get("signIn", {}).get("anonymous", {}).get("enabled") is True


def facebook_enabled(project, account):
    data = identity_toolkit_get(project, account, "defaultSupportedIdpConfigs/facebook.com")
    return isinstance(data, dict) and data.get("enabled") is True


def enable_facebook_provider(project, account, app_id, app_secret):
    return _enable_facebook_provider(
        project,
        account,
        app_id,
        app_secret,
        get_token=identity_toolkit_token,
        open_url=urlopen,
    )


def committed_project(manifest, ref, environment, env):
    """Firebase project of a provisioned `environment` in the manifest committed on `ref`.

    None when the manifest lives outside this repository; "" when `ref` lacks the
    manifest or the environment is not provisioned there.
    """
    try:
        relative = Path(manifest).resolve().relative_to(ROOT.resolve())
    except ValueError:
        return None
    remote, _, branch = ref.partition("/")
    run("git", "fetch", "--quiet", remote, branch, quiet=True)
    try:
        shown = subprocess.run(
            ["git", "show", f"{ref}:{relative.as_posix()}"], cwd=ROOT, capture_output=True, text=True, timeout=60,
        )
    except (OSError, subprocess.TimeoutExpired):
        return ""
    if shown.returncode:
        return ""
    with TemporaryDirectory(prefix="foodsavr-manifest-") as directory:
        path = Path(directory) / "instance.yaml"
        path.write_text(shown.stdout, encoding="utf-8")
        return firebase_identity({**env, "MANIFEST": str(path), "ENV": environment})[0]


def firebase_json(*args):
    """Result of a Firebase CLI command with your login, or None."""
    try:
        response = subprocess.run(
            ["firebase", *args, "--non-interactive", "--json"], cwd=ROOT,
            capture_output=True, text=True, timeout=120,
        )
        data = json.loads(response.stdout)
    except (OSError, subprocess.TimeoutExpired, ValueError):
        return None
    return data.get("result") if response.returncode == 0 and isinstance(data, dict) else None


def firebase_project_exists(project):
    projects = firebase_json("projects:list")
    return isinstance(projects, list) and any(p.get("projectId") == project for p in projects)


def firebase_web_app(project):
    apps = firebase_json("apps:list", "WEB", "--project", project)
    if isinstance(apps, list) and apps:
        return apps[0].get("appId", "")
    return ""


def default_site_exists(project):
    result = firebase_json("hosting:sites:list", "--project", project)
    sites = result.get("sites", []) if isinstance(result, dict) else []
    return any(site.get("name", "").endswith(f"/sites/{project}") for site in sites)


def write_production_identity(manifest, project, web_app):
    """Replace production's `provisioned: false` with its Firebase identity."""
    path = Path(manifest)
    lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
    try:
        start = lines.index("  production:\n")
        marker = lines.index("    provisioned: false\n", start)
    except ValueError:
        return False
    if any(line.strip() and not line.startswith("    ") for line in lines[start + 1:marker]):
        return False
    lines[marker:marker + 1] = [
        "    firebase:\n",
        f"      projectId: {project}\n",
        f'      webAppId: "{web_app}"\n',
        f"      siteId: {project}\n",
    ]
    path.write_text("".join(lines), encoding="utf-8")
    return True


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
        return process(Step(title, False), listing)
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


def load_menu():
    path = ROOT / "scripts/human"
    if not (path / "menu.toml").is_file():
        return None, None
    sys.path.insert(0, str(path))
    import humanctl

    return humanctl, humanctl.load_registry()


def run_bypass(menu, entries, topology, repo):
    by_number = {str(number): entry for number, entry in enumerate(entries, start=1)}
    for number, entry in by_number.items():
        print(f"  {number}  {entry.title}")
    choice = choose("Select an operation", (*by_number, "back"), "back")
    if choice == "back":
        return None
    entry = by_number[choice]
    channels = tuple(TOPOLOGY_BRANCHES[topology][1:])
    if any(variable.name == "CHANNEL" for variable in entry.vars):
        if not channels:
            print("This topology has no promotion channels.")
            return 1
        entry = replace(entry, vars=tuple(
            replace(variable, choices=channels) if variable.name == "CHANNEL" else variable
            for variable in entry.vars
        ))
    values = menu.collect(entry)
    if values is None:
        return 1
    if not all(re.fullmatch(r"[-A-Za-z0-9 ./:@_+=%,~]*", value) for value in values.values()):
        print("Use plain input without shell syntax.")
        return 1
    if not confirm(f"{entry.title}. {'Preview now?' if entry.apply_assign else 'Run now?'}"):
        return 0
    preview = entry.dry_assign or (entry.apply_assign.partition("=")[0] + "=" if entry.apply_assign else "")
    env = {**os.environ, "RELEASE_TOPOLOGY": topology}
    if repo:
        env.update(GH_REPO=repo, GITHUB_REPOSITORY=repo)
    result = run(*menu.command(entry, values, tuple(preview.split())), env=env)
    if result == 0 and entry.apply_assign and confirm("Apply the operation?"):
        result = run(*menu.command(entry, values, tuple(entry.apply_assign.split())), env=env)
    return result


def run_wizard(args):
    listing = args.list
    if not listing and (
        is_unattended_agent_env() or not sys.stdin.isatty() or not sys.stdout.isatty()
    ):
        print("Open a terminal to run make setup. Use make setup LIST=1 to see remaining steps.")
        return 2
    try:
        menu, registry = load_menu()
        if not listing and registry:
            entries = [item for item in menu.all_entries(registry) if item.target not in {"setup", "human"}]
            if entries and choose("FoodSavr", ("setup", "operations"), "setup") == "operations":
                state = probe_environment(repo=args.repo)
                github = state["github"]
                topology = github["variables"].get("RELEASE_TOPOLOGY") or state["local_config"].get("release_topology")
                result = run_bypass(
                    menu, entries, topology if topology in TOPOLOGY_BRANCHES else "single", github["target_repo"],
                )
                if result is not None:
                    return result
        return setup(args, listing, getattr(registry, "setup_steps", ()))
    except (EOFError, KeyboardInterrupt):
        print("\nSetup paused. Run make setup to resume.", file=sys.stderr)
        return 1


def setup(args, listing, ordered_steps=()):
    initial = probe_environment(repo=args.repo, offline=True)
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
    wizard = Setup(args.repo, profile, initial, listing)
    return wizard.execute(ordered_steps)


class Setup:
    def __init__(self, repo, profile, initial, listing):
        self.repo = repo
        self.profile = profile
        self.config = initial["local_config"]
        self.listing = listing
        self.cloud = profile != "local-dev"
        self.firebase = profile == "full-cloud"
        self.state = initial if not self.cloud else self.probe()
        self.repo = self.state["github"]["target_repo"]
        self.topology = "single"
        self.env = None
        self.environments = []
        self.production_created = False
        self.project = ""
        self.web_app = ""

    def probe(self):
        return probe_environment(repo=self.repo, offline=not self.cloud)

    def refresh(self, check):
        self.state = self.probe()
        return check(self.github)

    @property
    def github(self):
        return self.state["github"]

    @property
    def tools(self):
        return self.state["tools"]

    def step(self, title, ready, action=None, next_action="", verify=None):
        return process(Step(title, ready, action, next_action), self.listing, verify)

    def execute(self, ordered_steps):
        steps = {
            "prerequisites": self.prerequisites,
            "github-login": self.github_login,
            "repository": self.repository,
            "release-topology": self.release_topology,
            "local-files": self.local_files,
            "release-branches": self.release_branches,
            "agent-app": lambda: self.github_app("agent", "AGENT_APP"),
            "release-gate-app": lambda: self.github_app("release-gate", "RELEASE_GATE_APP"),
            "runner-login": self.runner_login,
            "cloud-login": self.cloud_login,
            "firebase-project": self.firebase_project,
            "firebase-app-config": self.firebase_app_config,
            "github-infrastructure": self.github_infrastructure,
            "firebase-infrastructure": self.firebase_infrastructure,
            "anonymous-sign-in": self.anonymous_sign_in,
            "facebook-sign-in": self.facebook_sign_in,
            "fork-actions": self.fork_actions,
        }
        if ordered_steps and (len(ordered_steps) != len(steps) or set(ordered_steps) != set(steps)):
            raise ValueError("The setup steps in scripts/human/menu.toml are incomplete.")
        return 0 if all(steps[name]() for name in (ordered_steps or steps)) else 1

    def prerequisites(self):
        tools = [("flutter", "https://docs.flutter.dev/install")]
        if self.cloud:
            tools.extend([("gh", "https://cli.github.com"), ("terraform", "https://developer.hashicorp.com/terraform/install")])
        if self.firebase:
            tools.append(("gcloud", "https://cloud.google.com/sdk/docs/install"))
        return all(
            self.step(f"Install {tool}", False, next_action=f"Open {url}.")
            for tool, url in tools if not self.tools[tool]
        )

    def github_login(self):
        def ready(info):
            return info["authenticated"]

        return not self.cloud or self.step(
            "GitHub sign-in", ready(self.github), lambda: run("gh", "auth", "login", "--web") == 0,
            "Sign in at https://github.com/login/device and resume setup.", lambda: self.refresh(ready),
        )

    def repository(self):
        if not self.cloud:
            return True

        def fork():
            if not confirm(f"Create a fork of {self.repo} for your GitHub automation?"):
                return False
            self.repo = fork_repository(upstream=self.repo)["fork"]
            return True

        if self.github["needs_fork"] and not self.step(
            "Repository fork", False, fork, verify=lambda: self.refresh(lambda info: info["is_admin"]),
        ):
            return False
        return self.step(
            "GitHub configuration access", self.github["config_readable"],
            next_action=f"Check Actions access at https://github.com/{self.repo}/settings/actions.",
        )

    def release_topology(self):
        if not self.cloud:
            return True
        selected = self.github["variables"].get("RELEASE_TOPOLOGY")
        if not selected and self.config.get("profile") != "local-dev":
            selected = self.config.get("release_topology")
        if selected not in TOPOLOGY_BRANCHES:
            default = "full-channels" if self.repo and self.repo.casefold() == UPSTREAM_REPO.casefold() else "single"
            if self.listing:
                print("Choose release channels")
                selected = default
            else:
                for name, branches in TOPOLOGY_BRANCHES.items():
                    print(f"  {name}  {', '.join(branches)}")
                selected = choose("Release channels", tuple(TOPOLOGY_BRANCHES), default)
        self.topology = selected
        return True

    def local_files(self):
        def scaffold():
            return scaffold_local(profile=self.profile, topology=self.topology, repo=self.repo)["hooks_configured"]

        ready = (
            all(self.state["local_files"].values())
            and self.config.get("profile") == self.profile
            and self.config.get("release_topology") == self.topology
            and self.config.get("repo") == self.repo
        )
        return self.step("Local development files", ready, scaffold)

    def branch_refs_ready(self, info):
        return set(TOPOLOGY_BRANCHES[self.topology]) <= set(info["branches"])

    def release_branches(self):
        missing = [b for b in TOPOLOGY_BRANCHES[self.topology] if b not in set(self.github.get("branches", []))]

        def create():
            if not self.repo:
                return False
            print(f"Missing release channels ({self.topology}) on {self.repo}: {', '.join(missing)}")
            if not confirm(f"Create missing release channels ({', '.join(missing)})?"):
                return False
            try:
                ensure_branches(repo=self.repo, topology=self.topology, default_branch=TOPOLOGY_BRANCHES[self.topology][0])
            except (PermissionError, RuntimeError, ValueError) as exc:
                print(exc, file=sys.stderr)
                return False
            return True

        return not self.cloud or self.step(
            "Release channels", not missing, create,
            verify=lambda: self.refresh(self.branch_refs_ready),
        )

    def github_app(self, role, prefix):
        def has_id(info):
            return str(info["variables"].get(f"{prefix}_ID", "")).isdecimal()

        def configure():
            info = self.github
            if f"{prefix}_PRIVATE_KEY" not in info["secret_names"] or not (
                has_id(info) or f"{prefix}_ID" in info["secret_names"]
            ):
                return configure_app(self.repo, role)
            print("Open the existing App at https://github.com/settings/apps.")
            variables = {}
            if not has_id(info):
                app_id = input("App ID: ").strip()
                if not app_id.isdecimal():
                    return False
                variables[f"{prefix}_ID"] = app_id
            if role == "agent" and not info["variables"].get("AGENT_APP_SLUG"):
                slug = input("App URL name: ").strip()
                if not re.fullmatch(r"[a-zA-Z0-9-]+", slug):
                    return False
                variables["AGENT_APP_SLUG"] = slug
            return all(run(
                "gh", "variable", "set", name, "--repo", self.repo, "--body", value, quiet=True,
            ) == 0 for name, value in variables.items())

        def ready(info):
            return (
                f"{prefix}_PRIVATE_KEY" in info["secret_names"] and has_id(info)
                and (role != "agent" or bool(info["variables"].get("AGENT_APP_SLUG")))
            )

        return not self.cloud or self.step(
            f"GitHub {role} App", ready(self.github), configure,
            f"Check App credentials and installation at https://github.com/{self.repo}/settings/installations.",
            lambda: self.refresh(ready),
        )

    def runner_login(self):
        def ready(info):
            return bool(set(HARNESS_AUTH_SECRETS) & set(info["secret_names"]))

        return not self.cloud or self.step(
            "CI runner login", ready(self.github), lambda: configure_harness(self.repo),
            verify=lambda: self.refresh(ready),
        )

    def deployment_env(self):
        return {
            **os.environ,
            "GITHUB_REPOSITORY": self.repo or "",
            "GH_REPO": self.repo or "",
            "RELEASE_TOPOLOGY": self.topology,
            "AGENT_APP_ID": self.github["variables"].get("AGENT_APP_ID", ""),
            "RELEASE_GATE_APP_ID": self.github["variables"].get("RELEASE_GATE_APP_ID", ""),
        }

    def github_infrastructure(self):
        if not self.cloud:
            return True
        available = self.github["config_readable"] and self.tools["terraform"] and self.branch_refs_ready(self.github)
        return terraform_step(
            "GitHub configuration", "scripts/infra/apply-github.sh", self.deployment_env(), self.listing, available,
        )

    def cloud_authenticated(self):
        return self.tools["gcloud"] and run("gcloud", "auth", "print-access-token", quiet=True) == 0

    def cloud_login(self):
        return not self.firebase or self.step(
            "Google Cloud sign-in", self.cloud_authenticated(), lambda: run("gcloud", "auth", "login") == 0,
            "Check your account at https://console.cloud.google.com/.", self.cloud_authenticated,
        )

    def firebase_project(self):
        if not self.firebase:
            return True
        self.env = self.deployment_env()
        manifest = self.env.get("MANIFEST") or self.config.get("manifest")
        if self.repo and self.repo.casefold() != UPSTREAM_REPO.casefold() and not manifest:
            if self.listing:
                print("Select the Firebase deployment manifest")
            else:
                print(f"Choose the deployment manifest for {self.repo}. See deploy/examples/firebase-free-web.yaml.")
                path = Path(input("Deployment manifest path: ").strip()).expanduser()
                if not path.is_file():
                    print("Choose an existing deployment manifest and resume setup.")
                    return False
                manifest = str(path.resolve())
                save_instance_local({"manifest": manifest})
        self.env["MANIFEST"] = str(Path(manifest or ROOT / "deploy/instance.yaml").resolve())
        self.environments = manifest_environments(self.env["MANIFEST"]) if self.tools["dart"] else []
        self.env["ENV"] = primary_environment(self.environments, os.environ.get("ENV", ""))
        if self.tools["dart"]:
            self.project, self.web_app = firebase_identity(self.env)
        return self.step(
            "Firebase project", bool(self.project and self.web_app),
            next_action="Check the deployment manifest against https://console.firebase.google.com/.",
        ) and self.production_project()

    def declared(self, name):
        return next((e for e in self.environments if e.get("name") == name), None)

    def production_project(self):
        """Create the separate production project when the manifest declares it unprovisioned."""
        production = self.declared("production")
        if self.env["ENV"] == "production" or production is None or production.get("provisioned", True):
            return True
        firebase_cli = "https://firebase.google.com/docs/cli"

        def provision():
            if not shutil.which("firebase"):
                print(f"Install the Firebase CLI at {firebase_cli}.")
                return False
            saved = load_instance_local().get("production_project", "")
            default = saved or f"{(self.repo or 'foodsavr').rsplit('/', 1)[-1].lower()}-prod"
            project = input(f"Production Firebase project ID [{default}]: ").strip() or default
            if not PROJECT_ID.fullmatch(project) or project == self.project:
                print("Use a new lower-case project ID of 6 to 30 letters, digits or dashes.")
                return False
            save_instance_local({"production_project": project})
            if not firebase_project_exists(project):
                if not confirm(f"Create the Firebase project {project} with your Firebase login?"):
                    return False
                if run("firebase", "projects:create", project, "--display-name", "FoodSavr") or (
                    not firebase_project_exists(project)
                ):
                    print("Create it at https://console.firebase.google.com/ and resume setup.")
                    return False
            web_app = firebase_web_app(project)
            if not web_app:
                if not confirm(f"Register the FoodSavr web app in {project}?"):
                    return False
                created = firebase_json("apps:create", "WEB", "FoodSavr web", "--project", project)
                web_app = created.get("appId", "") if isinstance(created, dict) else ""
                if not web_app:
                    print(f"Add a web app at {CONSOLE}/{project}/settings/general and resume setup.")
                    return False
            if not default_site_exists(project) and run(
                "firebase", "hosting:sites:create", project, "--project", project,
            ):
                print(f"Open Hosting at {CONSOLE}/{project}/hosting and resume setup.")
                return False
            if not write_production_identity(self.env["MANIFEST"], project, web_app):
                print(f"Set environments.production.firebase to projectId {project}, webAppId {web_app}"
                      " in the deployment manifest and remove provisioned: false.")
                return False
            self.production_created = True
            print(f"Created production project {project}. Next steps:")
            print("  1. Commit the updated deployment manifest on a branch and open a PR.")
            print(f"  2. Create the Firestore database at {CONSOLE}/{project}/firestore.")
            print(f"  3. Enable sign-in providers at {CONSOLE}/{project}/authentication/providers.")
            print("  4. After the PR is merged, verify the legal texts and account deletion.")
            print("  5. Run make setup again to apply the production configuration.")
            return True

        def verify():
            self.environments = manifest_environments(self.env["MANIFEST"])
            return bool(firebase_identity({**self.env, "ENV": "production"})[0])

        return self.step(
            "Production Firebase project", False, provision,
            "Create it at https://console.firebase.google.com/ and resume setup.", verify,
        )

    def firebase_infrastructure(self):
        if not self.firebase:
            return True
        available = self.tools["terraform"] and self.cloud_authenticated()
        primary = self.env.get("ENV", "production")
        if not self.terraform_state(primary):
            return False
        names = [primary]
        if primary != "production" and self.production_apply_allowed():
            names.append("production")
        return all(self.environment_infrastructure(name, available) for name in names)

    def production_apply_allowed(self):
        """Apply production only once its identity is merged, never in the run that created it."""
        production = self.declared("production")
        if production is None or not production.get("provisioned", True):
            return False
        if self.production_created:
            print("Skipping the production configuration: this run created the production project. "
                  "Merge the manifest PR, verify the legal texts and account deletion, then run make setup again.")
            return False
        ref = f"origin/{TOPOLOGY_BRANCHES[self.topology][0]}"
        committed = committed_project(self.env["MANIFEST"], ref, "production", self.env)
        if committed is None:
            return True
        local = firebase_identity({**self.env, "ENV": "production"})[0]
        if not committed or committed != local:
            print(f"Skipping the production configuration: production project {local or '(none)'} is not "
                  f"merged on {ref}. Merge the manifest PR, verify the legal texts and account deletion, "
                  "then run make setup again.")
            return False
        return True

    def environment_infrastructure(self, name, available):
        suffix = "" if name == "production" else f"_{name.upper()}"
        env = {**self.env, "ENV": name}
        env["SETUP_GCP_OUTPUTS_READY"] = str(int(all(
            self.github["variables"].get(f"{variable}{suffix}") for variable in (
                "GCP_WORKLOAD_IDENTITY_PROVIDER", "GCP_DEPLOY_SERVICE_ACCOUNT",
                "GCP_TELEMETRY_SERVICE_ACCOUNT", "RECAPTCHA_ENTERPRISE_SITE_KEY",
            )
        )))
        title = "Firebase configuration" if name == "production" else f"Firebase configuration ({name})"
        return terraform_step(title, "scripts/infra/apply.sh", env, self.listing, available)

    def terraform_state(self, name):
        """Keep local state when the project moves from `production` to another environment."""
        if name == "production" or not self.project or not self.repo:
            return True
        try:
            legacy = local_state_path(self.repo, f"gcp-{self.project}-production")
            current = local_state_path(self.repo, f"gcp-{self.project}-{name}")
        except ValueError:
            return True
        if not legacy.is_file():
            return True
        if current.is_file():
            return self.step(
                f"Terraform state ({name})", False,
                next_action=f"Both {legacy} and {current} exist; keep the newer one and resume setup.",
            )

        def move():
            if not confirm(f"Move the Terraform state of {self.project} from production to {name}?"):
                return False
            current.parent.mkdir(parents=True, exist_ok=True)
            legacy.replace(current)
            return True

        return self.step(f"Terraform state ({name})", False, move, verify=current.is_file)

    def anonymous_sign_in(self):
        if not self.firebase:
            return True
        account = self.env.get("GCLOUD_ACCOUNT") if self.env else None
        url = f"https://console.firebase.google.com/project/{self.project}/authentication/providers" if self.project else (
            "https://console.firebase.google.com/"
        )

        def ready():
            return anonymous_enabled(self.project, account)

        def enable():
            print(f"Enable Anonymous at {url}.")
            return confirm("Verify Firebase sign-in now?")

        return self.step("Anonymous sign-in", ready(), enable, f"Open {url}.", ready)

    def facebook_sign_in(self):
        if not self.firebase:
            return True
        account = self.env.get("GCLOUD_ACCOUNT") if self.env else None
        url = f"https://console.firebase.google.com/project/{self.project}/authentication/providers" if self.project else (
            "https://console.firebase.google.com/"
        )

        def creds():
            return load_facebook_credentials(ROOT)

        def ready():
            return facebook_enabled(self.project, account)

        def enable():
            app_id, app_secret = creds()
            missing = [
                name for name, value in (("FACEBOOK_APP_ID", app_id), ("FACEBOOK_APP_SECRET", app_secret))
                if not value
            ]
            if missing:
                if confirm("Store Meta app credentials to enable Facebook sign-in?"):
                    command = ["python3", "scripts/secrets/rotate.py"]
                    if self.repo:
                        command.extend(["--repo", self.repo, "--yes"])
                    command.extend(missing)
                    run(*command)
                    app_id, app_secret = creds()
            elif not confirm("Enable Facebook sign-in in Firebase Auth?"):
                return False
            if app_id and app_secret and enable_facebook_provider(self.project, account, app_id, app_secret):
                return True
            print(f"Enable Facebook at {url}.")
            return confirm("Verify Facebook sign-in now?")

        return self.step("Facebook sign-in", ready(), enable, f"Open {url}.", ready)

    def firebase_app_config(self):
        if not self.firebase:
            return True

        # lib/firebase_options.dart is tracked in git (#426); this step only
        # repairs it when it no longer matches the manifest's project and web app.
        path = ROOT / "lib/firebase_options.dart"
        url = f"https://console.firebase.google.com/project/{self.project}/settings/general"

        def ready():
            return bool(fingerprint(path, self.project, self.web_app))

        def repair():
            if not confirm("Regenerate lib/firebase_options.dart from Firebase?"):
                return False
            if not shutil.which("firebase"):
                print("Install the Firebase CLI at https://firebase.google.com/docs/cli.")
                return False
            try:
                regenerate(path, self.project, self.web_app)
            except ValueError as error:
                if "Sign in to the Firebase CLI" not in str(error):
                    print(str(error), file=sys.stderr)
                    return False
                if not confirm("Sign in to Firebase in your browser?") or run("firebase", "login", "--reauth"):
                    return False
                try:
                    regenerate(path, self.project, self.web_app)
                except ValueError as retry_error:
                    print(str(retry_error), file=sys.stderr)
                    return False
            if not ready():
                return False
            print("Regenerated lib/firebase_options.dart; commit it on a branch and open a PR.")
            return True

        return self.step("Firebase app configuration", ready(), repair, f"Check registered apps at {url}.", ready)

    def fork_actions(self):
        if not self.cloud or not self.github["is_fork"]:
            return True
        permissions = ["gh", "api", f"repos/{self.repo}/actions/permissions"]

        def ready():
            return run(*permissions, "--jq", 'if .enabled then true else error("disabled") end', quiet=True) == 0

        return self.step(
            "GitHub Actions", ready(),
            lambda: confirm("Enable GitHub Actions now?") and run(
                *permissions, "-X", "PUT", "-F", "enabled=true", quiet=True,
            ) == 0,
            f"Open https://github.com/{self.repo}/settings/actions.", ready,
        )
