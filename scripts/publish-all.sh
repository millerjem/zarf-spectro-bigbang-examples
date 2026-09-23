#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
registry="${ZARF_REGISTRY:-172.16.64.17:30003}"
repository="${ZARF_REPOSITORY:-zarf/packages}"
insecure="${ZARF_INSECURE:-true}"

shopt -s nullglob
packages=("${repo_root}"/dist/zarf-package-*.tar.zst)
if (( ${#packages[@]} == 0 )); then
  echo "No package archives found. Run scripts/build-all.sh first." >&2
  exit 1
fi

tls_args=()
if [[ "${insecure}" == "true" ]]; then
  tls_args+=(--insecure-skip-tls-verify)
fi

for package_file in "${packages[@]}"; do
  echo "Publishing ${package_file##*/}"
  zarf package publish \
    "${package_file}" \
    "oci://${registry}/${repository}" \
    --confirm \
    "${tls_args[@]}"
done

