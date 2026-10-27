#!/usr/bin/env python3
"""Fail-closed validation for Fastlane's exported, signed App Store IPA.

Fastlane's authenticated read-only profile retrieval supplies UUID and SHA-256
snapshots. This validator requires those exact profiles in the IPA before
decoding their metadata and checking the signed bundles. `security cms -D` is
used only to decode content; CMS signer trust is inherited from the Fastlane
profile retrieval and Xcode export, not independently checked here.
"""
from __future__ import annotations

import argparse
import datetime as dt
import fnmatch
import hashlib
import json
import plistlib
import re
import subprocess
import sys
import tempfile
import zipfile
from xml.parsers import expat
from pathlib import Path, PurePosixPath
from typing import Callable

import validate_unsigned_app as unsigned


Runner = Callable[..., subprocess.CompletedProcess]


def fail(message: str) -> None:
    raise ValueError(message)


def load_plist(path: Path) -> dict:
    try:
        with path.open("rb") as stream:
            value = plistlib.load(stream)
    except (OSError, plistlib.InvalidFileException, expat.ExpatError) as error:
        fail(f"{path}: cannot read property list: {error}")
    if not isinstance(value, dict):
        fail(f"{path}: expected a property-list dictionary")
    return value


def _run(
    runner: Runner,
    args: list[str],
    *,
    text: bool = True,
) -> subprocess.CompletedProcess:
    result = runner(args, check=False, capture_output=True, text=text)
    if result.returncode != 0:
        stderr = result.stderr
        if isinstance(stderr, bytes):
            stderr = stderr.decode("utf-8", "replace")
        fail(f"{' '.join(args[:3])} failed: {str(stderr).strip()}")
    return result


def _profile_data(
    profile_path: Path,
    expected_uuid: str,
    expected_sha256: str,
    runner: Runner,
    now: dt.datetime,
) -> dict:
    if not profile_path.is_file() or profile_path.stat().st_size == 0:
        fail(f"missing or empty embedded provisioning profile: {profile_path}")
    if not re.fullmatch(r"[0-9a-fA-F]{64}", expected_sha256):
        fail(f"invalid expected profile SHA-256 for {profile_path}")
    actual_sha256 = _sha256(profile_path)
    if actual_sha256.lower() != expected_sha256.lower():
        fail(f"{profile_path}: embedded profile differs from Fastlane's read-only profile")

    result = _run(
        runner,
        ["security", "cms", "-D", "-i", str(profile_path)],
        text=False,
    )
    output = result.stdout
    if isinstance(output, str):
        output = output.encode()
    try:
        profile = plistlib.loads(output)
    except (ValueError, plistlib.InvalidFileException, expat.ExpatError) as error:
        fail(f"{profile_path}: profile content is not a valid plist: {error}")
    if not isinstance(profile, dict):
        fail(f"{profile_path}: expected a provisioning profile dictionary")
    if profile.get("UUID") != expected_uuid:
        fail(
            f"{profile_path}: embedded profile UUID {profile.get('UUID')!r} does not match "
            f"Fastlane's read-only profile {expected_uuid!r}"
        )

    expiration = profile.get("ExpirationDate")
    if not isinstance(expiration, dt.datetime):
        fail(f"{profile_path}: profile ExpirationDate is missing or invalid")
    if expiration.tzinfo is None:
        expiration = expiration.replace(tzinfo=dt.timezone.utc)
    if expiration <= now:
        fail(f"{profile_path}: provisioning profile expired at {expiration.isoformat()}")

    if profile.get("ProvisionsAllDevices") is True or profile.get("ProvisionedDevices"):
        fail(f"{profile_path}: expected an App Store profile, not an ad hoc/development profile")

    profile["_source_sha256"] = actual_sha256.lower()
    return profile


def _verify_profile(
    profile_path: Path,
    profile: dict,
    bundle_id: str,
    team_id: str,
    app_group: str,
) -> dict:
    entitlements = profile.get("Entitlements")
    if not isinstance(entitlements, dict):
        fail(f"{profile_path}: profile entitlements are missing")

    if entitlements.get("get-task-allow") is not False:
        fail(f"{profile_path}: get-task-allow must be false for App Store distribution")

    profile_team = entitlements.get("com.apple.developer.team-identifier")
    if profile_team != team_id:
        fail(f"{profile_path}: expected team {team_id}, got {profile_team!r}")

    application_identifier = entitlements.get("application-identifier")
    prefixes = profile.get("ApplicationIdentifierPrefix")
    expected_suffix = f".{bundle_id}"
    if (
        not isinstance(application_identifier, str)
        or not application_identifier.endswith(expected_suffix)
    ):
        fail(
            f"{profile_path}: application-identifier does not match bundle ID {bundle_id}"
        )
    app_id_prefix = application_identifier[: -len(expected_suffix)]
    if not isinstance(prefixes, list) or app_id_prefix not in prefixes:
        fail(f"{profile_path}: application-identifier prefix is not in the profile")

    groups = entitlements.get("com.apple.security.application-groups", [])
    if not isinstance(groups, list) or app_group not in groups:
        fail(f"{profile_path}: required application group {app_group} is missing")
    certificates = profile.get("DeveloperCertificates")
    if not isinstance(certificates, list) or not certificates or any(
        not isinstance(certificate, bytes) or not certificate
        for certificate in certificates
    ):
        fail(f"{profile_path}: DeveloperCertificates must contain DER certificates")

    return {
        "name": profile.get("Name"),
        "uuid": profile.get("UUID"),
        "expires": expiration_for_report(profile["ExpirationDate"]),
        "bundle_id": bundle_id,
        "team_id": profile_team,
        "developer_certificates": len(certificates),
        "source_sha256": profile["_source_sha256"],
        "source_match": True,
        "source": "Fastlane read-only profile retrieval",
        "cms_signature_validated_independently": False,
    }


def expiration_for_report(value: dt.datetime) -> str:
    if value.tzinfo is None:
        value = value.replace(tzinfo=dt.timezone.utc)
    return value.astimezone(dt.timezone.utc).isoformat()


def _entitlement_value_authorized(signed, allowed) -> bool:
    if isinstance(signed, str) and isinstance(allowed, str):
        return fnmatch.fnmatchcase(signed, allowed)
    if isinstance(signed, list) and isinstance(allowed, list):
        return all(
            any(_entitlement_value_authorized(value, pattern) for pattern in allowed)
            for value in signed
        )
    if isinstance(signed, dict) and isinstance(allowed, dict):
        return all(
            key in allowed and _entitlement_value_authorized(value, allowed[key])
            for key, value in signed.items()
        )
    return signed == allowed


def _verify_signature(
    bundle: Path,
    bundle_id: str,
    team_id: str,
    app_group: str,
    profile: dict,
    certificate_prefix: Path,
    runner: Runner,
) -> None:
    _run(
        runner,
        ["codesign", "--verify", "--deep", "--strict", "--verbose=2", str(bundle)],
    )
    details = _run(
        runner,
        ["codesign", "-dv", "--verbose=4", str(bundle)],
    )
    detail_text = f"{details.stdout}\n{details.stderr}"
    signature_fields = {}
    for line in detail_text.splitlines():
        key, separator, value = line.partition("=")
        if separator and key in {"Identifier", "TeamIdentifier"}:
            if key in signature_fields:
                fail(f"{bundle}: signature reports duplicate {key} fields")
            signature_fields[key] = value.strip()
    if "Authority=Apple Distribution:" not in detail_text:
        fail(f"{bundle}: signature is not an Apple Distribution signature")
    if signature_fields.get("Identifier") != bundle_id:
        fail(f"{bundle}: signature identifier does not match {bundle_id}")
    if signature_fields.get("TeamIdentifier") != team_id:
        fail(f"{bundle}: signature team does not match {team_id}")

    _run(
        runner,
        [
            "codesign",
            "--display",
            f"--extract-certificates={certificate_prefix}",
            str(bundle),
        ],
    )
    leaf_certificate = Path(f"{certificate_prefix}0")
    if not leaf_certificate.is_file() or leaf_certificate.stat().st_size == 0:
        fail(f"{bundle}: codesign did not extract the signature leaf certificate")
    if leaf_certificate.read_bytes() not in profile.get("DeveloperCertificates", []):
        fail(f"{bundle}: signing leaf certificate is not authorized by its profile")

    signed = _run(
        runner,
        ["codesign", "--display", "--entitlements", "-", "--xml", str(bundle)],
    )
    entitlement_text = signed.stdout
    if isinstance(entitlement_text, bytes):
        entitlement_text = entitlement_text.decode("utf-8", "replace")
    plist_start = entitlement_text.find("<?xml")
    if plist_start < 0:
        plist_start = entitlement_text.find("<plist")
    if plist_start < 0:
        fail(f"{bundle}: codesign did not return signed entitlements")
    plist_end = entitlement_text.find("</plist>", plist_start)
    if plist_end < 0:
        fail(f"{bundle}: codesign returned incomplete signed entitlements")
    plist_end += len("</plist>")
    try:
        signed_entitlements = plistlib.loads(entitlement_text[plist_start:plist_end].encode())
    except (ValueError, plistlib.InvalidFileException, expat.ExpatError) as error:
        fail(f"{bundle}: codesign returned invalid entitlements: {error}")
    if not isinstance(signed_entitlements, dict):
        fail(f"{bundle}: signed entitlements are not a dictionary")

    profile_entitlements = profile["Entitlements"]
    for key, value in signed_entitlements.items():
        if key not in profile_entitlements or not _entitlement_value_authorized(
            value, profile_entitlements[key]
        ):
            fail(f"{bundle}: signed entitlement {key!r} is not authorized by its profile")

    if signed_entitlements.get("application-identifier") != profile_entitlements.get(
        "application-identifier"
    ):
        fail(f"{bundle}: signed application identifier does not match its profile")
    if signed_entitlements.get("com.apple.developer.team-identifier") != team_id:
        fail(f"{bundle}: signed team entitlement does not match {team_id}")
    if signed_entitlements.get("get-task-allow") is not False:
        fail(f"{bundle}: signed get-task-allow entitlement must be false")
    if app_group not in signed_entitlements.get(
        "com.apple.security.application-groups", []
    ):
        fail(f"{bundle}: signed application-group entitlement is missing")
    if not str(signed_entitlements["application-identifier"]).endswith(
        f".{bundle_id}"
    ):
        fail(f"{bundle}: signed application identifier does not match {bundle_id}")


def _validate_ipa_index(ipa_path: Path) -> tuple[str, str]:
    if not ipa_path.is_file() or ipa_path.stat().st_size == 0:
        fail(f"Fastlane IPA output is missing or empty: {ipa_path}")

    try:
        with zipfile.ZipFile(ipa_path) as archive:
            bad_member = archive.testzip()
            if bad_member is not None:
                fail(f"{ipa_path}: corrupt IPA member {bad_member}")
            names = archive.namelist()
    except (OSError, RuntimeError, zipfile.BadZipFile) as error:
        fail(f"{ipa_path}: not a readable IPA archive: {error}")

    if len(names) != len(set(names)):
        fail(f"{ipa_path}: duplicate ZIP member paths are not allowed")

    for name in names:
        path = PurePosixPath(name)
        if path.is_absolute() or ".." in path.parts or "\\" in name:
            fail(f"{ipa_path}: unsafe IPA member path {name!r}")

    app_info = [
        name
        for name in names
        if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", name)
    ]
    if len(app_info) != 1:
        fail(f"{ipa_path}: expected exactly one top-level Payload/*.app/Info.plist")

    app_root = app_info[0][: -len("/Info.plist")]
    extension_root = f"{app_root}/PlugIns/ShareExtension.appex"
    extension_info = sorted(
        name
        for name in names
        if re.fullmatch(re.escape(app_root) + r"/PlugIns/[^/]+\.appex/Info\.plist", name)
    )
    expected_extension_info = [f"{extension_root}/Info.plist"]
    if extension_info != expected_extension_info:
        fail(
            f"{ipa_path}: expected only ShareExtension.appex, found {extension_info}"
        )
    required = [
        f"{app_root}/Info.plist",
        f"{app_root}/PrivacyInfo.xcprivacy",
        f"{app_root}/embedded.mobileprovision",
        f"{extension_root}/Info.plist",
        f"{extension_root}/PrivacyInfo.xcprivacy",
        f"{extension_root}/embedded.mobileprovision",
    ]
    missing = [name for name in required if name not in names]
    if missing:
        fail(f"{ipa_path}: required app/extension files are missing: {missing}")
    return app_root, extension_root


def _bundle_info(
    bundle: Path,
    bundle_id: str,
    expected_version: str,
    expected_build: str,
) -> dict:
    info = load_plist(bundle / "Info.plist")
    if info.get("CFBundleIdentifier") != bundle_id:
        fail(
            f"{bundle}/Info.plist: expected bundle ID {bundle_id}, "
            f"got {info.get('CFBundleIdentifier')!r}"
        )
    if info.get("CFBundleShortVersionString") != expected_version:
        fail(
            f"{bundle}/Info.plist: expected version {expected_version}, "
            f"got {info.get('CFBundleShortVersionString')!r}"
        )
    if str(info.get("CFBundleVersion", "")) != expected_build:
        fail(
            f"{bundle}/Info.plist: expected build {expected_build}, "
            f"got {info.get('CFBundleVersion')!r}"
        )
    family = info.get("UIDeviceFamily")
    if bundle.suffix == ".app" and family != [1]:
        fail(f"{bundle}/Info.plist: expected iPhone-only UIDeviceFamily [1], got {family!r}")
    if family is not None and family != [1]:
        fail(f"{bundle}/Info.plist: expected iPhone-only UIDeviceFamily [1], got {family!r}")
    return info


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_signed_ipa(
    ipa_path: Path,
    *,
    expected_version: str,
    expected_build: str,
    app_id: str,
    extension_id: str,
    team_id: str,
    app_group: str,
    built_after: float,
    app_profile_uuid: str,
    app_profile_sha256: str,
    extension_profile_uuid: str,
    extension_profile_sha256: str,
    runner: Runner = subprocess.run,
    now: dt.datetime | None = None,
) -> dict:
    ipa_path = ipa_path.resolve()
    if not ipa_path.is_file() or ipa_path.stat().st_size == 0:
        fail(f"Fastlane IPA output is missing or empty: {ipa_path}")
    if ipa_path.stat().st_mtime < built_after:
        fail(f"Fastlane IPA output is stale: {ipa_path}")

    now = now or dt.datetime.now(dt.timezone.utc)
    app_root, extension_root = _validate_ipa_index(ipa_path)

    with tempfile.TemporaryDirectory(prefix="masquerade-signed-ipa-") as temp:
        extraction = Path(temp)
        _run(runner, ["ditto", "-x", "-k", str(ipa_path), str(extraction)])
        app = extraction / app_root
        extension = extraction / extension_root
        if not app.is_dir() or not extension.is_dir():
            fail("Fastlane IPA extraction is missing Runner.app or ShareExtension.appex")

        app_info = _bundle_info(app, app_id, expected_version, expected_build)
        extension_info = _bundle_info(
            extension, extension_id, expected_version, expected_build
        )
        if app_info.get("MinimumOSVersion") is None:
            fail(f"{app}/Info.plist: MinimumOSVersion is missing")
        if extension_info.get("MinimumOSVersion") is None:
            fail(f"{extension}/Info.plist: MinimumOSVersion is missing")

        bundles = [
            unsigned.validate_bundle(app, app_id, expected_version),
            unsigned.validate_bundle(extension, extension_id, expected_version),
        ]
        binaries = [
            path for path in app.rglob("*") if path.is_file() and unsigned.is_mach_o(path)
        ]
        if not binaries:
            fail("no Mach-O binaries were found in the signed IPA")
        checked_minimums = []
        for binary in binaries:
            builds = unsigned.macho_deployment_targets(binary)
            unsigned.validate_macho_builds(binary, builds)
            checked_minimums.extend(
                {
                    "path": str(binary.relative_to(app)),
                    "architecture": build["architecture"],
                    "platform": build["platform"],
                    "minimum_ios": build["minimum_ios"],
                }
                for build in builds
            )

        reports = []
        profile_inputs = (
            (app, app_id, app_profile_uuid, app_profile_sha256),
            (
                extension,
                extension_id,
                extension_profile_uuid,
                extension_profile_sha256,
            ),
        )
        for bundle, bundle_id, expected_uuid, expected_sha256 in profile_inputs:
            profile_path = bundle / "embedded.mobileprovision"
            profile = _profile_data(
                profile_path,
                expected_uuid,
                expected_sha256,
                runner,
                now,
            )
            profile_summary = _verify_profile(
                bundle / "embedded.mobileprovision",
                profile,
                bundle_id,
                team_id,
                app_group,
            )
            certificate_prefix = extraction / f"signature-certificate-{bundle_id}-"
            _verify_signature(
                bundle,
                bundle_id,
                team_id,
                app_group,
                profile,
                certificate_prefix,
                runner,
            )
            reports.append(
                {
                    "bundle_id": bundle_id,
                    "version": expected_version,
                    "build": expected_build,
                    "minimum_ios": str(
                        load_plist(bundle / "Info.plist").get("MinimumOSVersion")
                    ),
                    "profile": profile_summary,
                    "signature": "verified Apple Distribution",
                }
            )

    return {
        "result": "passed",
        "ipa": str(ipa_path),
        "ipa_size": ipa_path.stat().st_size,
        "ipa_sha256": _sha256(ipa_path),
        "bundles": reports,
        "macho_binaries_checked": len(binaries),
        "macho_minimums": checked_minimums,
    }


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa", type=Path)
    parser.add_argument("--expected-version", required=True)
    parser.add_argument("--expected-build", required=True)
    parser.add_argument("--app-id", required=True)
    parser.add_argument("--extension-id", required=True)
    parser.add_argument("--team-id", required=True)
    parser.add_argument("--app-group", required=True)
    parser.add_argument("--built-after", required=True, type=float)
    parser.add_argument("--app-profile-uuid", required=True)
    parser.add_argument("--app-profile-sha256", required=True)
    parser.add_argument("--extension-profile-uuid", required=True)
    parser.add_argument("--extension-profile-sha256", required=True)
    return parser


def main() -> int:
    args = _parser().parse_args()
    report = validate_signed_ipa(
        args.ipa,
        expected_version=args.expected_version,
        expected_build=args.expected_build,
        app_id=args.app_id,
        extension_id=args.extension_id,
        team_id=args.team_id,
        app_group=args.app_group,
        built_after=args.built_after,
        app_profile_uuid=args.app_profile_uuid,
        app_profile_sha256=args.app_profile_sha256,
        extension_profile_uuid=args.extension_profile_uuid,
        extension_profile_sha256=args.extension_profile_sha256,
    )
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"signed IPA validation failed: {error}", file=sys.stderr)
        raise SystemExit(1)
