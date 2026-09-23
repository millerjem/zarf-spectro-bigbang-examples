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
