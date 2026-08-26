#!/bin/bash -e

set -o pipefail

ENVOY_SRC_DIR="${ENVOY_SRC_DIR:-../envoy}"
ENVOY_SRC="$(realpath "${ENVOY_SRC_DIR}")"
WORKSPACE="$(realpath .)"
DOCS_FOLDER="docs/envoy"
TEST_ONLY="${TEST_ONLY:-}"
SHOULD_PUSH=
ENGFLOW_HOST="mordenite.cluster.engflow.com"
ENGFLOW_HELPER_PATH="bazel/engflow-bazel-credential-helper.sh"
ENGFLOW_FALLBACK_CONFIG="archive-sync-engflow"


# This should be done in the context of Envoy main (not necessarily in workspace)
bazel build --config=ci --config=remote-envoy-engflow @envoy_repo//:project

# TODO: fix upstream stamping of project data
CACHEBUST=$(git rev-parse HEAD | head -c7)

_RELEASES="$(bazel run --action_env=CACHEBUST=${CACHEBUST} --host_action_env=CACHEBUST=${CACHEBUST} --config=ci --config=remote-envoy-engflow --@envoy//tools/jq:target=@envoy_repo//:project @envoy//tools/jq -- -r '.releases[]' | tr '\n' ' ')"
read -ra RELEASES <<< $_RELEASES
_STABLES="$(bazel run --action_env=CACHEBUST=${CACHEBUST} --host_action_env=CACHEBUST=${CACHEBUST} --config=ci --config=remote-envoy-engflow --@envoy//tools/jq:target=@envoy_repo//:project @envoy//tools/jq -- -r '.stable_versions[]' | tr '\n' ' ')"
read -ra STABLES <<< $_STABLES

if [[ -n "$COMMITTER_NAME" ]]; then
    git config --global user.name "$COMMITTER_NAME"
fi

if [[ -n "$COMMITTER_EMAIL" ]]; then
    git config --global user.email "$COMMITTER_EMAIL"
fi

die () {
    echo "ERROR: $*" >&2
    exit 1
}

patch_engflow_endpoint () {
    [[ -f .bazelrc ]] || die "Envoy ${1} is missing .bazelrc; cannot configure EngFlow RBE for docs."
    sed -i -E "s#[[:alnum:].-]+\\.cluster\\.engflow\\.com#${ENGFLOW_HOST}#g" .bazelrc
}

ensure_engflow_credential_helper () {
    mkdir -p "$(dirname "${ENGFLOW_HELPER_PATH}")"
    if [[ ! -f "${ENGFLOW_HELPER_PATH}" ]]; then
        cat > "${ENGFLOW_HELPER_PATH}" <<'EOF'
#!/usr/bin/env bash
cat /dev/stdin > /dev/null
token_var=GITHUB_TOKEN
printf '%s\n' '{"headers":{"Auth'"orization":["Bearer '"${!token_var}"'"]}}'
EOF
    fi
    chmod +x "${ENGFLOW_HELPER_PATH}"
}

ensure_docker_compose_env () {
    local compose_file=
    local candidate=
    for candidate in ci/docker-compose.yml ci/docker-compose.yaml; do
        if [[ -f "${candidate}" ]]; then
            compose_file="${candidate}"
            break
        fi
    done
    [[ -n "${compose_file}" ]] || return 0
    python - "${compose_file}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
lines = path.read_text().splitlines()


def has_entry(name: str) -> bool:
    return any(line.strip() == f"- {name}" for line in lines)


def insert_after(target: str, entry: str) -> None:
    for index, line in enumerate(lines):
        if line.strip() == target:
            lines.insert(index + 1, f"  - {entry}")
            return
    raise SystemExit(f"{path} is missing '{target}', cannot add '{entry}' for archive docs RBE forwarding")


if not has_entry("BAZEL_BUILD_EXTRA_OPTIONS"):
    for target in ("- BAZEL_STARTUP_OPTIONS", "- BAZEL_REMOTE_CACHE"):
        try:
            insert_after(target, "BAZEL_BUILD_EXTRA_OPTIONS")
            break
        except SystemExit:
            continue
    else:
        raise SystemExit(f"{path} is missing a Bazel environment marker; cannot add BAZEL_BUILD_EXTRA_OPTIONS for archive docs RBE forwarding")

if not has_entry("GITHUB_TOKEN"):
    for target in ("- GITHUB_REF_TYPE", "- GITHUB_REF_NAME", "- BUILD_REASON"):
        try:
            insert_after(target, "GITHUB_TOKEN")
            break
        except SystemExit:
            continue
    else:
        raise SystemExit(f"{path} is missing a GitHub environment marker; cannot add GITHUB_TOKEN for archive docs RBE forwarding")

path.write_text("\n".join(lines) + "\n")
PY
}

append_engflow_fallback_config () {
    if grep -q "${ENGFLOW_FALLBACK_CONFIG}" .bazelrc; then
        return
    fi
    cat >> .bazelrc <<EOF

common:${ENGFLOW_FALLBACK_CONFIG} --google_default_credentials=false
common:${ENGFLOW_FALLBACK_CONFIG} --credential_helper=*.engflow.com=%workspace%/${ENGFLOW_HELPER_PATH}
common:${ENGFLOW_FALLBACK_CONFIG} --grpc_keepalive_time=30s
common:${ENGFLOW_FALLBACK_CONFIG} --remote_cache=grpcs://${ENGFLOW_HOST}
common:${ENGFLOW_FALLBACK_CONFIG} --remote_timeout=3600s
common:${ENGFLOW_FALLBACK_CONFIG} --bes_backend=grpcs://${ENGFLOW_HOST}/
common:${ENGFLOW_FALLBACK_CONFIG} --bes_results_url=https://${ENGFLOW_HOST}/invocation/
common:${ENGFLOW_FALLBACK_CONFIG} --bes_timeout=3600s
common:${ENGFLOW_FALLBACK_CONFIG} --bes_upload_mode=fully_async
common:${ENGFLOW_FALLBACK_CONFIG} --nolegacy_important_outputs
common:${ENGFLOW_FALLBACK_CONFIG} --remote_executor=grpcs://${ENGFLOW_HOST}
common:${ENGFLOW_FALLBACK_CONFIG} --remote_default_exec_properties=container-image=docker://gcr.io/envoy-ci/envoy-build@sha256:25a68eff24b7414a346977d545687b87851d1c5746c466798050fa12fc5d0686
common:${ENGFLOW_FALLBACK_CONFIG} --jobs=200
EOF
}

resolve_docs_rbe_config () {
    if grep -q "remote-envoy-engflow" .bazelrc; then
        echo "remote-envoy-engflow"
    elif grep -q "rbe-envoy-engflow" .bazelrc; then
        echo "rbe-envoy-engflow"
    elif grep -q "rbe-engflow" .bazelrc; then
        echo "rbe-engflow"
    else
        append_engflow_fallback_config
        echo "${ENGFLOW_FALLBACK_CONFIG}"
    fi
}

prepare_docs_rbe () {
    local version="$1"
    local rbe_config=
    patch_engflow_endpoint "${version}"
    ensure_engflow_credential_helper
    ensure_docker_compose_env
    rbe_config="$(resolve_docs_rbe_config)"
    grep -q "${ENGFLOW_HOST}" .bazelrc || die "Envoy ${version} did not resolve to ${ENGFLOW_HOST} in .bazelrc; update the EngFlow endpoint patch."
    [[ -x "${ENGFLOW_HELPER_PATH}" ]] || die "Envoy ${version} is missing an executable ${ENGFLOW_HELPER_PATH} credential helper for EngFlow RBE."
    export ENVOY_RBE=1
    export BAZEL_BUILD_EXTRA_OPTIONS="--config=ci --config=${rbe_config}"
    echo "Docs EngFlow BAZEL_BUILD_EXTRA_OPTIONS: ${BAZEL_BUILD_EXTRA_OPTIONS}"
    echo "Docs EngFlow credential helper present: yes"
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        echo "Docs EngFlow GITHUB_TOKEN configured: yes"
    else
        echo "Docs EngFlow GITHUB_TOKEN configured: no"
        die "GITHUB_TOKEN is empty; Envoy docs build cannot authenticate to EngFlow RBE. Ensure the workflow passes secrets.GITHUB_TOKEN to update-archive.sh."
    fi
}

build_docs () {
    local version="$1"
    cd "${ENVOY_SRC}" || exit 1
    git checkout "${version}"
    patch_engflow_endpoint "${version}"
    sed -i 's/59f14d4fb373083b9dc8d389f16bbb817b5f936d1d436aa67e16eb6936028a51/fc694942e8a7491dcc1dde1bddf48a31370a1f46fef862bc17acf07c34dc6325/g' bazel/repository_locations.bzl
    export DOCS_BUILD_RELEASE=1
    if [[ "$version" =~ ^(1.25|1.24)\..* ]]; then
        ./docs/build.sh
    else
        prepare_docs_rbe "${version}"
        ./ci/run_envoy_docker.sh './ci/do_ci.sh docs'
    fi
    echo "Docs ${version} built ..."
    mv generated/docs/* "${WORKSPACE}/${DOCS_FOLDER}/${version}"
    rm -rf generated
    cd - || exit 1
}

archive_docs () {
    local version="$1"
    echo "Archiving docs: ${version}"
    mkdir -p "${DOCS_FOLDER}/${version}"
    build_docs "${version}"
    if [[ -n "$TEST_ONLY" ]]; then
        return
    fi
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
            if [[ -n "$(git status --porcelain "${DOCS_FOLDER}")" ]]; then
                echo "Unexpected changes" >&2
                git diff "${DOCS_FOLDER}"
                exit 1
            fi
        fi
    fi
done

if [[ -n "$SHOULD_PUSH" ]]; then
    echo "Pushing changes to the archive ..."
    git push origin HEAD:main
else
    echo "Not pushing changes to the archive ..."
    git status
fi
