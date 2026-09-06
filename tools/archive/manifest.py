"""Pure functions for the archive manifest (`versions.json`).

The archive bucket is the source of truth for what is published. The manifest
is derived data - an index into the bucket - and can be regenerated from a
bucket listing at any time.

Existing entries are always carried forward untouched. An entry is only ever
added for a version that is published but not yet recorded, and only ever
removed if the version has disappeared from the bucket (which should not
happen, and is logged loudly if it does).
"""

import datetime
import hashlib
import json
from typing import Callable, Iterable

from packaging import version as _version

# Number of most recent minor versions that are considered stable.
STABLE_MINORS = 4


def parse_version(v: str) -> _version.Version:
    """Parse a `vX.Y.Z` archive version string."""
    return _version.Version(v.lstrip("v"))


def sort_versions(versions: Iterable[str]) -> list:
    """Versions sorted semantically, newest first."""
    return sorted(versions, key=parse_version, reverse=True)


def minor_version(v: str) -> str:
    """Minor version (`1.39`) for an archive version (`v1.39.1`)."""
    parsed = parse_version(v)
    return f"{parsed.major}.{parsed.minor}"


def group_minors(versions: Iterable[str]) -> dict:
    """Versions grouped by minor version, both sorted newest first."""
    minors: dict = {}
    for v in sort_versions(versions):
        minors.setdefault(minor_version(v), []).append(v)
    return {
        minor: minors[minor]
        for minor
        in sorted(minors, key=_version.Version, reverse=True)}


def classify_versions(versions: Iterable[str]) -> dict:
    """Classification of published versions.

    This mirrors the grouping done by `tools/versions/release_versions.py` -
    the most recent `STABLE_MINORS` minor versions are considered stable, and
    anything older is archived - so that the website can consume the manifest
    rather than a directory glob.
    """
    minors = group_minors(versions)
    stable = list(minors)[:STABLE_MINORS]
    return dict(
        latest=(minors[stable[0]][0] if minors else None),
        stable={minor: minors[minor] for minor in stable},
        archived={
            minor: releases
            for minor, releases
            in minors.items()
            if minor not in stable})


def digest_objects(objects: Iterable) -> str:
    """Digest for the objects published under a version prefix.

    The digest is the `sha256` of the sorted `"<path> <md5>"` lines for every
    object under the prefix, where `<path>` is relative to the version prefix
    and `<md5>` is the (base64) `md5Hash` from the GCS object listing. It
    therefore requires no downloads, and can be recomputed by anyone with read
    access to the bucket.
    """
    lines = sorted(f"{path} {md5}\n" for path, md5 in objects)
    return f"sha256:{hashlib.sha256(''.join(lines).encode('utf-8')).hexdigest()}"


def utcnow() -> str:
    """Current time as an RFC3339 timestamp."""
    return datetime.datetime.now(
        datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def build_manifest(
        existing: dict | None,
        have: Iterable[str],
        per_version_meta: Callable[[str], dict],
        archive: str | None = None,
        generated: str | None = None) -> dict:
    """Manifest for the versions published in the archive bucket.

    `existing` is the current manifest (or `None`), `have` the versions found
    in the bucket, and `per_version_meta` a callable resolving the metadata for
    a version that is not already recorded.
    """
    existing = existing or {}
    existing_versions = existing.get("versions") or {}
    have = list(have)
    versions = {}
    for v in sort_versions(have):
        if v in existing_versions:
            # Published versions are immutable - carry the recorded entry
            # forward without recomputing it.
            versions[v] = existing_versions[v]
            continue
        versions[v] = per_version_meta(v)
    for v in existing_versions:
        if v not in versions:
            print(
                f"WARNING: {v} is recorded in the manifest but is not present "
                "in the archive bucket, dropping the entry. This should not "
                "happen and may indicate bucket tampering.")
    return dict(
        generated=generated or utcnow(),
        archive=archive or existing.get("archive"),
        versions=versions,
        classification=classify_versions(versions))


def version_meta(
        v: str,
        objects: Iterable,
        published: str | None = None) -> dict:
    """Manifest entry for a version, derived from its object listing."""
    objects = list(objects)
    return dict(
        minor=minor_version(v),
        digest=digest_objects(objects),
        objects=len(objects),
        published=published or utcnow())


def dumps(manifest: dict) -> str:
    """Stable JSON serialization - identical content produces identical bytes.

    Version keys are ordered by semver, newest first, when the manifest is
    built, and that order is preserved here.
    """
    return f"{json.dumps(manifest, indent=2)}\n"


def manifest_changed(existing: dict | None, manifest: dict) -> bool:
    """Whether the manifest content changed, ignoring the generated stamp."""
    if not existing:
        return True
    return (
        {k: v for k, v in existing.items() if k != "generated"}
        != {k: v for k, v in manifest.items() if k != "generated"})
