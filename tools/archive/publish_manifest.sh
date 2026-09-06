#!/usr/bin/env bash
set -euo pipefail

for h in "${RUNFILES_DIR:-}/_main/tools/archive/runfiles.sh" "${RUNFILES_DIR:-}/envoy_archive/tools/archive/runfiles.sh" "$0.runfiles/_main/tools/archive/runfiles.sh" "$0.runfiles/envoy_archive/tools/archive/runfiles.sh"; do [[ -f "$h" ]] && source "$h" && break; done
if ! declare -F archive_rlocation >/dev/null; then echo "ERROR: cannot find tools/archive/runfiles.sh" >&2; exit 1; fi
archive_require_gcp_key

RCLONE="$(archive_rlocation "${RCLONE_BIN}")"
META_BUCKET="$(cat "$(archive_rlocation "${META_BUCKET_FILE}")")"
MANIFEST="$(archive_rlocation "${MANIFEST_FILE}")"
CHANGED="$(archive_rlocation "${CHANGED_FILE}")"
DROPPED="$(archive_rlocation "${DROPPED_FILE}")"
MISSING_SIDECARS="$(archive_rlocation "${MISSING_SIDECARS_FILE}")"
if [[ -s "${MISSING_SIDECARS}" ]]; then
    echo "ERROR: archive versions without sidecars - run //tools/archive:backfill first:" >&2
    sed 's/^/  /' "${MISSING_SIDECARS}" >&2
    exit 1
fi

if [[ "$(cat "${CHANGED}")" != "true" ]]; then
    echo "Manifest is up to date, not updating"
    exit 0
fi
while read -r version; do
    [[ -z "${version}" ]] && continue
    printf 'WARNING: %s is recorded in the manifest but is not present in the archive bucket, dropping the entry. This should not happen and may indicate bucket tampering.\n' "${version}" >&2
done < "${DROPPED}"
"${RCLONE}" --config /dev/null rcat \
    --header-upload "Cache-Control: public, max-age=300" \
    "gcs:${META_BUCKET}/envoy/docs/versions.json" < "${MANIFEST}"
printf 'Manifest updated: gs://%s/envoy/docs/versions.json\n' "${META_BUCKET}"
