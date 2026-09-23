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

## 2. Deploy Zot

The preferred path is the Spectro **Zot Registry** pack because it keeps the
registry lifecycle in a Palette cluster profile.

1. Create an add-on cluster profile named `internal-zot`.
2. Add the `zot-registry` or `zot-registry-fips` pack supported by the installed
   VerteX release.
3. Keep the Service internal. Use `ClusterIP` when the VerteX management plane
   shares the service network. Use a privately routed `LoadBalancer` or
   `NodePort` only when required by the actual topology.
4. Enable persistent storage and choose a retained or snapshotted StorageClass.
5. Configure a write account for package publication and a read-only account
   for VerteX synchronization when the pack supports separate accounts.
6. Configure TLS. The certificate SAN must match the endpoint registered in
   VerteX. Distribute the issuing CA instead of disabling certificate
   verification in production.
7. Attach the profile and wait for the Zot workload and PVC to become ready.

Example validation commands:

```sh
kubectl get pods,svc,pvc -n zot-system
curl --fail --cacert /path/to/zot-ca.pem https://zot.example.mil/v2/
```

An HTTP `401` from `/v2/` proves that the registry is reachable and requires
authentication. A successful authenticated request normally returns `200`.

## 3. Register Zot in VerteX

In **Tenant Settings → Registries → OCI Registries**, add an OCI Zarf registry:

- Endpoint: the Zot HTTPS endpoint reachable from the management plane.
- Base content path: `zarf/packages`.
- Provider type: Zarf.
- Authentication: enabled, using the read-only account.
- Synchronization: enabled.
- Wait for synchronization: enabled.
- CA certificate: the private issuing CA when applicable.

Do not use the Spectro pack-registry setting for this purpose. A Palette pack
registry and an OCI Zarf registry are distinct resources.

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

## 7. Deploy through VerteX

1. Wait for the Zarf registry synchronization to complete.
2. Create or update an add-on cluster profile.
3. Add a Zarf layer and select one of the published package versions.
4. Select optional components and provide variable overrides in the layer
   values.
5. Publish the profile and attach it to a non-production test cluster.
6. Confirm the layer reaches `Running` before promoting it.

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
