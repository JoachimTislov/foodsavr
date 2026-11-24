#!/usr/bin/env bash
# Sets skip=true when HEAD (a push to daily, weekly, or stable) already succeeded for
# this commit SHA, or has the exact tree of a merged PR's head commit on which
# workflow $1 already succeeded. Rebase merges rewrite SHAs but keep the tree
# when the PR was up to date, and fast-forward promotions preserve the SHA.
# Pull request synchronize events (typically a rebase onto a moved base) also skip
# when the previous head has a green run of the workflow and the tree diff old head
# -> new head touches nothing in the workflow's scope (the pathspecs). When
# --target <name>:<p1,p2,...> flags are given, each target also emits
# skip_<name>=true|false so unrelated target changes (e.g. a web-only merge on
# develop) reuse green android/integration/rules runs from the previous head.
# Usage: already_tested.sh [--push-only-reuse] [--require-job <regex>]
#        [--target <name>:<csv_paths>]... <workflow-file.yml> [pathspec...]   (needs GH_TOKEN)
set -euo pipefail
out="${GITHUB_OUTPUT:-/dev/stdout}"

push_only_reuse=false
require_job_re=""
targets=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --push-only-reuse)
      push_only_reuse=true
      shift
      ;;
    --require-job)
      require_job_re="${2:?--require-job requires a regex}"
      shift 2
      ;;
    --target)
      targets+=("${2:?--target requires name:path1,path2}")
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

emit_all_targets() {
  local val="$1"
  local spec name
  for spec in "${targets[@]}"; do
    name="${spec%%:*}"
    echo "skip_${name}=${val}" >> "$out"
  done
}

skip() {
  local val="$1"
  local msg="$2"
  local emit_targets="${3:-yes}"
  echo "skip=${val}" >> "$out"
  if [ "$emit_targets" != "no" ] && [ "${#targets[@]}" -gt 0 ]; then
    emit_all_targets "$val"
  fi
  echo "already_tested: skip=${val} (${msg})" >&2
  exit 0
}

repo="${GITHUB_REPOSITORY:?}"

run_matches_requirement() {
  local run_id="$1"
  local jobs_json matched
  jobs_json=$(gh api "repos/$repo/actions/runs/$run_id/jobs" 2>/dev/null || true)
  [ -n "$jobs_json" ] || return 1
  if [ -n "$require_job_re" ]; then
    matched=$(printf '%s' "$jobs_json" | jq --arg re "$require_job_re" '[.jobs[] | select(.conclusion == "success" and (.name | test($re; "i")))] | length' 2>/dev/null || echo 0)
  else
    matched=$(printf '%s' "$jobs_json" | jq '[.jobs[] | select(.conclusion == "success" and (.name | test("already|detect|skip|preflight|validation status|decide"; "i") | not))] | length' 2>/dev/null || echo 0)
  fi
  [ "${matched:-0}" -gt 0 ]
}

has_green_pr_run() {
  local commit_sha="$1"
  local run_ids
  run_ids=$(gh run list --repo "$repo" --workflow "$wf" --commit "$commit_sha" --event pull_request --status success --json databaseId --jq '.[].databaseId' 2>/dev/null || true)
  [ -n "$run_ids" ] || return 1
  if [ -z "$require_job_re" ]; then
    return 0
  fi
  local run_id
  for run_id in $run_ids; do
    if run_matches_requirement "$run_id"; then
      return 0
    fi
  done
  return 1
}

check_speculative_train_reuse() {
  local pr_number head_sha head_repo train_branch train_runs new_tree run_id train_sha train_tree
  pr_number=$(jq -r '.pull_request.number // empty' "$GITHUB_EVENT_PATH" 2>/dev/null || true)
  head_sha=$(jq -r '.pull_request.head.sha // empty' "$GITHUB_EVENT_PATH" 2>/dev/null || true)
  head_repo=$(jq -r '.pull_request.head.repo.full_name // empty' "$GITHUB_EVENT_PATH" 2>/dev/null || true)
  # Fail closed on fork PRs or payloads without trusted same-repo head metadata.
  if [ -z "$pr_number" ] || [ -z "$head_sha" ] || [ "$head_repo" != "$repo" ]; then
    return 1
  fi
  train_branch="merge-train/pr-${pr_number}"
  train_runs=$(gh run list --repo "$repo" --workflow "$wf" --branch "$train_branch" --event push --status success --limit 5 --json databaseId,headSha --jq '.[] | "\(.databaseId) \(.headSha)"' 2>/dev/null || true)
  [ -n "$train_runs" ] || return 1
  git rev-parse --verify "${head_sha}^{tree}" >/dev/null 2>&1 || git fetch --no-tags --depth=1 origin "$head_sha" 2>/dev/null || return 1
  new_tree=$(git rev-parse "${head_sha}^{tree}" 2>/dev/null || true)
  [ -n "$new_tree" ] || return 1
  while read -r run_id train_sha; do
    [ -n "$run_id" ] && [ -n "$train_sha" ] || continue
    git rev-parse --verify "${train_sha}^{tree}" >/dev/null 2>&1 \
      || git fetch --no-tags --depth=1 origin "$train_sha" 2>/dev/null \
      || git fetch --no-tags --depth=1 origin "$train_branch" 2>/dev/null \
      || continue
    train_tree=$(git rev-parse "${train_sha}^{tree}" 2>/dev/null || true)
    if [ -n "$train_tree" ] && [ "$train_tree" = "$new_tree" ]; then
      if run_matches_requirement "$run_id"; then
        skip true "tree ${new_tree:0:7} already validated on ${train_branch} (${train_sha:0:7}, run ${run_id})"
      fi
    fi
  done <<< "$train_runs"
  return 1
}

if [ "${GITHUB_EVENT_NAME:-}" = "pull_request" ]; then
  wf="$1"; shift
  check_speculative_train_reuse || true
  [ "$(jq -r .action "$GITHUB_EVENT_PATH")" = "synchronize" ] || skip false "not a synchronize event"
  if [ "$#" -eq 0 ] && [ "${#targets[@]}" -eq 0 ]; then
    skip false "no scope pathspecs given"
  fi
  before=$(jq -r .before "$GITHUB_EVENT_PATH"); new=$(jq -r .pull_request.head.sha "$GITHUB_EVENT_PATH")
  git fetch --no-tags --depth=1 origin "$before" "$new" 2>/dev/null || skip false "cannot fetch previous head"
  has_green_pr_run "$before" || skip false "no qualifying green $wf run on previous head $before"
  if [ "$#" -gt 0 ]; then
    touched=$(git diff --name-only "$before" "$new" -- "$@") || skip false "diff failed"
    if [ -z "$touched" ]; then
      skip true "previous head $before green; nothing in scope changed"
    fi
  fi
  if [ "${#targets[@]}" -gt 0 ]; then
    reused=()
    rerun=()
    target_lines=()
    for spec in "${targets[@]}"; do
      name="${spec%%:*}"
      csv="${spec#*:}"
      IFS=',' read -r -a target_paths <<< "$csv"
      t_touched=$(git diff --name-only "$before" "$new" -- "${target_paths[@]}") || skip false "target diff failed for $name"
      if [ -z "$t_touched" ]; then
        target_lines+=("skip_${name}=true")
        reused+=("$name")
      else
        target_lines+=("skip_${name}=false")
        rerun+=("$name")
      fi
    done
    printf '%s\n' "${target_lines[@]}" >> "$out"
    skip false "previous head $before green; reused=[${reused[*]:-none}] rerun=[${rerun[*]:-none}]" no
  fi
  skip false "changes since previous head are in scope"
fi
[ "${GITHUB_EVENT_NAME:-}" = "push" ] || skip false "not a push"
wf="$1"; shift
sha="${GITHUB_SHA:?}"

# Helper: verify at least one matching workflow run executed non-skipped work
# (GitHub marks a workflow run conclusion=success even when every job was skipped).
has_non_skipped_run() {
  local commit_sha="$1"
  local event_filter="${2:-}"
  local args=(run list --repo "$repo" --workflow "$wf" --commit "$commit_sha" --status success --json databaseId --jq '.[].databaseId')
  if [ -n "$event_filter" ]; then
    args+=(--event "$event_filter")
  fi
  local run_ids
  run_ids=$(gh "${args[@]}" 2>/dev/null || true)
  local run_id
  for run_id in $run_ids; do
    local executed
    executed=$(gh api "repos/$repo/actions/runs/$run_id/jobs" \
      --jq '[.jobs[] | select(.conclusion == "success" and (.name | test("already|detect|skip|preflight|validation status|decide"; "i") | not))] | length' 2>/dev/null || echo 0)
    if [ "${executed:-0}" -gt 0 ]; then
      return 0
    fi
  done
  return 1
}

if [ "$push_only_reuse" = "true" ]; then
  if has_non_skipped_run "$sha" push; then
    skip true "workflow $wf already succeeded on a push run for commit $sha"
  fi
  skip false "full push validation required on release branch for commit $sha"
fi

if has_non_skipped_run "$sha"; then
  skip true "workflow $wf already succeeded with executed jobs on commit $sha"
fi

# Guard against multi-PR fast-forward batches: if multiple commits were pushed
# and scope pathspecs are given, only allow PR-head tree reuse when the push
# contains a single commit or when the exact tree of HEAD was tested.
if [ -n "${GITHUB_EVENT_PATH:-}" ] && [ -f "${GITHUB_EVENT_PATH}" ]; then
  before=$(jq -r '.before // empty' "$GITHUB_EVENT_PATH" 2>/dev/null || true)
  commit_count=$(jq -r '(.commits // []) | length' "$GITHUB_EVENT_PATH" 2>/dev/null || echo 0)
  if [ -n "$before" ] && [ "$before" != "0000000000000000000000000000000000000000" ] && [ "${commit_count:-0}" -gt 1 ] && [ "$#" -gt 0 ]; then
    if git fetch --no-tags --depth=1 origin "$before" "$sha" 2>/dev/null; then
      touched=$(git diff --name-only "$before" "$sha" -- "$@" 2>/dev/null || echo "diff-failed")
      if [ -n "$touched" ]; then
        skip false "multi-commit push ($commit_count commits) touched in-scope paths"
      fi
    else
      skip false "multi-commit push ($commit_count commits) and cannot inspect before..sha diff"
    fi
  fi
fi

pr=$(gh api "repos/$repo/commits/$sha/pulls" --jq '[.[]|select(.merged_at!=null)][0].number // empty') || skip false "PR lookup failed"
[ -n "$pr" ] || skip false "no merged PR for commit"
head=$(gh api "repos/$repo/pulls/$pr" --jq .head.sha)

git fetch --no-tags --depth=1 origin "$head" 2>/dev/null || skip false "cannot fetch PR head"
[ "$(git rev-parse "$sha^{tree}")" = "$(git rev-parse "$head^{tree}")" ] || skip false "tree differs from PR head (not up to date)"

if ! has_non_skipped_run "$head" pull_request; then
  skip false "no successful non-skipped PR run of $wf on $head"
fi
skip true "tree identical to PR #$pr head $head, green $wf"
