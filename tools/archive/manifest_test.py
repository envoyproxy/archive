import json
import unittest

import manifest


def _meta(version):
    return dict(
        minor=manifest.minor_version(version),
        digest="sha256:new",
        objects=1,
        published="2026-09-06T12:00:00Z")


class ManifestTest(unittest.TestCase):

    def test_sort_versions(self):
        self.assertEqual(
            manifest.sort_versions(["v1.9.0", "v1.10.0", "v1.10.1"]),
            ["v1.10.1", "v1.10.0", "v1.9.0"])

    def test_minor_version(self):
        self.assertEqual(manifest.minor_version("v1.39.1"), "1.39")

    def test_group_minors(self):
        self.assertEqual(
            manifest.group_minors(["v1.38.0", "v1.39.0", "v1.39.1"]),
            {"1.39": ["v1.39.1", "v1.39.0"],
             "1.38": ["v1.38.0"]})

    def test_classify_versions(self):
        versions = [f"v1.{minor}.0" for minor in range(30, 40)]
        classification = manifest.classify_versions(versions)
        self.assertEqual(classification["latest"], "v1.39.0")
        self.assertEqual(
            list(classification["stable"]),
            ["1.39", "1.38", "1.37", "1.36"])
        self.assertEqual(list(classification["archived"])[0], "1.35")
        self.assertEqual(len(classification["archived"]), 6)

    def test_classify_versions_empty(self):
        self.assertEqual(
            manifest.classify_versions([]),
            dict(latest=None, stable={}, archived={}))

    def test_digest_objects_is_order_independent(self):
        objects = [("index.html", "aaa"), ("api/index.html", "bbb")]
        self.assertEqual(
            manifest.digest_objects(objects),
            manifest.digest_objects(reversed(objects)))
        self.assertTrue(manifest.digest_objects(objects).startswith("sha256:"))
        self.assertNotEqual(
            manifest.digest_objects(objects),
            manifest.digest_objects([("index.html", "aaa")]))

    def test_version_meta(self):
        objects = [("index.html", "aaa"), ("api/index.html", "bbb")]
        meta = manifest.version_meta(
            "v1.39.1", objects, published="2026-09-06T12:00:00Z")
        self.assertEqual(meta["minor"], "1.39")
        self.assertEqual(meta["objects"], 2)
        self.assertEqual(meta["published"], "2026-09-06T12:00:00Z")
        self.assertEqual(meta["digest"], manifest.digest_objects(objects))

    def test_build_manifest_adds_missing(self):
        result = manifest.build_manifest(
            None,
            ["v1.39.0", "v1.39.1"],
            _meta,
            archive="gs://bucket/envoy/docs",
            generated="2026-09-06T12:00:00Z")
        self.assertEqual(result["archive"], "gs://bucket/envoy/docs")
        self.assertEqual(result["generated"], "2026-09-06T12:00:00Z")
        self.assertEqual(list(result["versions"]), ["v1.39.1", "v1.39.0"])
        self.assertEqual(result["classification"]["latest"], "v1.39.1")

    def test_build_manifest_carries_existing_forward(self):
        existing = dict(
            generated="2020-01-01T00:00:00Z",
            archive="gs://bucket/envoy/docs",
            versions={
                "v1.39.0": dict(
                    minor="1.39",
                    digest="sha256:old",
                    objects=23,
                    published="2020-01-01T00:00:00Z",
                    extra="preserved")})
        result = manifest.build_manifest(
            existing,
            ["v1.39.0", "v1.39.1"],
            _meta,
            archive="gs://bucket/envoy/docs")
        self.assertEqual(
            result["versions"]["v1.39.0"],
            existing["versions"]["v1.39.0"])
        self.assertEqual(
            result["versions"]["v1.39.1"]["digest"], "sha256:new")

    def test_build_manifest_drops_unpublished(self):
        existing = dict(versions={"v1.39.0": dict(digest="sha256:old")})
        result = manifest.build_manifest(
            existing,
            ["v1.39.1"],
            _meta,
            archive="gs://bucket/envoy/docs")
        self.assertEqual(list(result["versions"]), ["v1.39.1"])

    def test_dumps_is_stable(self):
        result = manifest.build_manifest(
            None,
            ["v1.39.1", "v1.39.0"],
            _meta,
            archive="gs://bucket/envoy/docs",
            generated="2026-09-06T12:00:00Z")
        dumped = manifest.dumps(result)
        self.assertEqual(dumped, manifest.dumps(json.loads(dumped)))
        self.assertTrue(dumped.endswith("}\n"))
        self.assertTrue(dumped.splitlines()[1].startswith("  "))

    def test_manifest_changed(self):
        existing = manifest.build_manifest(
            None,
            ["v1.39.1"],
            _meta,
            archive="gs://bucket/envoy/docs",
            generated="2026-09-06T12:00:00Z")
        same = manifest.build_manifest(
            existing,
            ["v1.39.1"],
            _meta,
            archive="gs://bucket/envoy/docs",
            generated="2026-09-07T12:00:00Z")
        self.assertFalse(manifest.manifest_changed(existing, same))
        self.assertTrue(manifest.manifest_changed(None, same))
        updated = manifest.build_manifest(
            existing,
            ["v1.39.1", "v1.40.0"],
            _meta,
            archive="gs://bucket/envoy/docs")
        self.assertTrue(manifest.manifest_changed(existing, updated))


if __name__ == "__main__":
    unittest.main()
