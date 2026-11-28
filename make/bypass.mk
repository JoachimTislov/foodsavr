.PHONY: pr-merge merge-gate validate dispatch build-remote promote deploy-web release-candidate android-apk docs-build docs-publish deployment-poll monitor-web agent-review

# Manual bypass for every automated pipeline step: each target runs the script the
# workflow runs (or dispatches the workflow) with your own gh / firebase / gcloud
# login. Mutating targets are dry runs unless APPLY=1 (deploy-web: YES=1 for live).
# Inventory and menu: `make human` (`make human LIST=1`); contract: scripts/human/menu.toml.
APPLY_FLAG = $(if $(filter 1 true yes,$(APPLY)),--apply)
CURRENT_REF = $$(git rev-parse --abbrev-ref HEAD)
REPO = $$(gh repo view --json nameWithOwner --jq .nameWithOwner)

# Merge one PR when required checks, Validation, and review safeguards are green.
# A maintainer may explicitly override review/thread/security safeguards with an audit
# reason; checks, Validation, mergeability, and the verified-head binding still apply.
# Usage: make pr-merge PR=<number> [APPLY=1] [OVERRIDE_REVIEW=1 REASON="..."]
OVERRIDE_REVIEW_FLAG = $(if $(filter 1 true yes,$(OVERRIDE_REVIEW)),--override-review --reason "$(REASON)")
pr-merge:
	@test -n "$(PR)" || { echo "Usage: make pr-merge PR=<number> [APPLY=1]" >&2; exit 1; }
	@python3 scripts/github/manual_merge.py --pr "$(PR)" $(APPLY_FLAG) $(OVERRIDE_REVIEW_FLAG)

# One reconcile pass of the merge gate (merge-gate.yml) with your own login.
# Usage: make merge-gate [APPLY=1]
merge-gate:
	@python3 scripts/github/merge_gate.py --repo "$(REPO)" $(APPLY_FLAG)

# Dispatch the full Validation (pull-request.yml, operation=validation; includes the
# Android smoke and integration tests) on a ref (posts `Validation result` on its head).
# Usage: make validate [REF=<branch>]
validate:
	@ref="$(REF)"; python3 scripts/github/dispatch_workflow.py pull-request --ref "$${ref:-$(CURRENT_REF)}" --input operation=validation

# Dispatch any workflow that has a workflow_dispatch trigger.
# Usage: make dispatch WORKFLOW=<file.yml> REF=<ref> [INPUTS="key=value key=value"]
dispatch:
	@test -n "$(WORKFLOW)" -a -n "$(REF)" || { echo 'Usage: make dispatch WORKFLOW=<file.yml> REF=<ref> [INPUTS="key=value ..."]' >&2; exit 1; }
	@python3 scripts/github/dispatch_workflow.py "$(WORKFLOW)" --ref "$(REF)" $(foreach i,$(INPUTS),--input "$(i)")

# Release artifact builds (release.yml, operation=build-web|build-android) run on Actions.
# Usage: make build-remote PLATFORM=<web|android> [REF=<ref>]
build-remote:
	@case "$(PLATFORM)" in web|android) ;; *) echo "Usage: make build-remote PLATFORM=<web|android> [REF=<ref>]" >&2; exit 1;; esac
	@ref="$(REF)"; python3 scripts/github/dispatch_workflow.py release --ref "$${ref:-$(CURRENT_REF)}" --input operation="build-$(PLATFORM)"

# Fast-forward a release channel (release.yml, operation=promote) with
# scripts/github/promote_release.py. Dry run unless APPLY=1 (pushes with your gh login;
# DISPATCH=1 runs the release.yml promote operation instead).
# Usage: make promote CHANNEL=<daily|weekly|stable> [SOURCE=<branch>] [APPLY=1] [DISPATCH=1]
promote:
	@case "$(CHANNEL)" in daily|weekly|stable) ;; *) echo "Usage: make promote CHANNEL=<daily|weekly|stable> [SOURCE=<branch>] [APPLY=1] [DISPATCH=1]" >&2; exit 1;; esac
	@if [ -n "$(DISPATCH)" ]; then \
		python3 scripts/github/dispatch_workflow.py release --ref "$${WORKFLOW_REF:-develop}" --input operation=promote \
			--input promote_channel="$(CHANNEL)" --input promote_source="$(or $(SOURCE),default)" --input dry_run=$(if $(APPLY_FLAG),false,true); \
	else \
		topology="$${RELEASE_TOPOLOGY:-$$(gh variable get RELEASE_TOPOLOGY 2>/dev/null || true)}"; \
		GH_TOKEN="$$(gh auth token)" python3 scripts/github/promote_release.py --repo "$(REPO)" \
			$${topology:+--topology "$$topology"} --target-branch "$(CHANNEL)" \
			$(if $(SOURCE),--source-branch "$(SOURCE)") $(if $(APPLY_FLAG),--apply --strict-pending); \
	fi

# Build the web app with CI's pinned Flutter and deploy it to Firebase Hosting with your
# own `firebase login` (release.yml's hosting jobs run the same scripts/web/deploy_web.py).
# WEB_ACCESS_CODE can be supplied in the environment to gate the web build.
# WEB_ENV_FILE=<path> compiles public client config via --dart-define=BUNDLED_ENV_B64=... (keeping served assets/.env empty; local flutter run still reads local assets/.env).
# Usage: make deploy-web ENV=<env> [CHANNEL=<channel>] [TARGET=live|preview] [EXPIRES=4h] [WEB_ENV_FILE=<path>] [YES=1] [PLAN=1]
deploy-web:
	@test -n "$(ENV)" || { echo "Usage: make deploy-web ENV=<environment> [CHANNEL=<channel>] [TARGET=live|preview] [EXPIRES=4h] [WEB_ENV_FILE=<path>] [YES=1] [PLAN=1]" >&2; exit 1; }
	@python3 scripts/web/deploy_web.py local --env "$(ENV)" --target "$(or $(TARGET),live)" \
		$(if $(EXPIRES),--expires "$(EXPIRES)") $(if $(WEB_ENV_FILE),--web-env-file "$(WEB_ENV_FILE)") \
		$(if $(YES),--yes) $(if $(PLAN),--plan)

# The release candidate (release.yml release gate) is built only for pushes to `stable`;
# this dispatches the web build, whose `web-build` artifact is the candidate (gh run download).
# Usage: make release-candidate [REF=stable]
release-candidate:
	@python3 scripts/github/dispatch_workflow.py release --ref "$(or $(REF),stable)" --input operation=build-web
	@echo "The release gate does not run for dispatched builds; download the candidate with: gh run download <run-id> -n web-build"

# Android test APK to Google Drive (manual-tools.yml, tool=android-drive-test). Dispatches it, or
# with LOCAL=1 builds with CI's pinned Flutter and uploads from this machine, which needs
# GOOGLE_DRIVE_FOLDER_ID and GOOGLE_DRIVE_OAUTH_JSON in the environment.
# Usage: make android-apk [REF=stable] [LOCAL=1]
android-apk:
	@if [ -n "$(LOCAL)" ]; then \
		export PATH="$$(dirname "$$(python3 scripts/ci/local_ci.py --flutter-bin)"):$$PATH"; \
		bash scripts/release/android_drive.sh build && bash scripts/release/android_drive.sh upload; \
	else \
		python3 scripts/github/dispatch_workflow.py manual-tools --ref "$(or $(REF),stable)" --input tool=android-drive-test --input ref="$(or $(REF),stable)"; \
	fi

# Documentation site: build locally (the `Build documentation` job), or publish to GitHub
# Pages, which only works from Actions (dispatches release.yml docs-publish on stable).
# Usage: make docs-build | make docs-publish [REF=stable]
docs-build:
	@python3 scripts/ci/local_ci.py --group docs

docs-publish:
	@python3 scripts/github/dispatch_workflow.py release --ref "$(or $(REF),stable)" --input operation=docs-publish

# Poll one environment's usage against its level limits (ops-maintenance.yml deployment-poll) with your
# gcloud login. Usage: make deployment-poll ENV=<environment>
deployment-poll:
	@test -n "$(ENV)" || { echo "Usage: make deployment-poll ENV=<environment>" >&2; exit 1; }
	@mkdir -p .deployment-state/poll/$(ENV)
	@cd packages/foodsavr_deploy && dart pub get > /dev/null && \
		ACCESS_TOKEN="$$(gcloud auth print-access-token)" dart run bin/levels.dart poll --env "$(ENV)" \
			--state "$(CURDIR)/.deployment-state/poll/$(ENV)/state.json"

# Probe the live site and run fault intake (ops-maintenance.yml web-monitor). Dry run unless APPLY=1.
# Usage: make monitor-web [URL=<url>] [APPLY=1]
monitor-web:
	@scripts/monitoring/monitor_web.sh "$(or $(URL),$(MONITOR_TARGET_URL))" $(if $(APPLY_FLAG),--apply)

# Re-run the adaptive review (agent-ops.yml, operation=review) on a PR.
# Usage: make agent-review PR=<number>
agent-review:
	@test -n "$(PR)" || { echo "Usage: make agent-review PR=<number>" >&2; exit 1; }
	@python3 scripts/github/dispatch_workflow.py agent-ops --ref "$(or $(REF),develop)" --input operation=review --input pr="$(PR)"
