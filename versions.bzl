
VERSIONS = {
    "python": "3.12",
    "envoy": {
        "type": "github_archive",
        "repo": "envoyproxy/envoy",
        "version": "e026e46fcfefc0599307c8329d1c1cdff9658341",
        "sha256": "9ef2e96f1bbdf885e8e9312b2b4021fea82d7fab405a47816a046bc8b1a9b0b7",
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
