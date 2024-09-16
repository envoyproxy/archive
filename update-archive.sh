#!/bin/bash -e

set -o pipefail


ENVOY_SRC_DIR="${ENVOY_SRC_DIR:-../envoy}"
ENVOY_SRC="$(realpath "${ENVOY_SRC_DIR}")"
WORKSPACE="$(realpath .)"
DOCS_FOLDER="docs/envoy"
TEST_ONLY="${TEST_ONLY:-}"
SHOULD_PUSH=


# This should be done in the context of Envoy main (not necessarily in workspace)
bazel build --config=ci --config=remote-envoy-engflow @envoy_repo//:project

_RELEASES="$(bazel run --config=ci --config=remote-envoy-engflow --@envoy//tools/jq:target=@envoy_repo//:project @envoy//tools/jq -- -r '.releases[]' | tr '\n' ' ')"
read -ra RELEASES <<< $_RELEASES
_STABLES="$(bazel run --config=ci --config=remote-envoy-engflow --@envoy//tools/jq:target=@envoy_repo//:project @envoy//tools/jq -- -r '.stable_versions[]' | tr '\n' ' ')"
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
        if git grep -q "remote-envoy-engflow" .bazelrc; then
            export BAZEL_BUILD_EXTRA_OPTIONS="--config=ci --config=remote-envoy-engflow"
        elif git grep -q "rbe-envoy-engflow" .bazelrc; then
            export BAZEL_BUILD_EXTRA_OPTIONS="--config=ci --config=rbe-envoy-engflow"
        fi
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


for version in "${RELEASES[@]}"; do
    minor="${version%.*}"
    if [[ -e "${DOCS_FOLDER}/${version}" ]]; then
        continue
    fi
    if [[ " ${STABLES[*]} " =~ " ${minor:1} " ]]; then
        archive_docs "$version"
        if [[ -z "$TEST_ONLY" ]]; then
            SHOULD_PUSH=1
        else
            # this should not have change, but seems there is an issue with tmp paths
            git show --name-only
        fi
    fi
done


if [[ -n "$SHOULD_PUSH" ]]; then
    echo "Pushing changes to the archive ..."
    git push origin HEAD:main
else
    git status
fi
