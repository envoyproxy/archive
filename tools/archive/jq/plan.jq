# Bazel build-time transform of `@envoy_repo//:project` into the `want`
# (release wanted iff its minor is in `.stable_versions`) and `excluded`
# (everything else) version lists, both semver-desc sorted.
#
# Wired up as the `//tools/archive:plan_inputs` `jq()` action; invoke with
# `-L tools/archive/jq` so `import "versions"` resolves.

import "versions" as v;

def normalize_version: if startswith("v") then . else "v" + . end;

.stable_versions as $stable
| [.releases[] | normalize_version] as $releases
| {
    want: ([$releases[] | select((v::minor) as $m | $stable | index($m))] | v::sort_versions),
    excluded: ([$releases[] | select(((v::minor) as $m | $stable | index($m)) | not)] | v::sort_versions)
  }
