"""Reconcile the Envoy docs archive bucket with the releases that should be archived.

This is read-only - it computes what is published (`have`), what should be
published (`want`), and writes the resulting plan for the publish step.
"""

import argparse
import json
import pathlib
import sys

import gcs
import manifest


def parse_args(args) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--archive-bucket",
        required=True,
        help="GCS bucket containing the published docs")
    parser.add_argument(
        "--meta-bucket",
        help="GCS bucket containing the docs manifest (`versions.json`)")
    parser.add_argument(
        "--project-json",
        required=True,
        help="Path to the Envoy project data (`@envoy_repo//:project`)")
    parser.add_argument(
        "--output",
        help="Path to write the plan JSON to")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Only report the plan")
    return parser.parse_args(args)


def wanted_versions(project: dict) -> tuple:
    """Releases that should be archived, and those that should not.

    This is the derivation that `update-archive.sh` used - a release is
    archived if its minor version is one of the Envoy stable versions.
    """
    stable = set(project["stable_versions"])
    want = []
    excluded = []
    for release in project["releases"]:
        version = release if release.startswith("v") else f"v{release}"
        if manifest.minor_version(version) in stable:
            want.append(version)
        else:
            excluded.append(version)
    return manifest.sort_versions(want), manifest.sort_versions(excluded)


def main(*args) -> int:
    parsed = parse_args(args)
    project = json.loads(pathlib.Path(parsed.project_json).read_text())
    want, excluded = wanted_versions(project)
    gcs_client = gcs.client()
    have = manifest.sort_versions(
        gcs.published_versions(gcs_client, parsed.archive_bucket))
    missing = manifest.sort_versions(set(want) - set(have))

    print(f"archive: {gcs.archive_url(parsed.archive_bucket)}")
    print(f"have: {len(have)}")
    print(f"want: {len(want)}")
    print(f"missing ({len(missing)}): {' '.join(missing) or '-'}")
    print(f"excluded ({len(excluded)}): {' '.join(excluded) or '-'}")

    if parsed.meta_bucket:
        existing = gcs.fetch_manifest(gcs_client, parsed.meta_bucket)
        recorded = set((existing or {}).get("versions") or {})
        print(f"manifest: {gcs.manifest_url(parsed.meta_bucket)}")
        print(f"manifest versions: {len(recorded)}")
        unrecorded = manifest.sort_versions(set(have) - recorded)
        if unrecorded:
            print(
                "manifest is out of date, missing "
                f"({len(unrecorded)}): {' '.join(unrecorded)}")

    if parsed.output:
        pathlib.Path(parsed.output).write_text(
            manifest.dumps(dict(missing=missing, have=have)))
        print(f"plan written: {parsed.output}")

    if parsed.dry_run:
        print("Dry run, nothing to do")
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
