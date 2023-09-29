load("@rules_pkg//pkg:mappings.bzl", "pkg_filegroup", "pkg_files")

filegroup(
    name = "releases_html",
    srcs = glob([
        "envoy/v*/*",
        "envoy/v*/**/*",
    ]),
    visibility = ["//visibility:public"],
)

filegroup(
    name = "releases_inventories",
    srcs = glob(["envoy/v*/objects.inv"]),
    visibility = ["//visibility:public"],
)

pkg_files(
    name = "releases_files",
    srcs = [":releases_html"],
    prefix = "docs",
    strip_prefix = "",
)

pkg_filegroup(
    name = "releases",
    srcs = [":releases_files"],
    visibility = ["//visibility:public"],
)

alias(
    name = "docs",
    actual = ":releases",
    visibility = ["//visibility:public"],
)
