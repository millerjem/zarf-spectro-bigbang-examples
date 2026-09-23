#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
registry="${ZARF_REGISTRY:?Set ZARF_REGISTRY to the registry host and port}"
repository="${ZARF_REPOSITORY:-zarf/packages}"
insecure="${ZARF_INSECURE:-false}"

shopt -s nullglob
archives=("${repo_root}"/dist/zarf-package-*.tar.zst)
if (( ${#archives[@]} != 1 )); then
  echo "Expected exactly one package archive in dist; found ${#archives[@]}." >&2
  exit 1
fi

tls_args=()
if [[ "${insecure}" == "true" ]]; then
  tls_args+=(--insecure-skip-tls-verify)
fi

zarf package publish \
  "${archives[0]}" \
  "oci://${registry}/${repository}" \
  --confirm \
  "${tls_args[@]}"
