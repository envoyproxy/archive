
VERSIONS = {
    "python": "3.10",
    "envoy": {
        "type": "github_archive",
        "repo": "envoyproxy/envoy",
        "version": "cccdd4b2611f4804bd21eee944fdcbe0e1f91b2f",
        "sha256": "280deb5a3e408cbf1a3e29d79eedf6007e0813d1f410478f1c8c6663a93e6de6",
        "urls": ["https://github.com/{repo}/archive/{version}.tar.gz"],
        "strip_prefix": "envoy-{version}",
    },
    "envoy_toolshed": {
        "type": "github_archive",
        "repo": "envoyproxy/toolshed",
        "version": "0.1.1",
        "sha256": "ee759b57270a2747f3f2a3d6ecaad63b834dd9887505a9f1c919d72429dbeffd",
        "urls": ["https://github.com/{repo}/archive/bazel-v{version}.tar.gz"],
        "strip_prefix": "toolshed-bazel-v{version}/bazel",
    },
}
