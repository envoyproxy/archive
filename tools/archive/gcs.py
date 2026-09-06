"""Shared GCS access for the archive tooling.

Only prefix/object listing is done with the Python client - the bucket is
otherwise written with `gcloud storage`, which is present on the runner and
already used for the archive uploads.
"""

import json
from typing import Iterable

from google.cloud import storage

DOCS_PREFIX = "envoy/docs"
MANIFEST_PATH = f"{DOCS_PREFIX}/versions.json"


def client() -> storage.Client:
    return storage.Client()


def archive_url(bucket: str) -> str:
    return f"gs://{bucket}/{DOCS_PREFIX}"


def manifest_url(bucket: str) -> str:
    return f"gs://{bucket}/{MANIFEST_PATH}"


def published_versions(gcs: storage.Client, bucket: str) -> list:
    """Versions published in the archive bucket (prefix listing only)."""
    prefixes = set()
    pages = gcs.list_blobs(
        bucket,
        prefix=f"{DOCS_PREFIX}/",
        delimiter="/").pages
    for page in pages:
        prefixes |= set(page.prefixes)
    return [
        prefix[len(f"{DOCS_PREFIX}/"):].rstrip("/")
        for prefix
        in sorted(prefixes)
        if prefix.rstrip("/").rsplit("/", 1)[-1].startswith("v")]


def version_objects(gcs: storage.Client, bucket: str, version: str) -> Iterable:
    """`(path, md5)` for every object published for a version.

    Paths are relative to the version prefix, and the md5 is the one recorded
    in the object listing - nothing is downloaded.
    """
    prefix = f"{DOCS_PREFIX}/{version}/"
    return [
        (blob.name[len(prefix):], blob.md5_hash)
        for blob
        in gcs.list_blobs(bucket, prefix=prefix)]


def fetch_manifest(gcs: storage.Client, bucket: str) -> dict | None:
    """Current manifest from the meta bucket, if any."""
    blob = gcs.bucket(bucket).get_blob(MANIFEST_PATH)
    if blob is None:
        return None
    return json.loads(blob.download_as_bytes())
