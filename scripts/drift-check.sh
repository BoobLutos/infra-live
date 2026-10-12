#!/usr/bin/env bash
# Nightly drift detection for HCP Terraform free tier (which has no built-in
# health assessments). For each workspace it queues a plan-only run through the
# HCP Terraform API and reports any workspace whose plan is not empty.
#
# A non-empty plan means either drift (someone changed infrastructure outside
# Terraform) or merged code that hasn't been applied yet (e.g. a prod run still
# waiting for confirmation). Both deserve a look.
#
# Required env: TF_API_TOKEN, TFC_ORG, WORKSPACES (space-separated names)
# Optional env: TFC_HOST (default app.terraform.io), RUN_TIMEOUT_SECONDS (default 900),
#               TFC_API_URL (override the full API base URL, e.g. for testing)
set -euo pipefail

: "${TF_API_TOKEN:?TF_API_TOKEN is required}"
: "${TFC_ORG:?TFC_ORG is required}"
: "${WORKSPACES:?WORKSPACES is required}"
TFC_HOST="${TFC_HOST:-app.terraform.io}"
RUN_TIMEOUT_SECONDS="${RUN_TIMEOUT_SECONDS:-900}"
API="${TFC_API_URL:-https://${TFC_HOST}/api/v2}"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/stdout}"

api() {
  local method="$1" path="$2" body="${3:-}"
  local args=(-sS --fail-with-body -X "$method"
    -H "Authorization: Bearer ${TF_API_TOKEN}"
    -H "Content-Type: application/vnd.api+json")
  [[ -n "$body" ]] && args+=(--data "$body")
  curl "${args[@]}" "${API}${path}"
}

terminal_status() {
  case "$1" in
    planned_and_finished | planned_and_saved | errored | canceled | force_canceled | discarded | policy_soft_failed) return 0 ;;
    *) return 1 ;;
  esac
}

drifted=()
failed=()

{
  echo "## Drift check ($(date -u +%Y-%m-%dT%H:%MZ))"
  echo
  echo "| Workspace | Result | Run |"
  echo "| --- | --- | --- |"
} >>"$SUMMARY"

# The free tier allows one concurrent run, so workspaces are checked one at a time.
for ws in $WORKSPACES; do
  ws_id=$(api GET "/organizations/${TFC_ORG}/workspaces/${ws}" | jq -r '.data.id')

  payload=$(jq -n --arg ws_id "$ws_id" '{
    data: {
      type: "runs",
      attributes: { "plan-only": true, message: "Scheduled drift check (GitHub Actions)" },
      relationships: { workspace: { data: { type: "workspaces", id: $ws_id } } }
    }
  }')
  run_id=$(api POST "/runs" "$payload" | jq -r '.data.id')
  run_url="https://${TFC_HOST}/app/${TFC_ORG}/workspaces/${ws}/runs/${run_id}"
  echo "${ws}: queued ${run_id}"

  deadline=$((SECONDS + RUN_TIMEOUT_SECONDS))
  while :; do
    run_json=$(api GET "/runs/${run_id}?include=plan")
    status=$(jq -r '.data.attributes.status' <<<"$run_json")
    terminal_status "$status" && break
    if ((SECONDS > deadline)); then
      status="timed_out"
      break
    fi
    sleep 15
  done

  has_changes=$(jq -r '[.included[]? | select(.type == "plans") | .attributes["has-changes"]] | first // false' <<<"$run_json")

  if [[ "$status" == "planned_and_finished" && "$has_changes" == "true" ]]; then
    result="Changes found"
    drifted+=("$ws")
  elif [[ "$status" == "planned_and_finished" ]]; then
    result="No changes"
  else
    result="Run ended with status: ${status}"
    failed+=("$ws")
  fi

  echo "${ws}: ${result}"
  echo "| \`${ws}\` | ${result} | [${run_id}](${run_url}) |" >>"$SUMMARY"
done

if ((${#drifted[@]} > 0 || ${#failed[@]} > 0)); then
  {
    echo
    if ((${#drifted[@]} > 0)); then
      echo "Changes found in: ${drifted[*]}. Review the runs, then either apply the code or fix the manual change."
    fi
    if ((${#failed[@]} > 0)); then
      echo "Could not complete a check for: ${failed[*]}."
    fi
  } >>"$SUMMARY"
  exit 1
fi

echo >>"$SUMMARY"
echo "All workspaces match their code." >>"$SUMMARY"
