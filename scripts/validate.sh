#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for package_dir in "${repo_root}"/packages/*; do
  echo "Linting ${package_dir##*/}"
  zarf dev lint "${package_dir}"
  zarf dev inspect manifests "${package_dir}" >/dev/null
done

for chart_dir in "${repo_root}"/vendor/charts/zta-* \
  "${repo_root}"/vendor/charts/istio-namespace-injection \
  "${repo_root}"/vendor/charts/oscal-kyverno-operator; do
  helm lint "${chart_dir}"
done

echo "Validation completed successfully."

