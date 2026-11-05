#!/usr/bin/env bash
# Applies the common repo setup in this repo to an existing GitHub repository.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ./apply.sh OWNER/REPO [--check CONTEXT]... [--dry-run]

  --check CONTEXT  Required status check context (job name as shown on PRs).
                   Repeat for each check. Without any, the
                   "Main: Require Status Checks" ruleset is skipped.
  --dry-run        Print the write calls instead of making them.
USAGE
}

root=$(cd "$(dirname "$0")" && pwd)
repo=""
checks=()
dry_run=false

while (($#)); do
  case "$1" in
    --check)
      (($# >= 2)) || { usage >&2; exit 2; }
      checks+=("$2")
      shift 2
      ;;
    --dry-run) dry_run=true; shift ;;
    -h | --help) usage; exit 0 ;;
    -*) usage >&2; exit 2 ;;
    *)
      [[ -z $repo ]] || { usage >&2; exit 2; }
      repo=$1
      shift
      ;;
  esac
done
[[ $repo == ?*/?* ]] || { usage >&2; exit 2; }

# Write calls go through here so --dry-run can show them. Reads call gh directly.
write() {
  if $dry_run; then
    echo "dry-run: gh api $*"
    if [[ " $* " == *" --input - "* ]]; then cat; fi
  else
    gh api --silent "$@"
  fi
}

visibility=$(gh api "repos/$repo" --jq .visibility)
echo "Applying to $repo ($visibility)"

echo "Repo settings"
write -X PATCH "repos/$repo" --input "$root/settings/repo.json"

echo "Actions policies"
write -X PUT "repos/$repo/actions/permissions" --input "$root/settings/actions-permissions.json"
write -X PUT "repos/$repo/actions/permissions/workflow" --input "$root/settings/actions-workflow-permissions.json"

echo "Security"
write -X PUT "repos/$repo/vulnerability-alerts"
write -X PUT "repos/$repo/automated-security-fixes"
if [[ $visibility == public ]]; then
  write -X PATCH "repos/$repo" \
    -f 'security_and_analysis[secret_scanning][status]=enabled' \
    -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled'
  write -X PUT "repos/$repo/private-vulnerability-reporting"
fi

echo "Rulesets"
if ! existing=$(gh api "repos/$repo/rulesets?per_page=100" --jq '.[] | "\(.id)\t\(.name)"' 2>&1); then
  # Private repos need GitHub Pro (personal) or Team (org) for rulesets.
  echo "Skipping rulesets: $existing" >&2
  exit 0
fi

checks_json=""
for check in ${checks[@]+"${checks[@]}"}; do
  check=${check//\\/\\\\}
  check=${check//\"/\\\"}
  checks_json+="${checks_json:+, }{ \"context\": \"$check\" }"
done

for file in "$root"/rulesets/*.json; do
  body=$(<"$file")
  name=$(sed -n 's/^  "name": "\(.*\)",$/\1/p' "$file")

  if [[ $body == *'"required_status_checks": []'* ]]; then
    if [[ -z $checks_json ]]; then
      echo "  Skipping $name (no --check given)"
      continue
    fi
    body=${body/'"required_status_checks": []'/"\"required_status_checks\": [$checks_json]"}
  fi

  id=$(awk -F '\t' -v name="$name" '$2 == name { print $1 }' <<<"$existing")
  if [[ -n $id ]]; then
    echo "  Updating $name"
    write -X PUT "repos/$repo/rulesets/$id" --input - <<<"$body"
  else
    echo "  Creating $name"
    write -X POST "repos/$repo/rulesets" --input - <<<"$body"
  fi
done
