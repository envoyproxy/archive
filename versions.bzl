
VERSIONS = {
    "python": "3.12",
    "envoy": {
        "type": "github_archive",
        "repo": "envoyproxy/envoy",
        "version": "b461f159615c0a0a46d2e79aeb76418255dc880e",
        "sha256": "b2f8ff94fcea17adc988f2775f1f814d976a7fcb246f408a12573eeeaa286c83",
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
