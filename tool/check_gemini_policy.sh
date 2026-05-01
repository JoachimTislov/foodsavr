#!/usr/bin/env bash
set -euo pipefail

POLICY_FILE=".gemini/policies/shell.toml"
MAKEFILE="Makefile"

if [[ ! -f "$POLICY_FILE" ]] || [[ ! -f "$MAKEFILE" ]]; then
  exit 0
fi

is_make=false
is_allow=false
commands_str=""

# Parse the TOML file block by block
while IFS= read -r line || [[ -n "$line" ]]; do
  # Check for a new table/block, e.g. [[rules]]
  if [[ "$line" =~ ^\[+.*\]+ ]]; then
    # If the previous block matched both conditions, we are done searching
    if [[ "$is_make" == true && "$is_allow" == true ]]; then
      break
    fi
    # Reset for the new block
    is_make=false
    is_allow=false
    commands_str=""
  fi
  
  # Check for commandRegex matching 'make' and extract the group in parentheses
  if [[ "$line" =~ commandRegex.*make.*\(([^)]+)\) ]]; then
    is_make=true
    commands_str="${BASH_REMATCH[1]}"
  fi
  
  # Check for decision = "allow"
  if [[ "$line" =~ decision[[:space:]]*=[[:space:]]*\"allow\" ]]; then
    is_allow=true
  fi
done < "$POLICY_FILE"

# If the file ended and we never found a block that has both, exit cleanly
if [[ "$is_make" != true || "$is_allow" != true ]]; then
  exit 0
fi

IFS='|' read -ra COMMANDS <<< "$commands_str"
MISSING_FOUND=false

for cmd in "${COMMANDS[@]}"; do
  # Remove regex anchors, boundary markers, and extra spaces
  clean_cmd=$(echo "$cmd" | sed 's/[ \^$]//g; s/\\b//g')
  if [[ -z "$clean_cmd" ]]; then continue; fi

  # Check if it exists in the Makefile
  if ! grep -E -q "^${clean_cmd}:|\.PHONY:.* ${clean_cmd}( |$)" "$MAKEFILE"; then
    echo "MISSING: Target '$clean_cmd' is allowed by $POLICY_FILE but DOES NOT exist in $MAKEFILE"
    MISSING_FOUND=true
  fi
done

if [[ "$MISSING_FOUND" == true ]]; then
  exit 1
fi
