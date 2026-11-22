.PHONY: social-auth-setup social-auth-check router-setup router-check router-matrix monitoring-setup monitoring-check monitoring-probe monitoring-test
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

MONITOR_URL ?= https://my-foodsavr-store.web.app
monitoring-setup:
	@scripts/setup/monitoring.sh $(ARGS)

monitoring-check:
	@scripts/setup/monitoring.sh --check $(ARGS)

monitoring-probe:
	@node scripts/monitoring/probe_web.mjs --url "$(MONITOR_URL)" $(ARGS)

monitoring-test:
	@python3 -m unittest discover -s scripts/monitoring -p "test_*.py"
