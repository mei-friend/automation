#!/usr/bin/env bash
# Bulk-set GitHub Actions secrets across all repos in an org.
#
# Prerequisites:
#   brew install gh
#   gh auth login
#
# Usage:
#   ./update_secrets.sh --from-file ./secrets.env
#   ./update_secrets.sh NAME1=VALUE1 NAME2=VALUE2 ...
#
# The script prompts once per secret if it already exists somewhere,
# then applies the same decision to all repos.

set -euo pipefail

# ── CUSTOMIZE ──────────────────────────────────────────────────────────────────
# GitHub org (can also be overridden at runtime: ORG=my-org ./update_secrets.sh …)
ORG="${ORG:-your-org-name}"

# Repos to skip — add exact "org/repo-name" entries, or prefix patterns ending with *
EXCLUDED_REPOS=(
  "$ORG/.github"
  "$ORG/.github-private"
  # "$ORG/some-other-repo"   # uncomment to add more
)
# ── END CUSTOMIZE ──────────────────────────────────────────────────────────────

declare -A SECRETS
declare -A overwrite_decisions
SECRET_FILE=""

usage() {
  echo "Usage:"
  echo "  $0 --from-file ./secrets.env"
  echo "  $0 NAME1=VALUE1 NAME2=VALUE2 ..."
  echo
  echo "Env: ORG=<github-org>  (default: $ORG)"
}

abort() { echo "Error: $*" >&2; exit 1; }

require_gh() {
  command -v gh >/dev/null 2>&1 || abort "gh CLI not installed. Run: brew install gh"
  gh auth status >/dev/null 2>&1   || abort "gh not authenticated. Run: gh auth login"
}

parse_kv() {
  local kv="$1"
  [[ "$kv" == *"="* ]] || abort "Invalid format '$kv' (expected NAME=VALUE)"
  local name="${kv%%=*}" value="${kv#*=}"
  [[ -n "$name" && -n "$value" ]] || abort "Empty name or value in '$kv'"
  SECRETS["$name"]="$value"
}

load_env_file() {
  local file="$1"
  [[ -f "$file" ]] || abort "File not found: $file"
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"   # trim leading whitespace
    line="${line%"${line##*[![:space:]]}"}"   # trim trailing whitespace
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
    parse_kv "$line"
  done < "$file"
}

is_excluded() {
  local repo="$1"
  for pattern in "${EXCLUDED_REPOS[@]}"; do
    [[ "$repo" == $pattern ]] && return 0
  done
  return 1
}

# ── Parse arguments ────────────────────────────────────────────────────────────
if [[ $# -eq 0 ]]; then usage; exit 1; fi
while (( "$#" )); do
  case "$1" in
    --from-file) shift; SECRET_FILE="$1"; shift ;;
    -h|--help)   usage; exit 0 ;;
    *)           parse_kv "$1"; shift ;;
  esac
done
[[ -n "$SECRET_FILE" ]] && load_env_file "$SECRET_FILE"

require_gh

# ── Main loop ──────────────────────────────────────────────────────────────────
repos=()
while IFS=$'\t' read -r repo _rest; do
  repos+=("$repo")
done < <(gh repo list "$ORG" --limit 1000 --no-archived --source)

for repo in "${repos[@]}"; do
  if is_excluded "$repo"; then
    echo "Skipping: $repo"
    continue
  fi

  echo "Updating: $repo"
  existing=$(gh secret list -R "$repo" | awk '{print $1}')

  for name in "${!SECRETS[@]}"; do
    if echo "$existing" | grep -q "^$name$"; then
      if [[ -z "${overwrite_decisions[$name]:-}" ]]; then
        read -rp "Secret '$name' already exists. Overwrite in all repos? (y/N) " ans
        [[ "$ans" =~ ^[yY] ]] && overwrite_decisions["$name"]="yes" \
                               || overwrite_decisions["$name"]="no"
      fi
      if [[ "${overwrite_decisions[$name]}" != "yes" ]]; then
        echo "  — skipping $name"
        continue
      fi
    fi

    if gh secret set "$name" -R "$repo" --body "${SECRETS[$name]}" >/dev/null; then
      echo "  ✓ $name"
    else
      echo "  ✗ $name (failed)" >&2
    fi
  done
done
