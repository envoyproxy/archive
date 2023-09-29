load("@base_pip3//:requirements.bzl", "requirement")

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
