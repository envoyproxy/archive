# A single recursive `rclone lsjson` listing of envoy/docs -> sorted
# newest-first array of version prefixes present in the archive bucket.

import "versions" as v;

def version_re: "^v[0-9]+\\.[0-9]+\\.[0-9]+$";

[
  .[]
  | (.Path // .Name // "")
  | split("/")[0]
  | select(test(version_re))
]
| unique
| v::sort_versions
