# Repository Instructions

This repository contains reusable Zarf package examples for Palette VerteX,
the internal Zot registry, Spectro capabilities, and Miller ZTA guardrails.

When a task involves scaffolding, building, validating, publishing, registering,
or deploying Zarf packages, use the repository skill at
`skills/zarf-package-workflow/SKILL.md`. Read its detailed VerteX/Zot reference
only when the task touches that environment or registry operations.

Repository rules:

- Preserve unrelated user changes and inspect existing files before editing.
- Never commit registry passwords, API tokens, kubeconfigs, signing keys,
  private keys, or generated `*.tar.zst` archives.
- Treat published OCI version tags as immutable. Change `metadata.version`
  before publishing modified content.
- Keep vendored charts pinned and record their source and version.
- Do not publish, deploy to a cluster, create a GitHub repository, or replace a
  registry tag unless the user requested that external mutation.
- Run the validation appropriate to the changed package before committing.
- Keep the root README package matrix and published artifact information in
  sync with package definitions.
