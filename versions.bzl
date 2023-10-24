
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
}
