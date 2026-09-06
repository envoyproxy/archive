load("@archive_pip3//:requirements.bzl", "requirement")
load("@rules_python//python:defs.bzl", "py_binary", "py_library", "py_test")
load("@base_pip3//:requirements.bzl", base_requirement = "requirement")

exports_files([
    "requirements.txt",
])

py_library(
    name = "manifest",
    srcs = ["manifest.py"],
    imports = ["."],
    deps = [base_requirement("packaging")],
    visibility = ["//visibility:public"],
)

py_library(
    name = "gcs",
    srcs = ["gcs.py"],
    imports = ["."],
    deps = [requirement("google-cloud-storage")],
)

py_test(
    name = "manifest_test",
    srcs = ["manifest_test.py"],
    deps = [":manifest"],
)

py_binary(
    name = "reconcile",
    srcs = ["reconcile.py"],
    args = ["--project-json=$(location @envoy_repo//:project)"],
    data = ["@envoy_repo//:project"],
    deps = [
        ":gcs",
        ":manifest",
    ],
    visibility = ["//visibility:public"],
)

py_binary(
    name = "publish",
    srcs = ["publish.py"],
    deps = [
        ":gcs",
        ":manifest",
    ],
    visibility = ["//visibility:public"],
)
