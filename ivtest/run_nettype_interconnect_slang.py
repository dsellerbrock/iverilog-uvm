#!/usr/bin/env python3
"""Check the focused IEEE 1800-2017 nettype/interconnect Slang oracle."""

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


CASES = (
    ("sv_nettype_corpus_decl", "accept", 0, ()),
    ("sv_nettype_corpus_resolution_fn", "accept", 0, ()),
    ("sv_interconnect_corpus", "accept", 0, ()),
    ("sv_nettype_direct", "accept", 0, ()),
    ("sv_nettype_alias", "accept", 0, ()),
    ("sv_nettype_package", "accept", 0, ()),
    ("sv_nettype_parameter_instances", "accept", 0, ()),
    ("sv_nettype_single_driver", "accept", 0, ()),
    (
        "sv_nettype_invalid_underlying_fail",
        "reject",
        4,
        ("is not a valid type for a user-defined nettype",) * 4,
    ),
    (
        "sv_nettype_lookup_fail",
        "reject",
        2,
        (
            "undeclared identifier 'missing_net'",
            "undeclared identifier 'missing_resolver'",
        ),
    ),
    (
        "sv_nettype_resolver_signature_fail",
        "reject",
        4,
        (
            "should have a single input argument",
            "should have a return type",
            "should have a single input argument",
            "cannot be a task",
        ),
    ),
    (
        "sv_nettype_resolved_runtime_boundary_fail",
        "accept",
        0,
        (),
    ),
    (
        "sv_nettype_unresolved_multiple_driver_fail",
        "reject",
        1,
        ("cannot have multiple drivers because it does not specify a resolution function",),
    ),
    (
        "sv_nettype_unresolved_select_driver_fail",
        "reject",
        3,
        ("with user-defined nettype cannot be partially driven",) * 3,
    ),
    ("sv_interconnect_scalar", "accept", 0, ()),
    ("sv_interconnect_shapes", "accept", 0, ()),
    (
        "sv_interconnect_declaration_fail",
        "reject",
        4,
        (
            "interconnect nets cannot have an explicit type",
            "interconnect nets cannot have an explicit type",
            "interconnect net delays can only be a single value",
            "interconnect nets cannot have initializers",
        ),
    ),
    (
        "sv_interconnect_reference_fail",
        "reject",
        2,
        ("cannot reference interconnect net",) * 2,
    ),
    (
        "sv_interconnect_variable_fail",
        "reject",
        1,
        ("cannot connect 'variable_connection' to an interconnect port",),
    ),
    (
        "sv_interconnect_udnt_conflict_fail",
        "reject",
        1,
        ("cannot mix and match nets with user-defined nettypes",),
    ),
    (
        "sv_interconnect_unresolved_fail",
        "reject",
        1,
        ("cannot reference interconnect net 'unresolved_port'",),
    ),
)


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--slang",
        default="slang",
        help="Slang executable to run (default: %(default)s from PATH)",
    )
    return parser.parse_args()


def resolve_executable(value):
    candidate = Path(value).expanduser()
    if candidate.parent != Path("."):
        return str(candidate.resolve())
    resolved = shutil.which(value)
    if resolved is None:
        raise FileNotFoundError(value)
    return resolved


def check_case(slang, source_dir, temp_dir, case):
    name, polarity, expected_errors, message_fragments = case
    source = source_dir / f"{name}.v"
    diag_json = temp_dir / f"{name}.json"
    command = [
        slang,
        "--std",
        "1800-2017",
        "--error-limit",
        "0",
        "--diag-json",
        str(diag_json),
        str(source),
    ]
    result = subprocess.run(command, capture_output=True, text=True, check=False)

    try:
        diagnostics = json.loads(diag_json.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError) as error:
        return False, f"no readable diagnostic JSON ({error})"

    errors = [item for item in diagnostics if item.get("severity") == "error"]
    warnings = [item for item in diagnostics if item.get("severity") == "warning"]
    should_accept = polarity != "reject"
    failures = []

    if (result.returncode == 0) != should_accept:
        failures.append(f"return code {result.returncode}")
    if len(errors) != expected_errors:
        failures.append(f"{len(errors)} errors, expected {expected_errors}")
    if warnings:
        failures.append(f"{len(warnings)} warnings, expected 0")

    messages = [item.get("message", "") for item in errors]
    if len(messages) == len(message_fragments):
        for index, (message, fragment) in enumerate(zip(messages, message_fragments), 1):
            if fragment not in message:
                failures.append(f"error {index} lacks {fragment!r}: {message!r}")

    if failures:
        detail = "; ".join(failures)
        if result.stderr:
            detail += f"\n{result.stderr.rstrip()}"
        return False, detail

    return True, f"{polarity}: {len(errors)} errors, {len(warnings)} warnings"


def main():
    args = parse_args()
    try:
        slang = resolve_executable(args.slang)
    except FileNotFoundError:
        print(f"error: Slang executable not found: {args.slang}", file=sys.stderr)
        return 2

    ivtest_dir = Path(__file__).resolve().parent
    source_dir = ivtest_dir / "ivltests"
    failures = 0
    with tempfile.TemporaryDirectory(prefix="ivtest-slang-nettype-") as temp_name:
        temp_dir = Path(temp_name)
        for case in CASES:
            passed, detail = check_case(slang, source_dir, temp_dir, case)
            status = "PASS" if passed else "FAIL"
            print(f"{status} {case[0]}: {detail}")
            failures += not passed

    print(f"Checked {len(CASES)} cases; {failures} failed.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
