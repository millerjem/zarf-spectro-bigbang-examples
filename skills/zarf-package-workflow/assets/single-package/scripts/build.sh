#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
architecture="${ZARF_ARCHITECTURE:-amd64}"

mkdir -p "${repo_root}/dist"
zarf package create "${repo_root}" \
  --architecture "${architecture}" \
  --output "${repo_root}/dist" \
  --confirm
