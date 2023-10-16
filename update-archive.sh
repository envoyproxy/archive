#!/bin/bash -e

set -o pipefail


ENVOY_SRC_DIR="${ENVOY_SRC_DIR:-../envoy}"
ENVOY_SRC="$(realpath "${ENVOY_SRC_DIR}")"
WORKSPACE="$(realpath .)"
DOCS_FOLDER="docs/envoy"

# This should be done in the context of Envoy main (not necessarily in workspace)
bazel build @envoy_repo//:project
_RELEASES="$(jq -r '.releases[]' bazel-bin/external/envoy_repo/project.json | tr '\n' ' ')"
read -ra RELEASES <<< $_RELEASES
_STABLES="$(jq -r '.stable_versions[]' bazel-bin/external/envoy_repo/project.json | tr '\n' ' ')"
read -ra STABLES <<< $_STABLES

if [[ -n "$COMMITTER_NAME" ]]; then
    git config --global user.name "$COMMITTER_NAME"
fi

if [[ -n "$COMMITTER_EMAIL" ]]; then
    git config --global user.email "$COMMITTER_EMAIL"
fi

build_docs () {
    local version="$1"
    cd "${ENVOY_SRC}" || exit 1
    git checkout "${version}"
    export DOCS_BUILD_RELEASE=1
    if [[ "$version" =~ ^(1.25|1.24)\..* ]]; then
        ./docs/build.sh
    else
        ./ci/run_envoy_docker.sh './ci/do_ci.sh docs'
    fi
    mv generated/docs/* "${WORKSPACE}/${DOCS_FOLDER}/${version}"
    rm -rf generated
    cd - || exit 1
}

archive_docs () {
    local version="$1"
    echo "Archiving docs: ${version}"
    mkdir -p "${DOCS_FOLDER}/${version}"
    build_docs "${version}"
    git add "${DOCS_FOLDER}/${version}"
    git commit "${DOCS_FOLDER}/${version}" -m "archive: Add documentation (${version})"
}

SHOULD_PUSH=

for version in "${RELEASES[@]}"; do
    if [[ -e "${DOCS_FOLDER}/${version}" ]]; then
        continue
    fi
    minor="${version%.*}"
    if [[ " ${STABLES[*]} " =~ " ${minor:1} " ]]; then
        archive_docs "$version"
        SHOULD_PUSH=1
    fi
done

if [[ -n "$SHOULD_PUSH" ]]; then
    echo "Pushing changes to the archive ..."
    git push origin HEAD:main
fi
