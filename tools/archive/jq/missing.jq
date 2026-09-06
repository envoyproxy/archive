# `plan.json` output: reads the build-time `want`/`excluded` plan (from
# `//tools/archive:plan_inputs`, see plan.jq) plus the current `have` listing
# (rclone) and computes the versions still missing from the archive bucket.
#
# Usage: jq -n -L tools/archive/jq -f missing.jq \
#          --slurpfile plan_inputs <plan_inputs.json> \
#          --slurpfile have <have.json>

import "versions" as v;

($plan_inputs[0].want) as $want
| ($have[0]) as $have_versions
| {
    missing: ([$want[] as $version | select(($have_versions | index($version)) | not) | $version] | v::sort_versions),
    have: $have_versions
  }
