load("@envoy_toolshed//:macros.bzl", "json_data")
load("//:versions.bzl", "VERSIONS")
load("@aspect_bazel_lib//lib:jq.bzl", "jq")

exports_files([
    "versions.bzl",
])

json_data(
    name = "deps",
    data = VERSIONS,
)

jq(
    name = "dependency_versions",
    srcs = [":deps"],
    out = "dependency_shas.json",
    filter = """
    with_entries(select(.value | objects and .type == "github_archive") | .value |= {repo, sha256, url, version})
    """,
    visibility = ["//visibility:public"],
)

genrule(
    name = "versions",
    cmd = """
    $(location //tools/versions:release_versions) \
        $(locations //docs:releases_inventories) "" \
        > $@
    """,
    outs = ["versions.yaml"],
    tools = [
        "//tools/versions:release_versions",
        "//docs:releases_inventories",
    ],
    visibility = ["//visibility:public"],
)
