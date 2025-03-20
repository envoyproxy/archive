
VERSIONS = {
    "python": "3.12",
    "envoy": {
        "type": "github_archive",
        "repo": "envoyproxy/envoy",
        "version": "0b930118d82724d49e15b6a6104bd436a9eabba1",
        "sha256": "b8506fb2760d9e23830751e01d15517d035c854deee7efd8c4aafb2bc32541ee",
        "urls": ["https://github.com/{repo}/archive/{version}.tar.gz"],
        "strip_prefix": "envoy-{version}",
    },
    "rules_python": {
        "type": "github_archive",
        "repo": "bazel-contrib/rules_python",
        "version": "1.0.0",
        "sha256": "4f7e2aa1eb9aa722d96498f5ef514f426c1f55161c3c9ae628c857a7128ceb07",
        "urls": ["https://github.com/{repo}/releases/download/{version}/rules_python-{version}.tar.gz"],
        "strip_prefix": "rules_python-1.0.0",
    },
}
