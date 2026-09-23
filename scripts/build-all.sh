#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
architecture="${ZARF_ARCHITECTURE:-amd64}"

mkdir -p "${repo_root}/dist"

for package_dir in "${repo_root}"/packages/*; do
  package_name="${package_dir##*/}"
  echo "Building ${package_name} for ${architecture}"
  (
    cd "${repo_root}/dist"
    zarf package create "${package_dir}" --architecture "${architecture}" --confirm
  )
done

echo "Built packages:"
find "${repo_root}/dist" -maxdepth 1 -name 'zarf-package-*.tar.zst' -print | sort

