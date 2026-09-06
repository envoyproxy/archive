# Envoy Proxy archive

This is an archive for the [Envoy Proxy](https://www.envoyproxy.io) documentation.

The built docs live in Google Cloud Storage, and the archive bucket is the
source of truth for what is published.

## Buckets

| | contents | retention | cache-control |
|---|---|---|---|
| `gs://$GCS_ARCHIVE_BUCKET` | `envoy/docs/vX.Y.Z/**` | immutable | `public, max-age=31536000, immutable` |
| `gs://$GCS_META_BUCKET` | `envoy/docs/versions.json` | none (mutable) | `public, max-age=300` |

Both are public read. `versions.json` is a manifest of what is published - it
is derived data and can be regenerated from a listing of the archive bucket at
any time.

Required repo configuration:

- Secret `GCS_ARCHIVE_KEY` — base64 encoded JSON key for a service account with
  `roles/storage.objectCreator` and `roles/storage.objectViewer` on the archive
  bucket, and `roles/storage.objectUser` on the meta bucket. It is consumed via
  `envoyproxy/toolshed/actions/gcp/setup`.
- Variable `GCS_ARCHIVE_BUCKET` — the name of the archive bucket.
- Variable `GCS_META_BUCKET` — the name of the meta bucket.

Authentication currently uses this long-lived service account key, matching the
existing envoy docs publishing setup. Migrating to OIDC/Workload Identity
Federation is a TODO.

## Syncing the archive

`.github/workflows/envoy-sync.yaml` runs a stateless reconciler - it holds no
state in git, and makes no commits:

1. **have** — the version prefixes under `gs://$GCS_ARCHIVE_BUCKET/envoy/docs/`.
2. **want** — the Envoy releases whose minor version is currently stable,
   resolved from `@envoy_repo//:project`.
3. **missing** — `want` minus `have`, written to `plan.json` by
   `//tools/archive:reconcile`.
4. Each missing version is built with `tools/archive/build-docs.sh` and
   published by `//tools/archive:publish`, which uploads it with
   `gcloud storage rsync --no-clobber`, verifies the uploaded object count
   against the tarball, and regenerates the manifest if the published set
   changed.

To see what would be done without publishing anything, run the workflow with
`dry-run: true` (scheduled runs are dry runs), or locally:

```console
$ bazel run //tools/archive:reconcile -- \
      --archive-bucket=<archive-bucket> \
      --meta-bucket=<meta-bucket> \
      --output=/tmp/plan.json \
      --dry-run
```

### Manifest

`versions.json` records, for each published version, its minor version, the
number of objects published, when it was published, and a `digest`:

```console
$ sha256sum <<< "$(<relative-object-path> <md5Hash> for each object, sorted)"
```

The `md5Hash` comes from the GCS object listing, so the digest can be
recomputed by anyone with read access to the bucket, without downloading the
docs. Entries for versions that are already recorded are never recomputed -
published docs are immutable, and the recorded digest is what they are verified
against.

The manifest also carries the stable/archived classification of the published
versions, so the website can consume it in place of `versions.yaml`.

## `docs/`

The `docs/` directory holds the pre-migration copy of the archive in git. It is
no longer read or written by any workflow, and is scheduled for removal - do
not add anything that depends on it.
