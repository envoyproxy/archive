
VERSIONS = {
    "python": "3.12",
    "envoy": {
        "type": "github_archive",
        "repo": "envoyproxy/envoy",
        "version": "287f07ace81cbf6857ae08ed2740d8b3552395e7",
        "sha256": "b4912b588105a13fe274223a178ab3e20435cfadc21105eb1631346958998e31",
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
