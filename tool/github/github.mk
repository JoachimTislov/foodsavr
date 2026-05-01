.PHONY: gh-resolve-active gh-resolve-outdated gh-resolve-thread gh-summarize-comments gh-sync-pr

gh-resolve-active:
	@echo "Resolving active PR review threads..."
	@bash tool/github/resolve_active_review_threads.sh

gh-resolve-outdated:
	@echo "Resolving outdated PR review threads..."
	@bash tool/github/resolve_outdated_review_threads.sh

gh-resolve-thread:
	@if [ -z "$(id)" ]; then \
		echo "Error: Provide a thread ID (e.g., make gh-resolve-thread id=123)"; \
		exit 1; \
	fi
	@bash tool/github/resolve_thread_by_id.sh "$(id)"

gh-summarize-comments:
	@echo "Summarizing PR comments..."
	@bash tool/github/summarize_pr_comments.sh

gh-sync-pr:
	@echo "Syncing PR with base branch..."
	@bash tool/github/sync_pr_with_base.sh
