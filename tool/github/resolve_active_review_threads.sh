#!/usr/bin/env bash
set -euo pipefail

"$(dirname "$(realpath "$0")")/resolve_review_threads_base.sh" active "$@"
