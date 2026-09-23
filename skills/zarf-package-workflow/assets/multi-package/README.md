# Example Zarf Package Collection

Place each independently versioned package under `packages/`. Share pinned
charts through `vendor/charts/` and let the scripts discover package
directories automatically.

```sh
./scripts/validate.sh
./scripts/build-all.sh
./scripts/publish-all.sh
```
