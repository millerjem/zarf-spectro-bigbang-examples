# Deployment Agent Guide

Use this guide to deploy the internal Zot registry, publish these Zarf
packages, and test them through Palette VerteX. Never commit registry
passwords, private keys, kubeconfigs, or Zarf signing keys.

## 1. Prerequisites

- A Kubernetes cluster reachable by the VerteX management plane.
- `kubectl`, `helm`, `zarf`, `oras`, and `jq`.
- A persistent StorageClass.
- Administrator access in Palette VerteX.
- A DNS name and TLS certificate for production. The current laboratory
  endpoint is `172.16.64.17:30003` and uses a private certificate.

## 2. Deploy VerteX with its internal Zot registry

Palette VerteX Management Appliance includes an internal Zot registry. This is
the registry used at `172.16.64.17:30003`. It is part of the VerteX management
cluster and is not the `zot-registry` pack that can be installed on a workload
cluster. Do not deploy a second Zot instance when the management appliance was
installed with **In Cluster Registry** enabled.

During a new Management Appliance installation, open the leader node Local UI
at `https://<leader-node-ip>:5080` and use these registry settings:

| Installation setting | Value for this environment | Purpose |
| --- | --- | --- |
| In Cluster Registry | `True` | Deploy and manage Zot with the VerteX management cluster |
| Registry Endpoint | `172.16.64.17` | VerteX management VIP provided by kube-vip |
| Registry Port | `30003` | HTTPS OCI registry port |
| OCI Registry Base Content Path | `spectro-content` | Palette and VerteX pack content; keep separate from custom Zarf packages |
| OCI Pack Registry Username | Registry administrator account | Bootstrap and Palette content management |
| OCI Pack Registry Password | Secret supplied during installation | Never store this value in Git |
| OCI Registry Storage Size | At least `250 GiB` for production | Persistent pack, image, and Zarf artifact storage |
| OCI Pack Registry CA Cert | Not required for appliance-generated Zot TLS | Provide a CA when replacing the certificate |
| Image Replacement Rules | Empty | Internal Zot is already integrated with VerteX |
| Root Domain | `172.16.64.17` | Management VIP used to reach the registry |

Complete the appliance installation and access the system console at
`https://172.16.64.17/system`. If VerteX is already running at this address,
the internal Zot is already deployed; validate it instead of reinstalling it.

Use separate namespaces in the same Zot service:

```text
172.16.64.17:30003/spectro-content/...  # VerteX packs and platform content
172.16.64.17:30003/zarf/packages/...    # Custom Zarf package artifacts
```

Validate network reachability without printing credentials:

```sh
curl --silent --show-error \
  --output /dev/null \
  --write-out '%{http_code}\n' \
  --insecure \
  https://172.16.64.17:30003/v2/
```

The current endpoint returns `401` without credentials. This is the expected
result: Zot is reachable over HTTPS and requires authentication. A request with
valid credentials returns `200`. Replace `--insecure` with
`--cacert /path/to/zot-ca.pem` after distributing the issuing CA.

The Palette CLI can authenticate to the same internal Zot endpoint:

```sh
palette content registry-login \
  --registry https://172.16.64.17:30003 \
  --username "$ZOT_USERNAME" \
  --password "$ZOT_PASSWORD"
```

Use the Local UI **Content** page and Palette CLI for official Palette pack
bundles under `spectro-content`. Use Zarf or ORAS for Zarf package artifacts
under `zarf/packages`.

## 3. Add the internal Zot as an OCI Zarf registry

The same Zot endpoint must be registered separately as provider type **Zarf**
before Zarf packages appear in the cluster-profile builder. Adding it as an OCI
Pack registry does not expose Zarf packages.

For tenant scope, log in as a Tenant Administrator and navigate to
**Tenant Settings → Registries → OCI Registries → Add New OCI Registry**. For a
registry shared by every VerteX tenant, use the system console registry page
and apply the same field values at system scope.

Configure the registry as follows:

| Field | Value |
| --- | --- |
| Name | `vertex-internal-zarf` |
| Provider | `Zarf` |
| Synchronization | Enabled |
| Endpoint | `https://172.16.64.17:30003` |
| Base Content Path | `zarf/packages` |
| Enable Authentication | Enabled |
| Username | Zot read-only account, or the current lab registry account |
| Password | Zot account password |
| Insecure Skip TLS Verify | Enabled only for the current private-certificate lab |
| CA certificate | Upload the Zot issuing CA when it is not publicly trusted |

Important synchronization behavior:

- Decide whether to enable synchronization before saving. The setting is
  immutable after the registry is created; recreate the entry to change it.
- Packages at the Zot repository root are not synchronized. They must be below
  the configured `zarf/packages` base path.
- Synchronization starts after registry creation, runs daily, and can also be
  triggered from the registry row's three-dot menu with **Sync**.
- Wait for **Last Synced** to show a timestamp before testing the profile UX.
- Prefer uploading the issuing CA. Certificate verification bypass is a
  temporary lab exception, not the production configuration.

After synchronization, these live repositories should be discoverable:

```text
spectro-gitops-secrets:0.1.0
spectro-mesh-policy:0.1.0
spectro-observability:0.1.0
spectro-security:0.1.0
zta-baseline:0.1.0
```

Validate the source registry independently of the VerteX UI:

```sh
oras repo ls --insecure 172.16.64.17:30003 | \
  grep '^zarf/packages/' | sort

oras repo tags --insecure \
  172.16.64.17:30003/zarf/packages/zta-baseline
```

The first command should show the repositories beneath `zarf/packages`; the
second should include `0.1.0`. Do not use the `spectro-content` base path for
this registry entry because it contains Palette pack artifacts, not this Zarf
package catalog.

## 4. Authenticate a publisher

Preferred production login:

```sh
printf '%s' "$ZOT_PASSWORD" | \
  zarf tools registry login \
    --username "$ZOT_USERNAME" \
    --password-stdin \
    zot.example.mil
```

Laboratory login against the current endpoint may require its private CA to be
installed. The build scripts accept `ZARF_INSECURE=true` only for this test
environment.

## 5. Build and publish

```sh
./scripts/validate.sh
./scripts/build-all.sh
./scripts/publish-all.sh
```

The publishing script defaults to:

```text
oci://172.16.64.17:30003/zarf/packages/<package>:0.1.0
```

Treat published version tags as immutable. Increment `metadata.version` before
publishing changed content, because registry behavior may allow a tag to be
replaced even though doing so makes deployments difficult to audit.

## 6. Deploy packages directly

Examples:

```sh
zarf package deploy \
  oci://172.16.64.17:30003/zarf/packages/spectro-security:0.1.0 \
  --components kyverno,trivy \
  --set-variables KYVERNO_REPLICAS=3,TRIVY_STORAGE_SIZE=20Gi \
  --insecure-skip-tls-verify

zarf package deploy \
  oci://172.16.64.17:30003/zarf/packages/zta-baseline:0.1.0 \
  --components kyverno,zta-identity,zta-device-posture,zta-network,zta-workload,zta-data \
  --set-variables ZTA_POLICY_MODE=Audit,ZTA_TARGET_NAMESPACE=zta-workloads \
  --insecure-skip-tls-verify
```

Required components are always deployed. Optional components can be selected
interactively or with `--components`.

## 7. Exercise the new Zarf UX in VerteX

The Zarf profile-layer UX turns a synchronized Zarf package into a selectable,
versioned cluster-profile layer. It exposes the package metadata, required and
optional components, and deployment variables without requiring an operator to
move the air-gap archive to each workload cluster.

### 7.1 Create a Zarf add-on profile

1. Wait for `vertex-internal-zarf` to show a **Last Synced** timestamp.
2. From the tenant console, select **Profiles → Add Cluster Profile**.
3. Enter `zarf-capabilities-lab`, choose profile type **Add-on**, and continue.
4. On **Profile Layers**, select **Add Zarf**.
5. In **Registry**, choose `vertex-internal-zarf`.
6. Select a package, choose the explicit `0.1.0` version, and review its
   description before continuing.
7. Keep required components selected. Enable only the optional components
   needed for this test.
8. Review the variables imported from `zarf.yaml` and replace defaults where
   the scenario requires it.
9. Confirm the Zarf layer, save or publish the profile, and attach the profile
   to a non-production cluster.
10. Watch the cluster's profile stack until the Zarf layer reaches `Running`.

The registry and package selectors prove catalog synchronization. Component
selection demonstrates package composition. Variable fields demonstrate how a
single immutable package artifact can be reused with cluster-specific values.

### 7.2 Security capability example

Choose `spectro-security:0.1.0` to demonstrate a required platform capability
with an optional companion:

| UX item | Test selection |
| --- | --- |
| Required component | `kyverno` |
| Optional component | `trivy` enabled |
| `KYVERNO_REPLICAS` | `3` |
| `TRIVY_STORAGE_CLASS` | Empty to use the cluster default |
| `TRIVY_STORAGE_SIZE` | `20Gi` |

Expected capabilities are Kyverno admission and background policy processing,
plus an optional Trivy vulnerability scanner whose image and chart are carried
inside the Zarf package.

### 7.3 ZTA side-by-side example

Add a second Zarf layer using `zta-baseline:0.1.0`:

| UX item | Test selection |
| --- | --- |
| Required component | `kyverno` |
| Optional components | `zta-identity`, `zta-device-posture`, `zta-network`, `zta-workload`, `zta-data` |
| Leave disabled initially | `istio-namespace-enrollment`, `oscal-kyverno` |
| `KYVERNO_REPLICAS` | `3` |
| `ZTA_POLICY_MODE` | `Audit` |
| `ZTA_TARGET_NAMESPACE` | `zta-workloads` |
| `ZTA_POD_SECURITY_LEVEL` | `restricted` |

This shows the distinction between a general security platform layer and a
mission-focused ZTA guardrail layer. Start in `Audit`, review policy reports,
then create a new profile version before moving to `Enforce`. Do not update an
actively deployed profile version in place for that promotion.

### 7.4 Other packages available in the UX

| Package | Required capability | Optional capability |
| --- | --- | --- |
| `spectro-observability` | Prometheus and Grafana | Loki logging |
| `spectro-mesh-policy` | Istio base, control plane, ingress, and runtime images | Kyverno |
| `spectro-gitops-secrets` | Flux controllers | External Secrets Operator |

These examples demonstrate several Zarf capabilities in the VerteX workflow:

- OCI discovery and version selection from an authenticated internal registry.
- One package containing multiple independently selectable components.
- Required foundations combined with optional integrations.
- User-set variables applied at deployment without rebuilding the package.
- Vendored Helm charts and container images for disconnected deployment.
- Package-generated SBOMs retained with the built artifact.
- Profile versioning and repeatable rollout to more than one workload cluster.

If a package is visible through ORAS but absent from **Add Zarf**, confirm the
provider is `Zarf`, synchronization is enabled, the base content path is exactly
`zarf/packages`, and the latest sync completed after the package was published.

## 8. Verification

```sh
kubectl get pods -A
kubectl get clusterpolicies.kyverno.io
kubectl get policyreports.wgpolicyk8s.io -A
kubectl get prometheus -A 2>/dev/null || true
kubectl get deployments -n monitoring
kubectl get pods -n istio-system
kubectl get pods -n flux-system
kubectl get pods -n external-secrets
```

For the ZTA package, start with `ZTA_POLICY_MODE=Audit`. Review policy reports
and application compatibility before changing the mode to `Enforce`.

## 9. Removal and recovery

Remove Zarf packages in reverse dependency order. Remove guardrail components
before Kyverno, and workloads before Istio or Flux. Back up Zot storage before
registry upgrades. Do not delete the Zot PVC unless package loss is intended
and recovery has been tested.

## 10. Scaffold a Zarf source repository

An agent may scaffold either a single-package repository or a multi-package
repository. First inspect the destination and preserve existing files. Never
copy credentials, kubeconfigs, signing keys, generated package archives, or
local registry configuration into source control.

Choose the repository model using these rules:

| Model | Use it when | Versioning and release behavior |
| --- | --- | --- |
| Single package | One package has its own owners, lifecycle, or release cadence | One `zarf.yaml` at the root; a repository tag can match the package version |
| Multiple packages | Several related packages share charts, automation, reviewers, and registry policy | One directory per package; each `metadata.version` changes independently |

### 10.1 Common scaffolding rules

- Use a lowercase, DNS-compatible `metadata.name` and never rename a published
  package without treating it as a new registry artifact.
- Start examples at version `0.1.0`. Increment the version whenever published
  content changes; do not overwrite an existing tag.
- Vendor Helm charts under `vendor/charts/` so builds do not depend on a live
  chart repository.
- Put deployment-specific overrides in values files instead of modifying the
  vendored chart.
- Make the platform foundation a required component and integrations optional
  with `default: false`.
- Define user-facing overrides under top-level `variables` and reference them
  as `###ZARF_VAR_VARIABLE_NAME###` in values files or manifests.
- Pin chart versions and container image tags. Do not use `latest`, floating
  chart ranges, or unversioned Git references.
- Run image discovery after changing a chart or values file. Review the result
  before accepting it; remove template placeholders such as Istio's `auto` and
  explicitly add the real runtime image when necessary.
- Build for an explicit architecture and keep `dist/` out of Git.
- Generate SBOMs during normal Zarf builds. Configure signing for production
  releases.

Use this minimal package definition as the starting point:

```yaml
kind: ZarfPackageConfig
metadata:
  name: example-package
  description: Example platform capability.
  version: 0.1.0

variables:
  - name: REPLICA_COUNT
    description: Number of application replicas.
    default: "2"

components:
  - name: application
    description: Required application foundation.
    required: true
    charts:
      - name: application
        namespace: example-system
        version: 1.2.3
        localPath: vendor/charts/application-1.2.3.tgz
        valuesFiles:
          - values/application.yaml

  - name: optional-integration
    description: Optional integration for the application.
    default: false
    manifests:
      - name: optional-integration
        namespace: example-system
        files:
          - manifests/optional-integration.yaml
```

Example variable use in `values/application.yaml`:

```yaml
replicaCount: ###ZARF_VAR_REPLICA_COUNT###
```

### 10.2 Single-package repository

Use this layout:

```text
example-package/
├── .gitignore
├── AGENT.md
├── README.md
├── zarf.yaml
├── values/
│   └── application.yaml
├── manifests/
│   └── optional-integration.yaml
├── vendor/
│   └── charts/
└── scripts/
    ├── validate.sh
    ├── build.sh
    └── publish.sh
```

The scripts should operate on the repository root:

```sh
zarf dev find-images . --update --skip-cosign --architecture amd64
zarf dev lint .
zarf package create . --architecture amd64 --output dist --confirm
zarf package publish \
  dist/zarf-package-example-package-amd64-0.1.0.tar.zst \
  oci://172.16.64.17:30003/zarf/packages \
  --confirm \
  --insecure-skip-tls-verify
```

Use `--insecure-skip-tls-verify` only for the current laboratory certificate.
Production automation must trust Zot's issuing CA and omit that option.

### 10.3 Multiple-package repository

Use this repository as the reference layout:

```text
zarf-packages/
├── .gitignore
├── AGENT.md
├── README.md
├── packages/
│   ├── package-one/
│   │   ├── zarf.yaml
│   │   └── values/
│   └── package-two/
│       ├── zarf.yaml
│       └── values/
├── vendor/
│   └── charts/
├── scripts/
│   ├── validate.sh
│   ├── build-all.sh
│   └── publish-all.sh
└── dist/
```

Package definitions refer to shared vendored charts relative to their package
directory, for example:

```yaml
localPath: ../../vendor/charts/application-1.2.3.tgz
```

Automation must discover package directories instead of maintaining a second
hard-coded package list:

```sh
for package_dir in packages/*; do
  zarf dev lint "$package_dir"
done

for package_dir in packages/*; do
  (
    cd dist
    zarf package create "../$package_dir" --architecture amd64 --confirm
  )
done
```

Publishing automation should enumerate `dist/zarf-package-*.tar.zst`, publish
each archive to the common `zarf/packages` base path, and stop on the first
failure. Record the resulting OCI manifest digest in the README or release
notes.

### 10.4 Required repository files

Every scaffold must include:

- `.gitignore` entries for `dist/`, `*.tar.zst`, `.DS_Store`, kubeconfigs,
  environment files, and private key formats.
- A README package matrix showing required and optional components, variables,
  source versions, build commands, registry references, and limitations.
- An `AGENT.md` containing the applicable parts of this guide.
- Executable validation, build, and publication scripts with
  `set -euo pipefail`.
- Source provenance for vendored charts and an explicit statement when a chart
  is an upstream equivalent rather than a proprietary Spectro artifact.

Before creating a GitHub repository, verify that no secrets or generated
archives are staged. Unless the user explicitly requests public visibility,
create the repository as private:

```sh
git init -b main
git add .
git status --short
git commit -m "Add Zarf package scaffold"
gh repo create millerjem/REPOSITORY_NAME \
  --private \
  --source . \
  --remote origin \
  --push
```

### 10.5 Scaffold completion checks

A scaffold is complete only when:

1. Every package passes `zarf dev lint`.
2. Every local Helm chart passes `helm lint` with representative package
   variables substituted into its values.
3. `zarf dev find-images` has been reviewed and every runtime image is listed.
4. At least one target-architecture archive builds successfully.
5. The archive definition can be inspected with `zarf package inspect`.
6. The destination tag does not already exist before publication.
7. After publication, the OCI tag and manifest digest resolve from Zot.
8. Git contains source and vendored inputs but not built archives or secrets.

## 11. Official references

This runbook was reconciled with the following Spectro Cloud documentation on
September 23, 2026:

- [VerteX Management Appliance and internal Zot](https://docs.spectrocloud.com/vertex/install-palette-vertex/vertex-management-appliance/)
- [Add an OCI Zarf registry](https://docs.spectrocloud.com/registries-and-packs/registries/oci-registry/add-oci-zarf/)
- [OCI registry scopes and providers](https://docs.spectrocloud.com/registries-and-packs/registries/oci-registry/)
- [Update cluster-profile layers](https://docs.spectrocloud.com/profiles/cluster-profiles/modify-cluster-profiles/update-cluster-profile/)
