---
name: zarf-package-workflow
description: Scaffold, validate, build, publish, register, and deploy single-package or multi-package Zarf repositories, including Palette VerteX and internal Zot workflows. Use for Zarf package authoring, repository structure, OCI publication, air-gap packaging, and Add Zarf profile layers.
---

# Zarf Package Workflow

Use this workflow to produce repeatable Zarf source repositories and operate
their package lifecycle without leaking credentials or replacing immutable
artifacts.

## Select the operating mode

- For one independently released package, start from
  `assets/single-package/`.
- For several related packages sharing charts and automation, start from
  `assets/multi-package/`.
- For the Palette VerteX management appliance, internal Zot, OCI Zarf registry,
  package publication, Add Zarf UX, or the `172.16.64.17` lab, read
  [references/vertex-zarf-runbook.md](references/vertex-zarf-runbook.md) in full
  before acting.
- For an existing repository, preserve its layout unless the user explicitly
  asks for restructuring. Reuse its scripts and conventions where practical.

## Scaffold

Inspect the destination before creating files. Copy the closest asset tree,
then replace the example package name, description, manifests, namespaces,
variables, component names, and versions with values from the task.

Use lowercase DNS-compatible package and component names. Make foundations
required and integrations optional with `default: false`. Put cluster-specific
settings in top-level Zarf variables and values files rather than modifying a
vendored chart.

Vendor Helm charts under `vendor/charts/`, pin chart versions and image tags,
and record provenance in the README. Do not use `latest`, floating chart
ranges, or unversioned Git references.

## Discover and verify package content

After chart, values, or manifest changes:

1. Run `zarf dev find-images` with representative variable values.
2. Review the discovered images. Remove templating placeholders such as
   Istio's `auto` and add the actual runtime image when necessary.
3. Run `zarf dev lint` for every package.
4. Run `helm lint` for local charts with representative Zarf variables
   substituted.
5. Build at least one explicit target architecture.
6. Inspect the built definition and, when relevant, rendered manifests.

Warnings about tag-versus-digest pinning require review. Mutable tags and
missing runtime images are not acceptable. A normal Zarf build resolves and
embeds the selected image content and generates SBOMs.

## Publish and deploy

Publication and deployment are external mutations. Perform them only when the
user requests them and use the requested registry, cluster, and architecture.

Before publication, confirm the destination tag does not exist. Afterward,
resolve the OCI manifest and record its digest. For a private CA, prefer adding
the CA trust chain; use insecure TLS only for an explicitly identified lab.

Start policy packages in audit mode when available. Validate a non-production
deployment before promotion, and use a new cluster-profile version for
material changes rather than rewriting an active version in place.

## Completion criteria

Report the repository path, package references, versions, architecture,
validation performed, registry digests when published, and anything not tested
against a live cluster. Keep generated archives out of Git.
