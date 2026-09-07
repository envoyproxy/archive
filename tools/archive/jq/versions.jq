# Shared version helpers, imported by the other `tools/archive/jq/*.jq`
# programs as `import "versions" as v;` (with `-L tools/archive/jq`).

# "v1.2.3" -> [1, 2, 3]
def semver: ltrimstr("v") | split(".") | map(tonumber);

# "v1.2.3" -> "1.2"
def minor: ltrimstr("v") | split(".") | .[0:2] | join(".");

# Sort an array of "vX.Y.Z" strings newest-first.
def sort_versions: sort_by(semver) | reverse;

# Classify a `{version: meta}` object into `{latest, stable, archived}`,
# grouped by minor version, with the `$stable_minors` newest minors (by
# minor-version number, not release date) considered stable and the rest
# archived.
def classify($stable_minors):
  . as $versions
  | ($versions | keys | sort_versions) as $all
  | (reduce $all[] as $v ({}; .[$v | minor] += [$v])) as $minors
  | ($minors | keys | sort_by(split(".") | map(tonumber)) | reverse) as $minor_names
  | ($minor_names[:$stable_minors]) as $stable_names
  | {
      latest: (if ($all | length) == 0 then null else $all[0] end),
      stable: (reduce $stable_names[] as $m ({}; .[$m] = $minors[$m])),
      archived: (reduce ($minor_names[] as $m | select(($stable_names | index($m)) | not) | $m) as $m ({}; .[$m] = $minors[$m]))
    };
