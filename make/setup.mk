.PHONY: setup-fork setup-branches setup-enable-actions secrets-rotate setup setup-probe setup-verify infra-github-plan infra-github-apply infra-gcp-plan infra-gcp-apply social-auth-setup social-auth-check router-setup router-check router-matrix monitoring agent-status agent-usage

setup:
	@python3 scripts/setup/setupctl.py wizard

setup-probe:
	@python3 scripts/setup/setupctl.py probe

setup-verify:
	@python3 scripts/setup/setupctl.py verify --profile $(or $(PROFILE),local-dev)

infra-github-plan:
	@scripts/infra/apply-github.sh plan

infra-github-apply:
	@scripts/infra/apply-github.sh apply

infra-gcp-plan:
	@scripts/infra/apply.sh plan

infra-gcp-apply:
	@scripts/infra/apply.sh apply

social-auth-setup:
	@scripts/setup/social_auth.sh

social-auth-check:
	@scripts/setup/social_auth.sh --check

router-setup:
	@scripts/setup/agent_router.sh

router-check:
	@scripts/setup/agent_router.sh --check

router-matrix:
	@scripts/agents/agentctl router matrix

monitoring:
	@scripts/setup/monitoring.sh

agent-status:
	@scripts/agents/agentctl status

agent-usage:
	@scripts/agents/agentctl usage

# Rotate or set registry secrets (scripts/secrets/rotate.py); lists the registry when no name or group is given.
# Usage: make secrets-rotate [NAMES="A B"] [GROUP=<group>] [DRY_RUN=1]
secrets-rotate:
	@python3 scripts/secrets/rotate.py $(if $(or $(NAMES),$(GROUP)),$(if $(DRY_RUN),--dry-run) $(if $(GROUP),--group $(GROUP)) $(NAMES),--list)

# Contributor and fork steps from the setup wizard, for the `make human` menu.
# Usage: make setup-fork UPSTREAM=<owner>/foodsavr [YES=1]
setup-fork:
	@test -n "$(UPSTREAM)" || { echo "Usage: make setup-fork UPSTREAM=<owner>/foodsavr [YES=1]" >&2; exit 1; }
	@python3 scripts/setup/setupctl.py fork --upstream "$(UPSTREAM)" $(if $(YES),--yes)

# Usage: make setup-branches REPO=<owner>/<repo> TOPOLOGY=<single|two-stage|full-channels> [YES=1]
setup-branches:
	@test -n "$(REPO)" -a -n "$(TOPOLOGY)" || { echo "Usage: make setup-branches REPO=<owner>/<repo> TOPOLOGY=<single|two-stage|full-channels> [YES=1]" >&2; exit 1; }
	@python3 scripts/setup/setupctl.py ensure-branches --repo "$(REPO)" --topology "$(TOPOLOGY)" $(if $(YES),--yes)

# Enable GitHub Actions on a fork; do this last.
# Usage: make setup-enable-actions REPO=<owner>/<repo>
setup-enable-actions:
	@test -n "$(REPO)" || { echo "Usage: make setup-enable-actions REPO=<owner>/<repo>" >&2; exit 1; }
	@gh api -X PUT "repos/$(REPO)/actions/permissions" -F enabled=true
