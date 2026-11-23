.PHONY: human

# One entry point for the manual processes and pipeline bypasses. The menu is generated from
# scripts/human/menu.toml plus the scripts under scripts/human/*/ (see scripts/human/humanctl.py).
# Usage: make human            interactive menu (terminal only)
#        make human LIST=1     plain-text menu for agents and docs
human:
	@python3 scripts/human/humanctl.py $(if $(LIST),--list)
