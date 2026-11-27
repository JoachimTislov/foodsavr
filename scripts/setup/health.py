"""Evaluate scripts/setup/health.toml: the setup and platform health checks.

The checks are declarative; this module only holds one evaluator per `kind`.
`setupctl verify` and the final `make setup` step call `evaluate`. Live kinds
(network, GitHub runs, scripts) run through a `Live` object; without one they
report "not probed" so an offline verify never reads as healthy.
"""

from __future__ import annotations

from dataclasses import dataclass, field
import json
import os
from pathlib import Path
import re
import subprocess
import tomllib
from typing import Any, Callable

# Pages searched for one operation of a shared workflow (30 runs per page).
RUN_PAGE_BUDGET = 5
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
CONFIG = Path(__file__).with_name("health.toml")
REGISTRY = ROOT / "scripts/secrets/registry.toml"
WORKFLOWS = ROOT / ".github/workflows"
SECRET_REF = re.compile(r"secrets\.([A-Z_][A-Z0-9_]*)")


def load(path: Path = CONFIG) -> dict[str, Any]:
    with path.open("rb") as handle:
        return tomllib.load(handle)


def group(name: str, config: dict[str, Any] | None = None) -> tuple[str, ...]:
    return tuple((config or load())["groups"][name])


def lookup(data: Any, dotted: str) -> Any:
    for key in dotted.split("."):
        if not isinstance(data, dict):
            return None
        data = data.get(key)
    return data


def var_suffix(environment: str) -> str:
    """Mirror packages/foodsavr_deploy varSuffix: production uses the plain names."""
    return "" if environment == "production" else f"_{environment.upper()}"


def cloud_environments(variables: dict[str, str]) -> dict[str, dict[str, Any]]:
    """Provisioned environments published in the DEPLOY_INSTANCE Actions variable."""
    try:
        instance = json.loads(variables.get("DEPLOY_INSTANCE") or "{}")
    except ValueError:
        return {}
    result: dict[str, dict[str, Any]] = {}
    for name, env in (instance.get("environments") or {}).items():
        firebase = env.get("firebase") or {}
        if env.get("provisioned") and firebase.get("projectId"):
            channels = dict(env.get("channels") or {}) or {"live": firebase.get("siteId") or firebase["projectId"]}
            result[name] = {"project": firebase["projectId"], "channels": channels}
    return result


class Live:
    """Read-only network, GitHub and script probes; replaced by a fake in tests."""

    def __init__(self, repo: str, root: Path = ROOT, run: Callable[..., subprocess.CompletedProcess[str]] | None = None):
        self.repo, self.root = repo, root
        self._run = run or self._subprocess

    def _subprocess(
        self,
        argv: list[str],
        timeout: int = 180,
        env: dict[str, str] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        run_env = {**os.environ, "GH_REPO": self.repo, **(env or {})} if self.repo else ({**os.environ, **(env or {})} if env else None)
        try:
            return subprocess.run(argv, cwd=self.root, env=run_env, text=True, capture_output=True, timeout=timeout, check=False)
        except (OSError, subprocess.TimeoutExpired) as exc:
            return subprocess.CompletedProcess(argv, 127, "", str(exc))

    def http_status(self, url: str) -> int | None:
        try:
            with urllib.request.urlopen(url, timeout=15) as response:
                return response.status
        except urllib.error.HTTPError as exc:
            return exc.code
        except (urllib.error.URLError, OSError):
            return None

    def _api(self, path: str, jq: str) -> str | None:
        proc = self._run(["gh", "api", path, "--jq", jq])
        return proc.stdout.strip() if proc.returncode == 0 else None

    def latest_run(self, workflow: str, event: str | None, branch: str, run_name: str | None = None) -> dict[str, Any] | None:
        # A shared workflow interleaves other operations; when the wanted one is older
        # than the first page, keep paging within a budget instead of reporting none.
        per_page = 30 if run_name else 1
        page = 1
        while True:
            query = f"repos/{self.repo}/actions/workflows/{workflow}/runs?status=completed&per_page={per_page}&page={page}"
            if event:
                query += f"&event={event}&branch={branch}"
            out = self._api(query, ".workflow_runs")
            runs = json.loads(out) if out and out != "null" else []
            match = next((r for r in runs if not run_name or run_name in str(r.get("display_title") or "")), None)
            if match is not None:
                return match
            if not run_name or len(runs) < per_page or page >= RUN_PAGE_BUDGET:
                return None
            page += 1

    def annotations(self, run_id: int) -> list[str]:
        jobs = self._api(f"repos/{self.repo}/actions/runs/{run_id}/jobs", ".jobs[].id") or ""
        messages: list[str] = []
        for job in jobs.split():
            messages += (self._api(f"repos/{self.repo}/check-runs/{job}/annotations", ".[].message") or "").splitlines()
        return [m for m in messages if m.strip()]

    def script(self, argv: list[str], env: dict[str, str] | None = None) -> tuple[bool, str]:
        try:
            proc = self._run(argv, env=env)
        except TypeError:
            proc = self._run(argv)
        lines = [line.strip() for line in (proc.stdout + proc.stderr).splitlines() if line.strip()]
        return proc.returncode == 0, lines[-1] if lines else ""


@dataclass
class Context:
    probe: dict[str, Any]
    profile: str
    topology: str
    branches: list[str]
    integration_branch: str
    live: Live | None = None
    values: dict[str, str] = field(default_factory=dict)

    @property
    def github(self) -> dict[str, Any]:
        return self.probe["github"]

    @property
    def configured(self) -> set[str]:
        return set(self.github.get("variables") or {}) | set(self.github.get("secret_names") or [])


Result = tuple[bool, str]
NOT_PROBED = (False, "not probed (needs online gh with admin on the repository)")


def _names(check: dict[str, Any], config: dict[str, Any]) -> list[str]:
    names = check["names"]
    return list(group(names[1:], config)) if isinstance(names, str) and names.startswith("@") else list(names)


def _workflow_refs() -> set[str]:
    return {m for path in WORKFLOWS.glob("*.y*ml") for m in SECRET_REF.findall(path.read_text(encoding="utf-8"))}


def _script_env(ctx: Context) -> dict[str, str]:
    gh = ctx.github
    env: dict[str, str] = {}
    if gh.get("target_repo"):
        env["GH_REPO"] = str(gh["target_repo"])
    deploy_instance = (gh.get("variables") or {}).get("DEPLOY_INSTANCE")
    if deploy_instance:
        env["DEPLOY_INSTANCE"] = str(deploy_instance)
    return env


def _run_script(live: Live, argv: list[str], env: dict[str, str]) -> tuple[bool, str]:
    try:
        return live.script(argv, env=env)
    except TypeError:
        return live.script(argv)


def _single(check: dict[str, Any], ctx: Context, config: dict[str, Any]) -> Result:
    kind, gh = check["kind"], ctx.github
    if kind == "probe":
        return all(lookup(ctx.probe, f) for f in check["fields"]), ""
    if kind == "branches":
        missing = [b for b in ctx.branches if b not in set(gh.get("branches") or [])]
        return not missing, f"missing={missing or 'none'}"
    if kind in ("github", "github-any"):
        names = _names(check, config)
        present = [n for n in names if n in ctx.configured]
        ok = bool(present) if kind == "github-any" else len(present) == len(names)
        return ok, f"set: {', '.join(present) or 'none'}" + ("" if ok else f"; need: {', '.join(n for n in names if n not in present)}")
    if kind == "event-policy":
        policy = gh.get("event_policy") or {"state": "unavailable", "detail": NOT_PROBED[1]}
        return policy.get("state") == "match", str(policy.get("detail"))
    if kind == "environments":
        envs = cloud_environments(gh.get("variables") or {})
        return bool(envs), ", ".join(envs) or "none"
    if kind == "registry":
        with REGISTRY.open("rb") as handle:
            registry = tomllib.load(handle)["secrets"]
        wanted = {n for n, s in registry.items() if "github" in s.get("sinks", ["github"])} & _workflow_refs()
        missing = sorted(wanted - ctx.configured)
        return not missing, ", ".join(missing) or "none"
    if ctx.live is None:
        return NOT_PROBED
    if kind == "workflow-run":
        run = ctx.live.latest_run(check["workflow"], check.get("event"), ctx.integration_branch, check.get("run_name"))
        if run is None:
            return False, "no completed run"
        marked = [m for m in ctx.live.annotations(run["id"]) if check.get("marker") and check["marker"] in m]
        return run.get("conclusion") == "success" and not marked, f"{marked[0] if marked else run.get('conclusion')} ({run.get('html_url')})"
    if kind == "script":
        target_repo = gh.get("target_repo")
        checkout_repo = ctx.probe.get("origin_repo") or lookup(ctx.probe, "local_config.repo")
        if target_repo and checkout_repo and target_repo.casefold() != str(checkout_repo).casefold():
            return False, f"checkout is bound to {checkout_repo}, not {target_repo}; run from a {target_repo} checkout"
        if check["id"] == "firebase-config":
            return False, "no provisioned environment in DEPLOY_INSTANCE"
        ok, last = _run_script(ctx.live, check["argv"], _script_env(ctx))
        return ok, "passes" if ok else f"{' '.join(check['argv'])}: {last}"
    raise ValueError(f"health.toml: unknown kind {kind!r} in {check['id']}")


def _items(check: dict[str, Any], ctx: Context) -> list[tuple[str, dict[str, str]]]:
    """Per-environment kinds fan out into one result per environment or site."""
    envs = cloud_environments(ctx.github.get("variables") or {})
    if check["kind"] == "wif":
        return [(f"{check['id']}-{env}", {"env": env, "suffix": var_suffix(env), "project": e["project"]}) for env, e in envs.items()]
    if check["kind"] == "site":
        return [
            (f"{check['id']}-{site}", {"env": env, "channel": channel, "site": site, "project": e["project"]})
            for env, e in envs.items() for channel, site in e["channels"].items()
        ]
    if check["kind"] == "script" and check["id"] == "firebase-config" and envs:
        items: list[tuple[str, dict[str, str]]] = []
        for env, e in envs.items():
            sites = sorted({site for site in e["channels"].values() if site and site != e["project"]})
            name = check["id"] if len(envs) == 1 else f"{check['id']}-{env}"
            items.append((name, {"env": env, "project": e["project"], "sites": json.dumps(sites)}))
        return items
    return [(check["id"], {})]


def _per_item(check: dict[str, Any], ctx: Context, values: dict[str, str]) -> Result:
    if check["kind"] == "wif":
        variables = ctx.github.get("variables") or {}
        provider = variables.get(f"GCP_WORKLOAD_IDENTITY_PROVIDER{values['suffix']}")
        account = variables.get(f"GCP_DEPLOY_SERVICE_ACCOUNT{values['suffix']}") or ""
        return bool(provider) and account.endswith(f"@{values['project']}.iam.gserviceaccount.com"), account or "unset"
    if ctx.live is None:
        return NOT_PROBED
    if check["kind"] == "script":
        target_repo = ctx.github.get("target_repo")
        checkout_repo = ctx.probe.get("origin_repo") or lookup(ctx.probe, "local_config.repo")
        if target_repo and checkout_repo and target_repo.casefold() != str(checkout_repo).casefold():
            return False, f"checkout is bound to {checkout_repo}, not {target_repo}; run from a {target_repo} checkout"
        argv = [*check["argv"], "--project", values["project"], "--sites", values["sites"]]
        ok, last = _run_script(ctx.live, argv, _script_env(ctx))
        return ok, "passes" if ok else f"{' '.join(argv)}: {last}"
    status = ctx.live.http_status(f"https://{values['site']}.web.app")
    return status == 200, f"HTTP {status or 'no response'}"


def evaluate(ctx: Context, config: dict[str, Any] | None = None) -> dict[str, Any]:
    config = config or load()
    checks: list[dict[str, Any]] = []
    notes: list[str] = []
    base = {"profile": ctx.profile, "repo": ctx.github.get("target_repo") or "<owner>/<repo>",
            "topology": ctx.topology, "branch": ctx.integration_branch}
    for check in config["check"]:
        if ctx.profile not in check["profiles"]:
            continue
        skip = check.get("skip_when")
        if skip and lookup(ctx.probe, skip["path"]) == skip["equals"]:
            continue
        declined = check.get("declined_step") in (lookup(ctx.probe, "local_config.declinedSteps") or [])
        for name, values in _items(check, ctx):
            text = {**base, **values}
            if declined:
                notes.append(f"{name}: declined in make setup (resume: {check['fix'].format(**text)})")
                continue
            ok, extra = _per_item(check, ctx, values) if values else _single(check, ctx, config)
            detail = check["detail"].format(**text) + (f": {extra}" if extra else "")
            if check.get("advisory"):
                if not ok:
                    notes.append(f"{name}: {detail} (fix: {check['fix'].format(**text)})")
                continue
            checks.append({"name": name, "ok": ok, "detail": detail, "remediation": check["fix"].format(**text)})
    return {"profile": ctx.profile, "ready": all(c["ok"] for c in checks), "checks": checks, "notes": notes}
