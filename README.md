> [!WARNING]
> **This repository is archived and no longer maintained.**
>
> The Envoy docs can be reached via the Envoy website: **https://www.envoyproxy.io/docs**


# Envoy Proxy archive

This is an archive for the [Envoy Proxy](https://www.envoyproxy.io) documentation.

The built docs live in Google Cloud Storage, and the archive bucket is the
source of truth for what is published.

## Buckets

| | contents | retention | cache-control |
|---|---|---|---|
| `gs://$GCS_ARCHIVE_BUCKET` | `envoy/docs/vX.Y.Z/**` | immutable | `public, max-age=31536000, immutable` |
| `gs://$GCS_META_BUCKET` | `envoy/docs/versions.json`, `envoy/docs/versions.json.sha256`, `envoy/docs/versions/vX.Y.Z.json` | none (mutable) | `public, max-age=300` |
| `gs://$GCS_META_BUCKET` | `envoy/docs/manifest/sha256-<hex>.json` | immutable | `public, max-age=31536000, immutable` |

Both are public read. `versions.json` is a manifest of what is published - it
is derived data, folded together from the per-version sidecars
(`envoy/docs/versions/<version>.json`) by the reconcile.

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

`.github/workflows/envoy-sync.yaml` runs a stateless sync - it holds no state in
git, and makes no commits.

`.github/workflows/ci.yaml` runs the `tools/archive` tests and a read-only
reconcile on every pull request.

The read side is a Bazel graph:

1. `//tools/archive:listing`, `:existing`, and `:sidecars` are uncached local
   `genrule`s that use the pinned `@rclone//:rclone` binary to read the public
   buckets anonymously.
2. `//tools/archive:plan_inputs`, `:have`, `:sidecars_by_version`, `:plan`,
   `:missing_txt`, `:new_entries`, `:manifest`, `:changed`, `:dropped`, and
   `:summary` are `@aspect_bazel_lib` `jq()` actions. The jq programs live
   under `tools/archive/jq/` and share `versions.jq` for semver helpers.
3. `bazel build //tools/archive:plan` writes `bazel-bin/tools/archive/plan.json`.
   `bazel build //tools/archive:manifest` writes
   `bazel-bin/tools/archive/versions.json`.

The bucket names are Bazel `string_flag`s, defaulting to the public buckets
`envoy-cncf-archive` and `envoy-cncf-meta`. CI overrides them from repository
variables:

```console
$ bazel build \
    --//tools/archive:archive_bucket="$GCS_ARCHIVE_BUCKET" \
    --//tools/archive:meta_bucket="$GCS_META_BUCKET" \
    //tools/archive:plan //tools/archive:manifest //tools/archive:summary
```

The write side is deliberately small: `//tools/archive:publish` extracts one
docs tarball, uploads it with `rclone copy --ignore-existing`, and writes its
sidecar; `//tools/archive:publish_manifest` uploads `versions.json` only when
`changed.txt` says it changed; and `//tools/archive:backfill` writes sidecars
for versions that already exist in the archive bucket but have none. All three
require `GCP_KEY_PATH` to point at a readable service-account key.

To see what would be done without publishing anything, run the workflow with
`dry-run: true` (scheduled runs are dry runs), or locally build the read-side
targets and inspect the summary:

```console
$ bazel build //tools/archive:plan //tools/archive:missing_txt //tools/archive:summary
$ cat bazel-bin/tools/archive/summary.txt
```

### Manifest

`versions.json` records, for each published version, its minor version, the
number of objects published, and a `digest`. When it was published is recorded
in the per-version sidecar, not in the manifest.

The digest is a content digest, computed once by whoever publishes the
version (the sync workflow, or `//tools/archive:backfill` for versions
uploaded outside it) from the extracted docs tree, before upload:

```console
$ find . -type f -print0 | sort -z | xargs -r0 sha256sum \
    | sed 's|  \./|  |' | sed -E 's/^([0-9a-f]+)  (.*)$/\2 \1/' | LC_ALL=C sort \
    | sha256sum | cut -d' ' -f1
```

That is: `sha256` over the sorted lines `"<relative-path>
<sha256-hex-of-file>"` for every regular file in the version's docs tree,
where `<relative-path>` is the object key with the `envoy/docs/<version>/`
prefix stripped, emitted as `sha256:<hex>`. It is defined once, in
`tools/archive/digest.sh`, and shared by `//tools/archive:publish` and
`//tools/archive:backfill`.

Each version's digest, object count, and publish time are written as a
sidecar to the meta bucket at
`gs://$GCS_META_BUCKET/envoy/docs/versions/<version>.json`, alongside the
docs upload. Sidecars are written once and never overwritten - published docs
are immutable, and the recorded digest is what they would be verified
against. The reconcile's `//tools/archive:sidecars`/`:sidecars_by_version`
read side folds every sidecar into `versions.json`; it never derives digests
from a bucket listing, so the read-only reconcile
(`//tools/archive:new_entries`) skips versions without a sidecar rather than
recording an undigested entry, and `//tools/archive:publish_manifest`
refuses to upload the manifest until `//tools/archive:backfill`
(`--version=vX.Y.Z ...` or `--all`) has been run for them. The `versions/`
prefix also holds the content-addressed manifest copies described below, so
the sidecar read side only considers `v*.json` object names.

The manifest also carries the stable/archived classification of the published
versions, so the website can consume it in place of `versions.yaml`.

#### Pinning the manifest

Each publish writes three objects in the meta bucket:

| object | mutability | contents |
|---|---|---|
| `envoy/docs/versions.json` | mutable, overwritten on every publish | the latest manifest - discovery only, do not pin |
| `envoy/docs/manifest/sha256-<hex>.json` | immutable, never deleted | a copy of that manifest, where `<hex>` is the `sha256` of the file bytes |
| `envoy/docs/versions.json.sha256` | mutable, overwritten on every publish | `<hex>\n` for the current `versions.json` |

The content-addressed copy is written first, so `versions.json` never names a
manifest that is not also fetchable under its digest. Consumers that need a
hermetic input pin the content-addressed URL, using the same `<hex>` as their
checksum:

```starlark
http_file(
    name = "envoy_docs_versions",
    urls = ["https://storage.googleapis.com/$GCS_META_BUCKET/envoy/docs/manifest/sha256-<hex>.json"],
    sha256 = "<hex>",
)
```

`versions.json.sha256` is how a non-Bazel consumer discovers the current
`<hex>` without hashing the manifest itself.

Because the copies are pinned by consumers they are never deleted, and there
is no garbage collection. That only works if identical manifest content
serializes to identical bytes, so the manifest is emitted with sorted keys,
compact whitespace and a single trailing newline (`jq -S -c`), and carries no
timestamps - neither a generation time, nor the per-version `published`
times, which stay in the per-version sidecars. `//tools/archive:manifest_test`
diffs the manifest built from the fixtures in `tools/archive/testdata/`
against `tools/archive/testdata/golden/versions.json`, so serialization drift
fails CI.

## `docs/`

The `docs/` directory holds the pre-migration copy of the archive in git. It is
no longer read or written by any workflow, and is scheduled for removal - do not
add anything that depends on it.
