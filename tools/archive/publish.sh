#!/usr/bin/env bash
set -euo pipefail

for h in "${RUNFILES_DIR:-}/_main/tools/archive/runfiles.sh" "${RUNFILES_DIR:-}/envoy_archive/tools/archive/runfiles.sh" "$0.runfiles/_main/tools/archive/runfiles.sh" "$0.runfiles/envoy_archive/tools/archive/runfiles.sh"; do [[ -f "$h" ]] && source "$h" && break; done
if ! declare -F archive_rlocation >/dev/null; then echo "ERROR: cannot find tools/archive/runfiles.sh" >&2; exit 1; fi

for h in "${RUNFILES_DIR:-}/_main/tools/archive/digest.sh" "${RUNFILES_DIR:-}/envoy_archive/tools/archive/digest.sh" "$0.runfiles/_main/tools/archive/digest.sh" "$0.runfiles/envoy_archive/tools/archive/digest.sh"; do [[ -f "$h" ]] && source "$h" && break; done
if ! declare -F archive_write_sidecar >/dev/null; then echo "ERROR: cannot find tools/archive/digest.sh" >&2; exit 1; fi

VERSION=""; TARBALL=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version=*) VERSION="${1#--version=}"; shift ;; --version) VERSION="$2"; shift 2 ;;
        --tarball=*) TARBALL="${1#--tarball=}"; shift ;; --tarball) TARBALL="$2"; shift 2 ;;
        *) echo "Unknown argument: $1" >&2; exit 2 ;;
    esac
done
[[ -n "$VERSION" && -f "$TARBALL" ]] || { echo "Usage: $0 --version=<vX.Y.Z> --tarball=<path>" >&2; exit 2; }
archive_require_gcp_key

RCLONE="$(archive_rlocation "${RCLONE_BIN}")"
ARCHIVE_BUCKET="$(cat "$(archive_rlocation "${ARCHIVE_BUCKET_FILE}")")"
META_BUCKET="$(cat "$(archive_rlocation "${META_BUCKET_FILE}")")"
work="$(mktemp -d)"
sidecar="${work}.sidecar.json"
trap 'rm -rf "${work}" "${sidecar}"' EXIT
tar --no-same-owner -xzf "${TARBALL}" -C "${work}"
files="$(find "${work}" -type f | wc -l | tr -d ' ')"
archive_write_sidecar "${VERSION}" "${work}" "${sidecar}"
"${RCLONE}" --config /dev/null copy \
    --ignore-existing \
    --header-upload "Cache-Control: public, max-age=31536000, immutable" \
    "${work}" "gcs:${ARCHIVE_BUCKET}/envoy/docs/${VERSION}"
published="$("${RCLONE}" --config /dev/null lsf -R --files-only "gcs:${ARCHIVE_BUCKET}/envoy/docs/${VERSION}" | wc -l | tr -d ' ')"
[[ "${published}" == "${files}" ]] || { printf 'ERROR: %s published %s objects, expected %s\n' "$VERSION" "$published" "$files" >&2; exit 1; }
"${RCLONE}" --config /dev/null copyto \
    --ignore-existing \
    --header-upload "Cache-Control: public, max-age=300" \
    "${sidecar}" "gcs:${META_BUCKET}/envoy/docs/versions/${VERSION}.json"
digest="$(sed -n 's/.*"digest": "\([^"]*\)".*/\1/p' "${sidecar}")"
printf 'Published %s (%s objects, %s)\n' "$VERSION" "$published" "$digest"
