"""Publish a built docs tarball for an Envoy version to the archive bucket.

The archive bucket is immutable - objects are uploaded with `--no-clobber` and
verified against the tarball. Once a version has landed the manifest in the
meta bucket is regenerated from a bucket listing.
"""

import argparse
import pathlib
import subprocess
import sys
import tarfile
import tempfile

import gcs
import manifest

ARCHIVE_CACHE_CONTROL = "public, max-age=31536000, immutable"
MANIFEST_CACHE_CONTROL = "public, max-age=300"


def parse_args(args) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--archive-bucket",
        required=True,
        help="GCS bucket to publish the docs to")
    parser.add_argument(
        "--meta-bucket",
        required=True,
        help="GCS bucket to publish the manifest (`versions.json`) to")
    parser.add_argument(
        "--version",
        required=True,
        help="Version being published (eg `v1.39.1`)")
    parser.add_argument(
        "--tarball",
        required=True,
        help="Tarball of the built docs, rooted at the docs tree")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report what would be published without uploading anything")
    return parser.parse_args(args)


def extract(tarball: str, path: str) -> int:
    """Extract the docs tarball, returning the number of files."""
    with tarfile.open(tarball) as tar:
        tar.extractall(path, filter="data")
    return len([p for p in pathlib.Path(path).rglob("*") if p.is_file()])


def upload(path: str, bucket: str, version: str) -> None:
    subprocess.run(
        ["gcloud", "storage", "rsync", "-r", "--no-clobber",
         f"--cache-control={ARCHIVE_CACHE_CONTROL}",
         path,
         f"{gcs.archive_url(bucket)}/{version}"],
        check=True)


def upload_manifest(content: str, bucket: str) -> None:
    with tempfile.TemporaryDirectory() as tmpdir:
        path = pathlib.Path(tmpdir).joinpath("versions.json")
        path.write_text(content)
        subprocess.run(
            ["gcloud", "storage", "cp",
             f"--cache-control={MANIFEST_CACHE_CONTROL}",
             str(path),
             gcs.manifest_url(bucket)],
            check=True)


def update_manifest(gcs_client, archive_bucket: str, meta_bucket: str) -> bool:
    """Regenerate the manifest from the archive bucket, if it changed."""
    existing = gcs.fetch_manifest(gcs_client, meta_bucket)
    have = gcs.published_versions(gcs_client, archive_bucket)
    updated = manifest.build_manifest(
        existing,
        have,
        lambda version: manifest.version_meta(
            version,
            gcs.version_objects(gcs_client, archive_bucket, version)),
        archive=gcs.archive_url(archive_bucket))
    if not manifest.manifest_changed(existing, updated):
        print("Manifest is up to date, not updating")
        return False
    upload_manifest(manifest.dumps(updated), meta_bucket)
    print(f"Manifest updated: {gcs.manifest_url(meta_bucket)}")
    return True


def main(*args) -> int:
    parsed = parse_args(args)
    version = parsed.version
    with tempfile.TemporaryDirectory() as tmpdir:
        files = extract(parsed.tarball, tmpdir)
        print(f"Publishing {version} ({files} files)")
        if parsed.dry_run:
            print(
                f"Dry run, not uploading to "
                f"{gcs.archive_url(parsed.archive_bucket)}/{version}")
            return 0
        upload(tmpdir, parsed.archive_bucket, version)
    gcs_client = gcs.client()
    published = len(
        gcs.version_objects(gcs_client, parsed.archive_bucket, version))
    if published != files:
        print(
            f"ERROR: {version} published {published} objects, expected "
            f"{files}",
            file=sys.stderr)
        return 1
    print(f"Published {version} ({published} objects)")
    update_manifest(gcs_client, parsed.archive_bucket, parsed.meta_bucket)
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
