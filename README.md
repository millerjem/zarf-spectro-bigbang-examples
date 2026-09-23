# Zarf Spectro and ZTA Examples

This repository contains five Zarf packages for testing Palette VerteX and
Big-Bang-style platform capabilities in disconnected environments.

| Package | Required component | Optional components |
| --- | --- | --- |
| `spectro-security` | Spectro community Kyverno | Spectro community Trivy |
| `spectro-observability` | kube-prometheus-stack | Spectro community Loki |
| `spectro-mesh-policy` | Istio base, control plane, and ingress gateway | Spectro community Kyverno |
| `spectro-gitops-secrets` | Flux2 | External Secrets Operator |
| `zta-baseline` | Spectro community Kyverno | Miller ZTA guardrails, Istio namespace enrollment, and OSCAL-Kyverno operator |

The Kyverno, Trivy, and Loki charts are copied from Spectro Cloud's public
`pack-central` community-pack definitions. The remaining charts are pinned
upstream equivalents for capabilities listed in the Spectro pack catalog; they
are not exports of Spectro's proprietary verified-pack artifacts.

## Build

```sh
./scripts/validate.sh
./scripts/build-all.sh
```

The packages are built for `amd64` into `dist/`.

## Published test artifacts

Version `0.1.0` is available from the internal registry at
`172.16.64.17:30003/zarf/packages`:

| Package | OCI manifest digest |
| --- | --- |
| `spectro-gitops-secrets` | `sha256:b649166be57bac223e77dae5a16df0a37031ba256b650c59f81ddb85fbdf6f28` |
| `spectro-mesh-policy` | `sha256:b68c45e5c09a816f50de2f88aba624b19039bd2697af7db9a47b875dc1bd386d` |
| `spectro-observability` | `sha256:b1c8303ea9a442ec0f18349846a25327bfc506dc5ad764a3ce08c9295dde0824` |
| `spectro-security` | `sha256:774a0264d2c1b9ebb869f8a790d9e57f5af5d201d687da37514502648d91e6ec` |
| `zta-baseline` | `sha256:b66809ba22536c9f1d642b177d5bc14c1c9c1edc703c0094d92fa41721105049` |

## Publish

The default target is the internal Zot registry used by VerteX:

```sh
./scripts/publish-all.sh
```

Override the destination when necessary:

```sh
ZARF_REGISTRY=registry.example.mil:5000 \
ZARF_REPOSITORY=zarf/packages \
ZARF_INSECURE=false \
./scripts/publish-all.sh
```

Repository behavior is defined in [AGENTS.md](AGENTS.md). The reusable
[Zarf package workflow](skills/zarf-package-workflow/SKILL.md) contains
single-package and multi-package scaffolding guidance, while the detailed
[VerteX and Zot runbook](skills/zarf-package-workflow/references/vertex-zarf-runbook.md)
covers registry registration, package deployment, component selection, and
verification procedures.

## Package source versions

- Kyverno application `1.18.2`, Helm chart `3.8.2`
- Trivy Helm chart `0.4.12`
- Loki application `3.7.4`, Helm chart `18.5.2`
- kube-prometheus-stack Helm chart `91.5.0`
- Istio Helm charts `1.28.2`
- Flux2 Helm chart `2.17.2`
- External Secrets Operator Helm chart `2.11.0`
- Miller ZTA charts `0.1.1`; OSCAL-Kyverno operator `0.1.0`

The examples are deployment demonstrations, not a complete Platform One Big
Bang distribution, an authorization boundary, or evidence of compliance.

## Reuse the workflow

The repository includes a portable Codex skill at
`skills/zarf-package-workflow`. It contains working starter assets for both
repository models and a detailed VerteX/Zot reference. To use it outside this
repository, ask Codex to install the `zarf-package-workflow` skill from the
`skills/zarf-package-workflow` directory of this GitHub repository. Access to
the private repository must already be configured on the target machine.
