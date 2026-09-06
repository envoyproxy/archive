# Key an array of raw per-version sidecars (one per
# gs://$META_BUCKET/envoy/docs/versions/<version>.json, each
# `{version, digest, objects, published}`) by version.
#
# Usage: jq -f sidecars.jq <sidecars.json>

reduce .[] as $sidecar ({}; .[$sidecar.version] = $sidecar)
