.PHONY: human disable-orphaned-workflows

# Alias for `make setup` (guided setup and operations wizard).
# Usage: make human            run `make setup` (interactive terminal only)
#        make human LIST=1     list remaining setup steps
human: setup

disable-orphaned-workflows:
	@python3 scripts/human/humanctl.py --disable-orphaned-workflows
