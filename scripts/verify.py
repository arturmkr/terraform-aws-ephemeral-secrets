#!/usr/bin/env python3
"""Security and lifecycle assertions that never print secret values."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any


WRITE_ONLY_OR_LEGACY_KEYS = {"secret_string", "secret_string_wo", "secret_binary"}


def run(command: list[str], cwd: Path | None = None) -> bytes:
    environment = os.environ.copy()
    environment["AWS_PAGER"] = ""
    environment["AWS_CLI_AUTO_PROMPT"] = "off"
    environment.pop("TF_LOG", None)
    environment.pop("TF_LOG_PATH", None)
    process = subprocess.run(
        command,
        cwd=cwd,
        env=environment,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if process.returncode != 0:
        # AWS and Terraform diagnostics are useful, but stdout may contain a
        # secret for get-secret-value. Never include stdout in failures.
        diagnostic = process.stderr.decode("utf-8", errors="replace").strip()
        raise RuntimeError(f"Command failed ({command[0]}): {diagnostic}")
    return process.stdout


def terraform(root_dir: Path, *arguments: str) -> bytes:
    return run(["terraform", f"-chdir={root_dir}", *arguments])


def terraform_metadata(root_dir: Path) -> dict[str, dict[str, Any]]:
    payload = terraform(root_dir, "output", "-json", "secrets")
    metadata = json.loads(payload)
    if not isinstance(metadata, dict) or not metadata:
        raise AssertionError("Terraform did not return secret metadata.")
    return metadata


def secret_value(secret_arn: str) -> bytes:
    payload = run(
        [
            "aws",
            "secretsmanager",
            "get-secret-value",
            "--secret-id",
            secret_arn,
            "--query",
            "SecretString",
            "--output",
            "text",
            "--no-cli-pager",
        ]
    )
    return payload.rstrip(b"\r\n")


def assert_write_only_fields_absent(value: Any, location: str = "root") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            child_location = f"{location}.{key}"
            # Plan configuration contains expression/reference objects for
            # write-only arguments. Those are safe; only a concrete string is
            # forbidden in state or planned values.
            if (
                key in WRITE_ONLY_OR_LEGACY_KEYS
                and isinstance(child, str)
                and child
            ):
                raise AssertionError(
                    f"Secret-bearing field {child_location} is populated in a Terraform artifact."
                )
            assert_write_only_fields_absent(child, child_location)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            assert_write_only_fields_absent(child, f"{location}[{index}]")


def assert_values_absent(artifact: bytes, values: list[bytes], label: str) -> None:
    for value in values:
        if value and value in artifact:
            raise AssertionError(f"A live AWS secret value is present in {label}.")


def assert_values_absent_from_json(value: Any, secrets: list[str], label: str) -> None:
    """Catch values that JSON escaping prevents a raw byte scan from finding."""
    if isinstance(value, dict):
        for child in value.values():
            assert_values_absent_from_json(child, secrets, label)
    elif isinstance(value, list):
        for child in value:
            assert_values_absent_from_json(child, secrets, label)
    elif isinstance(value, str):
        for secret in secrets:
            if secret and secret in value:
                raise AssertionError(f"A live AWS secret value is present in {label}.")


def artifacts(args: argparse.Namespace) -> None:
    root_dir = Path(args.root_dir).resolve()
    metadata = terraform_metadata(root_dir)
    values: list[bytes] = []

    for item in metadata.values():
        value = secret_value(item["arn"])
        if not value or value == b"None":
            raise AssertionError("At least one AWS secret has an empty value.")
        values.append(value)

    state = terraform(root_dir, "state", "pull")
    state_json = json.loads(state)
    assert_write_only_fields_absent(state_json, "state")
    assert_values_absent(state, values, "Terraform state")
    decoded_values = [value.decode("utf-8") for value in values]
    assert_values_absent_from_json(state_json, decoded_values, "Terraform state")

    if args.plan:
        plan_path = Path(args.plan).resolve()
        plan_raw = plan_path.read_bytes()
        plan_json_raw = terraform(root_dir, "show", "-json", str(plan_path))
        plan_json = json.loads(plan_json_raw)
        assert_write_only_fields_absent(plan_json, "plan")
        assert_values_absent(plan_raw, values, "the raw saved plan")
        assert_values_absent(plan_json_raw, values, "the JSON saved plan")
        assert_values_absent_from_json(plan_json, decoded_values, "the JSON saved plan")

    print(f"PASS: {len(values)} non-empty secrets; state and plan artifacts contain no secret values.")


def snapshot(args: argparse.Namespace) -> None:
    root_dir = Path(args.root_dir).resolve()
    result: dict[str, dict[str, Any]] = {}

    for name, item in terraform_metadata(root_dir).items():
        versions_raw = run(
            [
                "aws",
                "secretsmanager",
                "list-secret-version-ids",
                "--secret-id",
                item["arn"],
                "--include-deprecated",
                "--output",
                "json",
                "--no-cli-pager",
            ]
        )
        versions = json.loads(versions_raw).get("Versions", [])
        current = [
            version["VersionId"]
            for version in versions
            if "AWSCURRENT" in version.get("VersionStages", [])
        ]
        if len(current) != 1:
            raise AssertionError(f"Secret {name} does not have exactly one AWSCURRENT version.")
        result[name] = {
            "arn": item["arn"],
            "name": item["name"],
            "current_version_id": current[0],
            "version_count": len(versions),
        }

    print(json.dumps(result, sort_keys=True, indent=2))


def load_snapshot(path: str) -> dict[str, dict[str, Any]]:
    with Path(path).open(encoding="utf-8") as handle:
        return json.load(handle)


def compare_same(args: argparse.Namespace) -> None:
    before = load_snapshot(args.before)
    after = load_snapshot(args.after)
    if before != after:
        raise AssertionError("Secret metadata or AWS version IDs changed unexpectedly.")
    print(f"PASS: all {len(before)} AWS secret version IDs remained unchanged.")


def compare_rotation(args: argparse.Namespace) -> None:
    before = load_snapshot(args.before)
    after = load_snapshot(args.after)
    if before.keys() != after.keys() or args.target not in before:
        raise AssertionError("Rotation snapshots do not contain the same expected secrets.")

    for name in before:
        old = before[name]
        new = after[name]
        if old["arn"] != new["arn"] or old["name"] != new["name"]:
            raise AssertionError(f"AWS secret {name} was replaced during rotation.")
        if name == args.target:
            if old["current_version_id"] == new["current_version_id"]:
                raise AssertionError("The rotation target did not receive a new AWSCURRENT version.")
            if new["version_count"] != old["version_count"] + 1:
                raise AssertionError("Rotation did not add exactly one AWS Secrets Manager version.")
        elif old != new:
            raise AssertionError(f"Non-target secret {name} changed during rotation.")

    print(
        f"PASS: {args.target} gained one version without replacing its AWS secret; "
        "all other secrets were unchanged."
    )


def plan_no_secret_replacement(args: argparse.Namespace) -> None:
    root_dir = Path(args.root_dir).resolve()
    plan = json.loads(terraform(root_dir, "show", "-json", str(Path(args.plan).resolve())))
    secret_resources = [
        change
        for change in plan.get("resource_changes", [])
        if change.get("type") == "aws_secretsmanager_secret"
    ]
    if not secret_resources:
        raise AssertionError("Rotation plan contains no AWS secret metadata resources.")

    for change in secret_resources:
        actions = change.get("change", {}).get("actions", [])
        if "delete" in actions or "create" in actions:
            raise AssertionError(f"Rotation would replace {change.get('address')}.")

    print(f"PASS: rotation plan does not replace any of {len(secret_resources)} AWS secrets.")


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    commands = root.add_subparsers(dest="command", required=True)

    artifact_parser = commands.add_parser("artifacts")
    artifact_parser.add_argument("--root-dir", required=True)
    artifact_parser.add_argument("--plan")
    artifact_parser.set_defaults(function=artifacts)

    snapshot_parser = commands.add_parser("snapshot")
    snapshot_parser.add_argument("--root-dir", required=True)
    snapshot_parser.set_defaults(function=snapshot)

    same_parser = commands.add_parser("compare-same")
    same_parser.add_argument("--before", required=True)
    same_parser.add_argument("--after", required=True)
    same_parser.set_defaults(function=compare_same)

    rotation_parser = commands.add_parser("compare-rotation")
    rotation_parser.add_argument("--before", required=True)
    rotation_parser.add_argument("--after", required=True)
    rotation_parser.add_argument("--target", required=True)
    rotation_parser.set_defaults(function=compare_rotation)

    plan_parser = commands.add_parser("plan-no-secret-replacement")
    plan_parser.add_argument("--root-dir", required=True)
    plan_parser.add_argument("--plan", required=True)
    plan_parser.set_defaults(function=plan_no_secret_replacement)
    return root


def main() -> int:
    arguments = parser().parse_args()
    try:
        arguments.function(arguments)
    except (AssertionError, RuntimeError, json.JSONDecodeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
