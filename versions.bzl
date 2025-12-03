
VERSIONS = {
    "python": "3.12",
    "envoy": {
        "type": "github_archive",
        "repo": "envoyproxy/envoy",
        "version": "4809c587a60425e62d298efc174e94cac7dfadc3",
        "sha256": "e1c8aae28056e5fd73a2603597d63acc52a4aa702fc7cb3e6f59bfd36ef446bd",
        "urls": ["https://github.com/{repo}/archive/{version}.tar.gz"],
        "strip_prefix": "envoy-{version}",
    },
    "rules_python": {
        "type": "github_archive",
        "repo": "bazel-contrib/rules_python",
        "version": "1.7.0",
        "sha256": "f609f341d6e9090b981b3f45324d05a819fd7a5a56434f849c761971ce2c47da",
        "urls": ["https://github.com/{repo}/releases/download/{version}/rules_python-{version}.tar.gz"],
        "strip_prefix": "rules_python-1.7.0",
    },
}
