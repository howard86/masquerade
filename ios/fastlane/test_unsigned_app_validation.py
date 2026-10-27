#!/usr/bin/env python3

import importlib.util
import subprocess
import unittest
from pathlib import Path
from unittest.mock import patch


VALIDATOR_PATH = Path(__file__).with_name("validate_unsigned_app.py")
SPEC = importlib.util.spec_from_file_location("unsigned_app_validator", VALIDATOR_PATH)
validator = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(validator)


class MachOBuildValidationTest(unittest.TestCase):
    def test_vtool_requires_device_platform_and_accepts_ios_13(self):
        builds = validator.parse_vtool_builds(
            """Load command 0
cmd LC_BUILD_VERSION
platform IOS
minos 13.0
sdk 26.5
""",
            "arm64",
        )
        validator.validate_macho_builds(Path("Runner"), builds)
        self.assertEqual(builds[0]["minimum_ios"], "13.0")

    def test_simulator_slice_is_rejected(self):
        builds = validator.parse_vtool_builds(
            "platform IOSSIMULATOR\nminos 13.0\n", "arm64"
        )
        with self.assertRaisesRegex(ValueError, "not an iOS device"):
            validator.validate_macho_builds(Path("Runner"), builds)

    def test_every_architecture_is_checked(self):
        def fake_run(args, **_kwargs):
            if args[1:3] == ["lipo", "-archs"]:
                return subprocess.CompletedProcess(args, 0, stdout="arm64 arm64e", stderr="")
            if args[1] == "vtool":
                arch = args[3]
                minimum = "13.0" if arch == "arm64" else "15.0"
                output = f"platform IOS\nminos {minimum}\n"
                return subprocess.CompletedProcess(args, 0, stdout=output, stderr="")
            self.fail(f"unexpected tool command: {args}")

        with patch.object(validator.subprocess, "run", side_effect=fake_run):
            builds = validator.macho_deployment_targets(Path("Runner"))
        self.assertEqual([build["architecture"] for build in builds], ["arm64", "arm64e"])
        with self.assertRaisesRegex(ValueError, "requires iOS 15.0"):
            validator.validate_macho_builds(Path("Runner"), builds)

    def test_legacy_otool_fallback_checks_every_load_command(self):
        output = """Load command 0
cmd LC_VERSION_MIN_IPHONEOS
version 13.0
sdk 26.5
Load command 1
cmd LC_VERSION_MIN_IPHONEOS
version 15.0
sdk 26.5
"""
        builds = validator.parse_otool_builds(output, "arm64")
        self.assertEqual([build["minimum_ios"] for build in builds], ["13.0", "15.0"])
        with self.assertRaisesRegex(ValueError, "requires iOS 15.0"):
            validator.validate_macho_builds(Path("Runner"), builds)

    def test_missing_platform_or_minimum_does_not_pass(self):
        with self.assertRaisesRegex(ValueError, "without a minimum OS"):
            validator.parse_vtool_builds("platform IOS\n", "arm64")
        with self.assertRaisesRegex(ValueError, "no deployment records"):
            validator.validate_macho_builds(Path("Runner"), [])
        self.assertEqual(
            validator.parse_otool_builds("Load command 0\ncmd LC_SEGMENT_64\n", "arm64"),
            [],
        )

        def fake_run(args, **_kwargs):
            if args[1:3] == ["lipo", "-archs"]:
                return subprocess.CompletedProcess(args, 0, stdout="arm64", stderr="")
            if args[1] == "vtool":
                return subprocess.CompletedProcess(args, 0, stdout="", stderr="")
            if args[1] == "otool":
                output = "Load command 0\ncmd LC_SEGMENT_64\n"
                return subprocess.CompletedProcess(args, 0, stdout=output, stderr="")
            self.fail(f"unexpected tool command: {args}")

        with patch.object(validator.subprocess, "run", side_effect=fake_run):
            with self.assertRaisesRegex(ValueError, "could not read platform and minimum OS"):
                validator.macho_deployment_targets(Path("Runner"))


if __name__ == "__main__":
    unittest.main()
