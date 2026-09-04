load("@base_pip3//:requirements.bzl", "requirement")
load("@rules_python//python:defs.bzl", "py_binary")

py_binary(
    name = "release_versions",
    srcs = ["release_versions.py"],
    data = [
        "//docs:releases_inventories",
    ],
    deps = [
        requirement("packaging"),
        requirement("pyyaml"),
    ],
    args = ["$(locations //docs:releases_inventories)"],
    visibility = ["//visibility:public"],
)
