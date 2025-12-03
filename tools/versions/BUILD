load("@base_pip3//:requirements.bzl", "requirement")
load("@python3_12//:defs.bzl", "py_binary")

py_binary(
    name = "release_versions",
    srcs = ["release_versions.py"],
    data = [
        "@envoy_archive//docs:releases_inventories",
    ],
    deps = [
        requirement("packaging"),
        requirement("pyyaml"),
    ],
    args = ["$(locations @envoy_archive//docs:releases_inventories)"],
    visibility = ["//visibility:public"],
)
