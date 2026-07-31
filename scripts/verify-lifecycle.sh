#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEPLOYMENT_DIR="${REPOSITORY_DIR}/environments/dev"
VERIFY="${SCRIPT_DIR}/verify.py"
CREATED_WORKSPACE=false

for command in terraform aws python3; do
  command -v "${command}" >/dev/null || {
    echo "Required command not found: ${command}" >&2
    exit 1
  }
done

TEMP_DIR="$(mktemp -d)"
ORIGINAL_WORKSPACE="$(terraform -chdir="${DEPLOYMENT_DIR}" workspace show)"
WORKSPACE="verify-$(date +%Y%m%d%H%M%S)"

cleanup() {
  local status=$?
  trap - EXIT INT TERM
  if [[ "${CREATED_WORKSPACE}" == "true" ]]; then
    export TF_VAR_value_versions='{"service-password":2}'
    terraform -chdir="${DEPLOYMENT_DIR}" destroy -auto-approve -input=false >/dev/null || true
    terraform -chdir="${DEPLOYMENT_DIR}" workspace select "${ORIGINAL_WORKSPACE}" >/dev/null || true
    terraform -chdir="${DEPLOYMENT_DIR}" workspace delete "${WORKSPACE}" >/dev/null || true
  fi
  if [[ -n "${TEMP_DIR}" && -d "${TEMP_DIR}" ]]; then
    rm -rf -- "${TEMP_DIR}"
  fi
  exit "${status}"
}
trap cleanup EXIT INT TERM

terraform -chdir="${DEPLOYMENT_DIR}" workspace new "${WORKSPACE}" >/dev/null
CREATED_WORKSPACE=true

export TF_IN_AUTOMATION=true
export TF_INPUT=false
export TF_VAR_application_name="verification-${WORKSPACE}"
unset TF_LOG TF_LOG_PATH

echo "1/7 Initial apply in isolated workspace ${WORKSPACE}"
terraform -chdir="${DEPLOYMENT_DIR}" apply -auto-approve -input=false
python3 "${VERIFY}" snapshot --root-dir "${DEPLOYMENT_DIR}" >"${TEMP_DIR}/initial.json"

echo "2/7 Verify non-empty values and absence from state and a saved no-op plan"
terraform -chdir="${DEPLOYMENT_DIR}" plan -input=false -out="${TEMP_DIR}/no-op.tfplan"
python3 "${VERIFY}" artifacts --root-dir "${DEPLOYMENT_DIR}" --plan "${TEMP_DIR}/no-op.tfplan"

echo "3/7 Second apply must retain every AWS version ID"
terraform -chdir="${DEPLOYMENT_DIR}" apply -auto-approve -input=false
python3 "${VERIFY}" snapshot --root-dir "${DEPLOYMENT_DIR}" >"${TEMP_DIR}/second.json"
python3 "${VERIFY}" compare-same \
  --before "${TEMP_DIR}/initial.json" \
  --after "${TEMP_DIR}/second.json"

echo "4/7 Tag-only apply must retain every AWS version ID"
export TF_VAR_verification_tag="tag-only-$(date +%s)"
terraform -chdir="${DEPLOYMENT_DIR}" apply -auto-approve -input=false
python3 "${VERIFY}" snapshot --root-dir "${DEPLOYMENT_DIR}" >"${TEMP_DIR}/tagged.json"
python3 "${VERIFY}" compare-same \
  --before "${TEMP_DIR}/second.json" \
  --after "${TEMP_DIR}/tagged.json"

echo "5/7 Plan an intentional rotation from value_version 1 to 2"
export TF_VAR_value_versions='{"service-password":2}'
terraform -chdir="${DEPLOYMENT_DIR}" plan -input=false -out="${TEMP_DIR}/rotation.tfplan"
python3 "${VERIFY}" artifacts --root-dir "${DEPLOYMENT_DIR}" --plan "${TEMP_DIR}/rotation.tfplan"
python3 "${VERIFY}" plan-no-secret-replacement \
  --root-dir "${DEPLOYMENT_DIR}" \
  --plan "${TEMP_DIR}/rotation.tfplan"

echo "6/7 Apply rotation and compare AWS Secrets Manager version IDs"
terraform -chdir="${DEPLOYMENT_DIR}" apply -input=false "${TEMP_DIR}/rotation.tfplan"
python3 "${VERIFY}" snapshot --root-dir "${DEPLOYMENT_DIR}" >"${TEMP_DIR}/rotated.json"
python3 "${VERIFY}" compare-rotation \
  --before "${TEMP_DIR}/tagged.json" \
  --after "${TEMP_DIR}/rotated.json" \
  --target service-password

echo "7/7 Re-check post-rotation state"
python3 "${VERIFY}" artifacts --root-dir "${DEPLOYMENT_DIR}"
echo "All lifecycle and secret-persistence checks passed."
