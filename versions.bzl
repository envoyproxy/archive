
VERSIONS = {
    "python": "3.12",
    "envoy": {
        "type": "github_archive",
        "repo": "envoyproxy/envoy",
        "version": "acf9032e7938de4555c50668ab8df9bf8c456c4f",
        "sha256": "cdebcf7aabb1470699ea64dd2be661836cb1f95f57df3a0d2a54979fcbad844f",
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
