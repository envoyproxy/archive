# Envoy Proxy archive

This is an archive for the [Envoy Proxy](https://www.envoyproxy.io) documentation.

## GCS archive bucket

Archived docs are being migrated out of git into a public GCS bucket. This requires:

- A repo secret `GCS_ARCHIVE_KEY` — the JSON key for a service account with
  `roles/storage.objectCreator` and `roles/storage.objectViewer` scoped to the
  bucket only.
- A repo variable `GCS_ARCHIVE_BUCKET` — the name of the bucket.

Authentication currently uses this long-lived service account key, matching the
existing envoy docs publishing setup. Migrating to OIDC/Workload Identity
Federation is a TODO.

### Seeding the bucket

The one-off `.github/workflows/gcs-seed.yaml` workflow copies the existing
`docs/envoy/vX.Y.Z/` directories into the bucket. Trigger it manually
(`workflow_dispatch`) with a single version first (e.g. `v1.39.1`), check that
the uploaded objects have the correct paths and `Cache-Control` header, then
re-run it with `version: all` to seed everything else.
