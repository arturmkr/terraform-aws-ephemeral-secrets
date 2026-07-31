#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
FAILED=false

check_pattern() {
  local description=$1
  local pattern=$2
  if rg --glob '*.tf' --line-number "${pattern}" "${REPOSITORY_DIR}"; then
    echo "FAIL: ${description}" >&2
    FAILED=true
  fi
}

check_pattern \
  "Managed random generators persist their results in state; use ephemeral blocks." \
  'resource[[:space:]]+"random_(password|string|id|bytes|uuid)"'
check_pattern \
  "Managed TLS private keys persist private material in state; use an ephemeral block." \
  'resource[[:space:]]+"tls_private_key"'
check_pattern \
  "secret_string persists values in state; use secret_string_wo." \
  '(^|[^[:alnum:]_])secret_string[[:space:]]*='
check_pattern \
  "secret_binary persists values in state; this POC requires the write-only string path." \
  '(^|[^[:alnum:]_])secret_binary[[:space:]]*='

if [[ "${FAILED}" == "true" ]]; then
  exit 1
fi

echo "PASS: no state-persisting secret generator or Secrets Manager value argument found."
