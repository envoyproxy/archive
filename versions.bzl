
VERSIONS = {
    "python": "3.10",
    "envoy": {
        "type": "github_archive",
        "repo": "envoyproxy/envoy",
        "version": "8cd214daaf858a5e698494a5a667f31978531c18",
        "sha256": "7d17c7aaa675d22abdb1cecb800e7a9a83c61c01d64639a62397570d32db868b",
        "urls": ["https://github.com/{repo}/archive/{version}.tar.gz"],
        "strip_prefix": "envoy-{version}",
    },
}
