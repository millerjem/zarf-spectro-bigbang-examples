#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for package_dir in "${repo_root}"/packages/*; do
  zarf dev lint "${package_dir}"
done
