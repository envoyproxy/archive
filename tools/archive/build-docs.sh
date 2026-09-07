#!/bin/bash -e

# Build the Envoy docs for a release, producing a tarball rooted at the docs
# tree (ie extracting it yields `index.html` at the top level).
#
# Usage: tools/archive/build-docs.sh <version> <output.tar.gz>
#
# The build necessarily runs the target version's Envoy checkout, and its own
# Bazel version, so it cannot run inside this repo's Bazel.

set -o pipefail

VERSION="$1"
OUTPUT="$2"

if [[ -z "$VERSION" || -z "$OUTPUT" ]]; then
    echo "Usage: $0 <version> <output.tar.gz>" >&2
    exit 1
fi

ENVOY_SRC_DIR="${ENVOY_SRC_DIR:-../envoy}"
ENVOY_SRC="$(realpath "${ENVOY_SRC_DIR}")"
OUTPUT="$(realpath -m "${OUTPUT}")"

cd "${ENVOY_SRC}" || exit 1

git checkout "${VERSION}"
sed -i 's/morganite/mordenite/g' .bazelrc
sed -i 's/59f14d4fb373083b9dc8d389f16bbb817b5f936d1d436aa67e16eb6936028a51/fc694942e8a7491dcc1dde1bddf48a31370a1f46fef862bc17acf07c34dc6325/g' bazel/repository_locations.bzl

export DOCS_BUILD_RELEASE=1

rm -rf generated

if [[ "$VERSION" =~ ^v?(1.25|1.24)\..* ]]; then
    ./docs/build.sh
else
    if grep -q "remote-envoy-engflow" .bazelrc; then
        export BAZEL_BUILD_EXTRA_OPTIONS="--config=ci --config=remote-envoy-engflow"
    elif grep -q "rbe-envoy-engflow" .bazelrc; then
        export BAZEL_BUILD_EXTRA_OPTIONS="--config=ci --config=rbe-envoy-engflow"
    fi
    ./ci/run_envoy_docker.sh './ci/do_ci.sh docs'
fi

echo "Docs ${VERSION} built ..."

tar czf "${OUTPUT}" -C generated/docs .
rm -rf generated

echo "Docs ${VERSION} archived -> ${OUTPUT}"
