.PHONY: setup setup-probe setup-verify infra-github-plan infra-github-apply infra-gcp-plan infra-gcp-apply social-auth-setup social-auth-check router-setup router-check router-matrix monitoring agent-status agent-usage

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
