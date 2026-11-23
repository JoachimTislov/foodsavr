.PHONY: pr-merge merge-gate validate dispatch build-remote promote deploy-web release-candidate android-apk docs-build docs-publish deployment-poll monitor-web agent-review

# Manual bypass for every automated pipeline step: each target runs the script the
# workflow runs (or dispatches the workflow) with your own gh / firebase / gcloud
# login. Mutating targets are dry runs unless APPLY=1 (deploy-web: YES=1 for live).
# Inventory and menu: `make human` (`make human LIST=1`); contract: scripts/human/menu.toml.
APPLY_FLAG = $(if $(filter 1 true yes,$(APPLY)),--apply)
CURRENT_REF = $$(git rev-parse --abbrev-ref HEAD)
REPO = $$(gh repo view --json nameWithOwner --jq .nameWithOwner)

# Merge one PR when its required checks and `Validation result` are green, whatever the
# adaptive review tier says. Bound to the verified head SHA.
# Usage: make pr-merge PR=<number> [APPLY=1]
pr-merge:
	@test -n "$(PR)" || { echo "Usage: make pr-merge PR=<number> [APPLY=1]" >&2; exit 1; }
	@python3 scripts/github/manual_merge.py --pr "$(PR)" $(APPLY_FLAG)

# One reconcile pass of the merge gate (merge-gate.yml) with your own login.
# Usage: make merge-gate [APPLY=1]
merge-gate:
	@python3 scripts/github/merge_gate.py --repo "$(REPO)" $(APPLY_FLAG)

# Dispatch the full Validation workflow on a ref (posts `Validation result` on its head).
# Usage: make validate [REF=<branch>]
validate:
	@ref="$(REF)"; python3 scripts/github/dispatch_workflow.py validation --ref "$${ref:-$(CURRENT_REF)}"

# Dispatch any workflow that has a workflow_dispatch trigger.
# Usage: make dispatch WORKFLOW=<file.yml> REF=<ref> [INPUTS="key=value key=value"]
dispatch:
	@test -n "$(WORKFLOW)" -a -n "$(REF)" || { echo 'Usage: make dispatch WORKFLOW=<file.yml> REF=<ref> [INPUTS="key=value ..."]' >&2; exit 1; }
	@python3 scripts/github/dispatch_workflow.py "$(WORKFLOW)" --ref "$(REF)" $(foreach i,$(INPUTS),--input "$(i)")

# Release artifact builds (build-web.yml, build-android.yml) run on Actions.
# Usage: make build-remote PLATFORM=<web|android> [REF=<ref>]
build-remote:
	@case "$(PLATFORM)" in web|android) ;; *) echo "Usage: make build-remote PLATFORM=<web|android> [REF=<ref>]" >&2; exit 1;; esac
	@ref="$(REF)"; python3 scripts/github/dispatch_workflow.py "build-$(PLATFORM)" --ref "$${ref:-$(CURRENT_REF)}"

# Fast-forward a release channel (promote.yml) with scripts/github/promote_release.py.
# Dry run unless APPLY=1 (pushes with your gh login; DISPATCH=1 runs promote.yml instead).
# Usage: make promote CHANNEL=<nightly|beta|stable|release> [SOURCE=<branch>] [APPLY=1] [DISPATCH=1]
promote:
	@case "$(CHANNEL)" in nightly|beta|stable|release) ;; *) echo "Usage: make promote CHANNEL=<nightly|beta|stable|release> [SOURCE=<branch>] [APPLY=1] [DISPATCH=1]" >&2; exit 1;; esac
	@if [ -n "$(DISPATCH)" ]; then \
		python3 scripts/github/dispatch_workflow.py promote --ref "$${WORKFLOW_REF:-develop}" \
			--input channel="$(CHANNEL)" --input source="$(or $(SOURCE),default)" --input dry_run=$(if $(APPLY_FLAG),false,true); \
	else \
		topology="$${RELEASE_TOPOLOGY:-$$(gh variable get RELEASE_TOPOLOGY 2>/dev/null || true)}"; \
		GH_TOKEN="$$(gh auth token)" python3 scripts/github/promote_release.py --repo "$(REPO)" \
			$${topology:+--topology "$$topology"} --target-branch "$(CHANNEL)" \
			$(if $(SOURCE),--source-branch "$(SOURCE)") $(if $(APPLY_FLAG),--apply --strict-pending); \
	fi

# Build the web app with CI's pinned Flutter and deploy it to Firebase Hosting with your
# own `firebase login` (firebase-hosting.yml runs the same scripts/web/deploy_web.py).
# assets/.env is served publicly: WEB_ENV_FILE=<path> copies a file there, default empty.
# Usage: make deploy-web ENV=<env> [TARGET=live|preview] [EXPIRES=4h] [WEB_ENV_FILE=<path>] [YES=1] [PLAN=1]
deploy-web:
	@test -n "$(ENV)" || { echo "Usage: make deploy-web ENV=<environment> [TARGET=live|preview] [EXPIRES=4h] [WEB_ENV_FILE=<path>] [YES=1] [PLAN=1]" >&2; exit 1; }
	@python3 scripts/web/deploy_web.py local --env "$(ENV)" --target "$(or $(TARGET),live)" \
		$(if $(EXPIRES),--expires "$(EXPIRES)") $(if $(WEB_ENV_FILE),--web-env-file "$(WEB_ENV_FILE)") \
		$(if $(YES),--yes) $(if $(PLAN),--plan)

# Release candidate (release-gated.yml) only reacts to push-triggered Web Builds on `release`;
# this dispatches Web Build, whose `web-build` artifact is the candidate (gh run download).
# Usage: make release-candidate [REF=release]
release-candidate:
	@python3 scripts/github/dispatch_workflow.py build-web --ref "$(or $(REF),release)"
	@echo "Release (Gated) does not react to dispatched runs; download the candidate with: gh run download <run-id> -n web-build"

# Android test APK to Google Drive (android-drive-test.yml). Dispatches the workflow, or
# with LOCAL=1 builds with CI's pinned Flutter and uploads from this machine, which needs
# GOOGLE_DRIVE_FOLDER_ID and GOOGLE_DRIVE_OAUTH_JSON in the environment and your local
# lib/firebase_options.dart.
# Usage: make android-apk [REF=release] [LOCAL=1]
android-apk:
	@if [ -n "$(LOCAL)" ]; then \
		export PATH="$$(dirname "$$(python3 scripts/ci/local_ci.py --flutter-bin)"):$$PATH"; \
		bash scripts/release/android_drive.sh build && bash scripts/release/android_drive.sh upload; \
	else \
		python3 scripts/github/dispatch_workflow.py android-drive-test --ref "$(or $(REF),release)" --input ref="$(or $(REF),release)"; \
	fi

# Documentation site: build locally (the docs-pages.yml build job), or publish to GitHub
# Pages, which only works from Actions (dispatches docs-pages.yml on release).
# Usage: make docs-build | make docs-publish [REF=release]
docs-build:
	@python3 scripts/ci/local_ci.py --group docs

docs-publish:
	@python3 scripts/github/dispatch_workflow.py docs-pages --ref "$(or $(REF),release)"

# Poll one environment's usage against its level limits (deployment-level.yml) with your
# gcloud login. Usage: make deployment-poll ENV=<environment>
deployment-poll:
	@test -n "$(ENV)" || { echo "Usage: make deployment-poll ENV=<environment>" >&2; exit 1; }
	@mkdir -p .deployment-state/poll/$(ENV)
	@cd packages/foodsavr_deploy && dart pub get > /dev/null && \
		ACCESS_TOKEN="$$(gcloud auth print-access-token)" dart run bin/levels.dart poll --env "$(ENV)" \
			--state "$(CURDIR)/.deployment-state/poll/$(ENV)/state.json"

# Probe the live site and run fault intake (web-monitor.yml). Dry run unless APPLY=1.
# Usage: make monitor-web [URL=<url>] [APPLY=1]
monitor-web:
	@scripts/monitoring/monitor_web.sh "$(or $(URL),$(MONITOR_TARGET_URL))" $(if $(APPLY_FLAG),--apply)

# Re-run the adaptive review (agent-review.yml) on a PR.
# Usage: make agent-review PR=<number>
agent-review:
	@test -n "$(PR)" || { echo "Usage: make agent-review PR=<number>" >&2; exit 1; }
	@python3 scripts/github/dispatch_workflow.py agent-review --ref "$(or $(REF),develop)" --input pr="$(PR)"
