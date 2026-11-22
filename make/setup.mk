.PHONY: social-auth-setup social-auth-check router-setup router-check router-matrix monitoring agent-status
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
