# Build (or update) the archive manifest. Existing entries are carried forward
# untouched for any version still in `have`; new entries are supplied by
# new_entries.jq. Dropped versions are emitted by dropped.jq.
#
# The published manifest is content-addressed, so its body carries no
# timestamps: neither a generation time, nor the per-version `published`
# times, which stay in the per-version sidecars. Serialization is sorted and
# compact (`jq -S -c`, see MANIFEST_JQ_ARGS in tools/archive/BUILD).

import "versions" as v;

($existing[0] // {}) as $existing_manifest
| ($existing_manifest.versions // {}) as $existing_versions
| ($have[0]) as $have_versions
| ($new_entries[0] // {}) as $new
| ($archive_bucket | rtrimstr("\n")) as $bucket
| (reduce $have_versions[] as $ver ({};
    .[$ver] = (if ($existing_versions | has($ver)) then $existing_versions[$ver] else $new[$ver] end)
  ) | map_values(del(.published))) as $versions
| {
    archive: "gs://\($bucket)/envoy/docs",
    versions: $versions,
    classification: ($versions | v::classify($stable_minors))
  }
