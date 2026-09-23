#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
architecture="${ZARF_ARCHITECTURE:-amd64}"

mkdir -p "${repo_root}/dist"
for package_dir in "${repo_root}"/packages/*; do
  zarf package create "${package_dir}" \
    --architecture "${architecture}" \
    --output "${repo_root}/dist" \
    --confirm
done
