
VERSIONS = {
    "python": "3.10",
    "envoy": {
        "type": "github_archive",
        "repo": "envoyproxy/envoy",
        "version": "c811a885ef4d02aaa1cce02dde62f0ff6a1b0c38",
        "sha256": "846281edbf600a473d6379c28a882ec71bfc3a6ca9cafae038eeab19f5a30189",
        "urls": ["https://github.com/{repo}/archive/{version}.tar.gz"],
        "strip_prefix": "envoy-{version}",
    },
}
