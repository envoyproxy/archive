workspace(name = "envoy_archive")

load(":archive.bzl", "load_archives")
load_archives()

load("@envoy//bazel:api_binding.bzl", "envoy_api_binding")

envoy_api_binding()

load("@envoy//bazel:api_repositories.bzl", "envoy_api_dependencies")

envoy_api_dependencies()

load("@envoy//bazel:repositories.bzl", "envoy_dependencies")

envoy_dependencies()

load("@envoy//bazel:repositories_extra.bzl", "envoy_dependencies_extra")

envoy_dependencies_extra()

load("@envoy//bazel:python_dependencies.bzl", "envoy_python_dependencies")

envoy_python_dependencies()

load("@envoy//bazel:dependency_imports.bzl", "envoy_dependency_imports")

envoy_dependency_imports()

load(":toolchains.bzl", "load_toolchains")
load_toolchains()

load(":packages.bzl", "load_packages")
load_packages()

load("@website_pip3//:requirements.bzl", "install_deps")
install_deps()
