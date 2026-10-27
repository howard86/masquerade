#!/usr/bin/env python3
"""Decision-logic tests with mocked macOS signing tools; not signing verification."""
from __future__ import annotations

import datetime as dt
import importlib.util
import plistlib
import shutil
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

VALIDATOR_PATH = Path(__file__).with_name("validate_signed_ipa.py")
SPEC = importlib.util.spec_from_file_location("signed_ipa_validator", VALIDATOR_PATH)
validator = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(validator)


APP_ID = "dev.howardism.Masquerade"
EXTENSION_ID = f"{APP_ID}.ShareExtension"
TEAM_ID = "9KRJ83FMAF"
APP_GROUP = "group.dev.howardism.Masquerade"
VERSION = "1.29.0"
BUILD = "17"
NOW = dt.datetime(2026, 10, 27, tzinfo=dt.timezone.utc)
MACH_O_MAGIC = b"\xcf\xfa\xed\xfe"


class SignedIpaValidationTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.payload = self.root / "fixture" / "Payload"
        self.app = self.payload / "Runner.app"
        self.extension = self.app / "PlugIns" / "ShareExtension.appex"
        self.ipa = self.root / "Masquerade.ipa"
        self.signing_team = TEAM_ID
        self.signing_identifier = None
        self.signature_verify_fails = False
        self.malformed_app_profile = False
        self.human_readable_entitlements = False
        self.omit_signature_leaf_certificate = False
        self.cms_verification_fails = False
        self.apple_roots_missing = False
        self.app_certificate = b"mock app signing certificate DER"
        self.extension_certificate = b"mock extension signing certificate DER"
        self.app_profile = self.profile(APP_ID)
        self.extension_profile = self.profile(EXTENSION_ID)
        self.signed_app_entitlements = dict(self.app_profile["Entitlements"])
        self.signed_extension_entitlements = dict(self.extension_profile["Entitlements"])
        self.make_bundle(self.app, APP_ID, VERSION, BUILD, executable="Runner")
        self.make_bundle(
            self.extension,
            EXTENSION_ID,
            VERSION,
            BUILD,
            executable="ShareExtension",
        )
        self.write_ipa()

    def tearDown(self):
        self.temp.cleanup()

    def profile(self, bundle_id):
        return {
            "ApplicationIdentifierPrefix": [TEAM_ID],
            "ExpirationDate": NOW.replace(tzinfo=None) + dt.timedelta(days=30),
            "Name": f"Masquerade {bundle_id}",
            "UUID": f"PROFILE-{bundle_id}",
            "ProvisionsAllDevices": False,
            "DeveloperCertificates": [
                self.extension_certificate if bundle_id == EXTENSION_ID else self.app_certificate
            ],
            "Entitlements": {
                "application-identifier": f"{TEAM_ID}.{bundle_id}",
                "com.apple.developer.team-identifier": TEAM_ID,
                "com.apple.security.application-groups": [APP_GROUP],
                "get-task-allow": False,
            },
        }

    def make_bundle(self, bundle, bundle_id, version, build, *, executable):
        bundle.mkdir(parents=True, exist_ok=True)
        info = {
            "CFBundleIdentifier": bundle_id,
            "CFBundleShortVersionString": version,
            "CFBundleVersion": build,
            "MinimumOSVersion": "13.0",
            "UIDeviceFamily": [1],
            "CFBundleExecutable": executable,
        }
        (bundle / "Info.plist").write_bytes(plistlib.dumps(info))
        privacy = plistlib.loads(
            (Path(__file__).parents[1] / "Shared" / "PrivacyInfo.xcprivacy").read_bytes()
        )
        (bundle / "PrivacyInfo.xcprivacy").write_bytes(plistlib.dumps(privacy))
        (bundle / executable).write_bytes(MACH_O_MAGIC + b"mock executable")
        (bundle / "embedded.mobileprovision").write_bytes(b"mock CMS profile")

    def write_ipa(self, *, include_extension=True, corrupt=False):
        if corrupt:
            self.ipa.write_bytes(b"not a zip file")
            return
        with zipfile.ZipFile(self.ipa, "w", zipfile.ZIP_DEFLATED) as archive:
            for path in self.payload.rglob("*"):
                if not path.is_file():
                    continue
                if not include_extension and self.extension in path.parents:
                    continue
                archive.write(path, path.relative_to(self.payload.parent).as_posix())
        self.built_after = self.ipa.stat().st_mtime - 1

    def fake_run(self, args, *, check, capture_output, text):
        self.assertFalse(check)
        self.assertTrue(capture_output)
        if args[0] == "ditto":
            destination = Path(args[-1])
            destination.mkdir(parents=True, exist_ok=True)
            shutil.copytree(self.payload, destination / "Payload")
            return subprocess.CompletedProcess(args, 0, "" if text else b"", "" if text else b"")
        if args[0] == "security" and args[1:2] == ["find-certificate"]:
            self.assertIn("Apple Root CA", args)
            roots = "" if self.apple_roots_missing else (
                "-----BEGIN CERTIFICATE-----\nmock Apple root\n"
                "-----END CERTIFICATE-----\n"
            )
            return subprocess.CompletedProcess(args, 0, roots, "")
        if args[0] == "openssl" and args[1:3] == ["cms", "-verify"]:
            self.assertIn("-CAfile", args)
            self.assertNotIn("-noverify", args)
            if self.cms_verification_fails:
                return subprocess.CompletedProcess(args, 1, "", "CMS signature invalid")
            profile_path = args[args.index("-in") + 1]
            decoded_path = Path(args[args.index("-out") + 1])
            if self.malformed_app_profile and "ShareExtension.appex" not in profile_path:
                decoded_path.write_bytes(b"not a profile plist")
                return subprocess.CompletedProcess(args, 0, "", "")
            profile = (
                self.extension_profile
                if "ShareExtension.appex" in profile_path
                else self.app_profile
            )
            decoded_path.write_bytes(plistlib.dumps(profile))
            return subprocess.CompletedProcess(args, 0, "", "")
        if args[0] == "codesign" and "--verify" in args:
            code = 1 if self.signature_verify_fails else 0
            return subprocess.CompletedProcess(args, code, "", "signature invalid" if code else "")
        if args[0] == "codesign" and "-dv" in args:
            identifier = (
                EXTENSION_ID
                if "ShareExtension.appex" in args[-1]
                else APP_ID
            )
            if self.signing_identifier is not None:
                identifier = self.signing_identifier
            details = (
                "Authority=Apple Distribution: Masquerade (9KRJ83FMAF)\n"
                f"Identifier={identifier}\n"
                f"TeamIdentifier={self.signing_team}\n"
            )
            return subprocess.CompletedProcess(args, 0, "", details)
        if args[0] == "codesign" and any(
            arg.startswith("--extract-certificates=") for arg in args
        ):
            if self.omit_signature_leaf_certificate:
                return subprocess.CompletedProcess(args, 0, "", "")
            prefix = next(
                arg.split("=", 1)[1]
                for arg in args
                if arg.startswith("--extract-certificates=")
            )
            certificate = (
                self.extension_certificate
                if "ShareExtension.appex" in args[-1]
                else self.app_certificate
            )
            Path(f"{prefix}0").write_bytes(certificate)
            return subprocess.CompletedProcess(args, 0, "", "")
        if args[0] == "codesign" and "--entitlements" in args:
            self.assertIn("--xml", args)
            entitlement_index = args.index("--entitlements")
            self.assertEqual(args[entitlement_index + 1], "-")
            if self.human_readable_entitlements:
                return subprocess.CompletedProcess(
                    args,
                    0,
                    "application-identifier: human-readable output\n",
                    "",
                )
            entitlements = (
                self.signed_extension_entitlements
                if "ShareExtension.appex" in args[-1]
                else self.signed_app_entitlements
            )
            output = plistlib.dumps(entitlements).decode()
            return subprocess.CompletedProcess(args, 0, output, "")
        self.fail(f"unexpected tool command: {args}")

    def validate(self, **overrides):
        values = {
            "expected_version": VERSION,
            "expected_build": BUILD,
            "app_id": APP_ID,
            "extension_id": EXTENSION_ID,
            "team_id": TEAM_ID,
            "app_group": APP_GROUP,
            "built_after": self.built_after,
            "runner": self.fake_run,
            "now": NOW,
        }
        values.update(overrides)
        with patch.object(
            validator.unsigned,
            "macho_deployment_targets",
            return_value=[
                {"architecture": "arm64", "platform": "IOS", "minimum_ios": "13.0"}
            ],
        ):
            return validator.validate_signed_ipa(self.ipa, **values)

    def test_valid_fixture_passes_with_mocked_signing_tools(self):
        report = self.validate()
        self.assertEqual(report["result"], "passed")
        self.assertEqual(
            [bundle["bundle_id"] for bundle in report["bundles"]],
            [APP_ID, EXTENSION_ID],
        )
        self.assertEqual(report["macho_binaries_checked"], 2)
        self.assertEqual(
            report["bundles"][0]["profile"]["cms_signature"],
            "verified against Apple Root CA",
        )
        self.assertIn("unit tests mock signing tools", validator.__doc__.lower())
        self.assertIn("generated test ca", validator.__doc__.lower())

    def test_missing_ipa_fails_closed(self):
        with self.assertRaisesRegex(ValueError, "missing or empty"):
            validator.validate_signed_ipa(
                self.root / "missing.ipa",
                expected_version=VERSION,
                expected_build=BUILD,
                app_id=APP_ID,
                extension_id=EXTENSION_ID,
                team_id=TEAM_ID,
                app_group=APP_GROUP,
                built_after=0,
                runner=self.fake_run,
            )

    def test_malformed_ipa_fails_closed(self):
        self.write_ipa(corrupt=True)
        with self.assertRaisesRegex(ValueError, "not a readable IPA"):
            self.validate()

    def test_missing_extension_fails_before_extraction(self):
        self.write_ipa(include_extension=False)
        with self.assertRaisesRegex(ValueError, "expected only ShareExtension.appex"):
            self.validate()

    def test_missing_extension_privacy_manifest_fails(self):
        (self.extension / "PrivacyInfo.xcprivacy").unlink()
        self.write_ipa()
        with self.assertRaisesRegex(ValueError, "required app/extension files are missing"):
            self.validate()

    def test_missing_embedded_profile_fails(self):
        (self.app / "embedded.mobileprovision").unlink()
        self.write_ipa()
        with self.assertRaisesRegex(ValueError, "required app/extension files are missing"):
            self.validate()

    def test_malformed_embedded_profile_fails(self):
        self.malformed_app_profile = True
        with self.assertRaisesRegex(
            ValueError, "verified CMS content is not a valid profile plist"
        ):
            self.validate()

    def test_invalid_profile_cms_signature_fails(self):
        self.cms_verification_fails = True
        with self.assertRaisesRegex(ValueError, "openssl cms -verify.*CMS signature invalid"):
            self.validate()

    def test_missing_apple_root_ca_trust_certificates_fails(self):
        self.apple_roots_missing = True
        with self.assertRaisesRegex(ValueError, "no Apple Root CA trust certificates"):
            self.validate()

    def test_empty_profile_certificate_allowlist_fails(self):
        self.app_profile["DeveloperCertificates"] = []
        with self.assertRaisesRegex(ValueError, "DeveloperCertificates must contain DER"):
            self.validate()

    def test_unexpected_app_extension_fails_closed(self):
        unexpected = self.app / "PlugIns" / "Unexpected.appex"
        self.make_bundle(
            unexpected,
            "dev.howardism.Masquerade.Unexpected",
            VERSION,
            BUILD,
            executable="Unexpected",
        )
        self.write_ipa()
        with self.assertRaisesRegex(ValueError, "expected only ShareExtension.appex"):
            self.validate()

    def test_stale_output_fails_before_extraction(self):
        with self.assertRaisesRegex(ValueError, "IPA output is stale"):
            self.validate(built_after=self.ipa.stat().st_mtime + 10)

    def test_app_version_mismatch_fails(self):
        self.make_bundle(self.app, APP_ID, "1.29.1", BUILD, executable="Runner")
        self.write_ipa()
        with self.assertRaisesRegex(ValueError, "expected version 1.29.0"):
            self.validate()

    def test_extension_build_mismatch_fails(self):
        self.make_bundle(
            self.extension, EXTENSION_ID, VERSION, "18", executable="ShareExtension"
        )
        self.write_ipa()
        with self.assertRaisesRegex(ValueError, "expected build 17"):
            self.validate()

    def test_profile_bundle_mismatch_fails(self):
        self.extension_profile["Entitlements"]["application-identifier"] = (
            f"{TEAM_ID}.dev.howardism.OtherExtension"
        )
        with self.assertRaisesRegex(ValueError, "application-identifier does not match"):
            self.validate()

    def test_profile_team_mismatch_fails(self):
        self.app_profile["Entitlements"]["com.apple.developer.team-identifier"] = "OTHERTEAM"
        with self.assertRaisesRegex(ValueError, "expected team 9KRJ83FMAF"):
            self.validate()

    def test_expired_profile_fails(self):
        self.app_profile["ExpirationDate"] = NOW.replace(tzinfo=None) - dt.timedelta(days=1)
        with self.assertRaisesRegex(ValueError, "provisioning profile expired"):
            self.validate()

    def test_development_profile_fails(self):
        self.extension_profile["Entitlements"]["get-task-allow"] = True
        with self.assertRaisesRegex(ValueError, "get-task-allow must be false"):
            self.validate()

    def test_signature_verification_failure_fails(self):
        self.signature_verify_fails = True
        with self.assertRaisesRegex(ValueError, "codesign --verify.*signature invalid"):
            self.validate()

    def test_signature_team_mismatch_fails(self):
        self.signing_team = "OTHERTEAM"
        with self.assertRaisesRegex(ValueError, "signature team does not match"):
            self.validate()

    def test_signature_team_suffix_collision_fails(self):
        self.signing_team = f"{TEAM_ID}EXTRA"
        with self.assertRaisesRegex(ValueError, "signature team does not match"):
            self.validate()

    def test_signature_identifier_mismatch_fails(self):
        self.signing_identifier = "dev.howardism.OtherApp"
        with self.assertRaisesRegex(ValueError, "signature identifier does not match"):
            self.validate()

    def test_signature_identifier_suffix_collision_fails(self):
        self.signing_identifier = f"{APP_ID}.unexpected"
        with self.assertRaisesRegex(ValueError, "signature identifier does not match"):
            self.validate()

    def test_signature_certificate_not_in_profile_fails(self):
        self.app_profile["DeveloperCertificates"] = [b"unrelated certificate DER"]
        with self.assertRaisesRegex(ValueError, "signing leaf certificate is not authorized"):
            self.validate()

    def test_missing_signature_certificate_extraction_fails(self):
        self.omit_signature_leaf_certificate = True
        with self.assertRaisesRegex(ValueError, "did not extract the signature leaf"):
            self.validate()

    def test_human_readable_entitlements_fail_closed(self):
        self.human_readable_entitlements = True
        with self.assertRaisesRegex(ValueError, "did not return signed entitlements"):
            self.validate()

    def test_signed_entitlement_mismatch_fails(self):
        self.signed_extension_entitlements["com.apple.security.application-groups"] = []
        with self.assertRaisesRegex(ValueError, "signed application-group entitlement"):
            self.validate()

    def test_unsigned_extra_entitlement_not_in_profile_fails(self):
        self.signed_app_entitlements["com.apple.developer.unapproved-capability"] = True
        with self.assertRaisesRegex(ValueError, "not authorized by its profile"):
            self.validate()


@unittest.skipUnless(shutil.which("openssl"), "OpenSSL is required for CMS verification")
class ProfileCmsCryptoIntegrationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="profile-cms-crypto-")
        cls.root = Path(cls.temp.name)
        (cls.root / "signer.ext").write_text(
            "basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\n"
        )
        now = dt.datetime.now(dt.timezone.utc)
        payload = {
            "ExpirationDate": now + dt.timedelta(days=2),
            "ProvisionsAllDevices": False,
            "Entitlements": {"team": TEAM_ID},
        }
        (cls.root / "profile.plist").write_bytes(plistlib.dumps(payload))
        commands = [
            [
                "openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
                "-keyout", str(cls.root / "root.key"), "-out", str(cls.root / "root.pem"),
                "-days", "1", "-subj", "/CN=Test Apple Root CA",
                "-addext", "basicConstraints=critical,CA:TRUE",
                "-addext", "keyUsage=critical,keyCertSign,cRLSign",
            ],
            [
                "openssl", "req", "-newkey", "rsa:2048", "-nodes", "-keyout",
                str(cls.root / "signer.key"), "-out", str(cls.root / "signer.csr"),
                "-subj", "/CN=Test Profile Signer",
            ],
            [
                "openssl", "x509", "-req", "-in", str(cls.root / "signer.csr"),
                "-CA", str(cls.root / "root.pem"), "-CAkey", str(cls.root / "root.key"),
                "-CAcreateserial", "-out", str(cls.root / "signer.pem"), "-days", "1",
                "-sha256", "-extfile", str(cls.root / "signer.ext"),
            ],
            [
                "openssl", "cms", "-sign", "-binary", "-in", str(cls.root / "profile.plist"),
                "-signer", str(cls.root / "signer.pem"), "-inkey", str(cls.root / "signer.key"),
                "-certfile", str(cls.root / "root.pem"), "-outform", "DER", "-out",
                str(cls.root / "profile.mobileprovision"), "-nodetach",
            ],
        ]
        for command in commands:
            result = subprocess.run(command, capture_output=True, text=True)
            if result.returncode:
                raise RuntimeError(f"OpenSSL fixture setup failed: {result.stderr}")

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def test_profile_cms_signature_and_chain_are_verified(self):
        now = dt.datetime.now(dt.timezone.utc)
        profile = validator._profile_data(
            self.root / "profile.mobileprovision",
            self.root / "verified.plist",
            self.root / "root.pem",
            subprocess.run,
            now,
        )
        self.assertEqual(profile["Entitlements"]["team"], TEAM_ID)

    def test_tampered_profile_cms_is_rejected(self):
        tampered = self.root / "tampered.mobileprovision"
        contents = bytearray((self.root / "profile.mobileprovision").read_bytes())
        contents[-1] ^= 1
        tampered.write_bytes(contents)
        with self.assertRaisesRegex(ValueError, "openssl cms -verify failed"):
            validator._profile_data(
                tampered,
                self.root / "tampered.plist",
                self.root / "root.pem",
                subprocess.run,
                dt.datetime.now(dt.timezone.utc),
            )


if __name__ == "__main__":
    unittest.main()
