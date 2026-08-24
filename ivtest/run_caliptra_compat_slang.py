#!/usr/bin/env python3
"""Check focused Caliptra compatibility cases against Slang 1800-2017.

The case labels distinguish standard agreement from deliberate compatibility
boundaries: a Caliptra hierarchical-cross extension, known Slang disagreements
with the IEEE text, and legal forms that Icarus rejects loudly pending lossless
lowering. Run this script through the repository resource wrapper so Slang and
its descendants retain the campaign CPU guard.
"""

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


CASES = (
    ("sv_task_localparam_untyped", "standard", 0, 0, (), ()),
    (
        "sv_based_literal_leading_underscore",
        "ieee-accepted-slang-rejects",
        4,
        0,
        ("numeric literals must not start with a leading underscore",) * 4,
        (),
    ),
    ("sv_darray_new_default_fill", "standard", 0, 0, (), ()),
    ("sv_darray_new_default_runtime_size", "standard", 0, 0, (), ()),
    (
        "sv_darray_new_default_type_fail",
        "standard",
        1,
        0,
        ("cannot be assigned to type 'int'",),
        (),
    ),
    ("sv_covergroup_bin_iff", "standard", 0, 0, (), ()),
    ("sv_covergroup_constructor_scope", "standard", 0, 0, (), ()),
    ("sv_covergroup_cross_with", "standard", 0, 0, (), ()),
    ("sv_covergroup_following_localparam", "standard", 0, 0, (), ()),
    (
        "sv_covergroup_hierarchical_cross",
        "caliptra-extension",
        2,
        0,
        ("non-standard hierarchical reference in cover cross item",) * 2,
        (),
    ),
    ("sv_covergroup_transition_modes", "standard", 0, 0, (), ()),
    ("sv_covergroup_transition_repeat", "standard", 0, 0, (), ()),
    (
        "sv_covergroup_transition_repeat_fail",
        "ieee-invalid-slang-accepts",
        0,
        0,
        (),
        (),
    ),
    (
        "sv_assert_control_labeled_selective",
        "standard",
        0,
        2,
        (),
        ("sequence can never be matched",) * 2,
    ),
    (
        "sv_assert_control_instance_identity",
        "standard",
        0,
        1,
        (),
        ("sequence can never be matched",),
    ),
    ("sv_assert_eventually_not", "standard", 0, 0, (), ()),
    ("sv_assert_nested_nonoverlap_fanout", "standard", 0, 0, (), ()),
    ("sv_assert_nested_nonoverlap_unbounded", "standard", 0, 0, (), ()),
    ("sv_assert_property_local_declared_type", "standard", 0, 0, (), ()),
    ("sv_assert_property_local_packed", "standard", 0, 0, (), ()),
    ("sv_assert_property_local_unbounded_wait", "standard", 0, 0, (), ()),
    ("sv_assert_modport_preponed_sample", "standard", 0, 0, (), ()),
    ("sv_assert_packed_member_preponed_sample", "standard", 0, 0, (), ()),
    ("sv_vif_clocking_partial_member_preserve", "standard", 0, 0, (), ()),
    ("sv_vif_clocking_partial_select_preserve", "standard", 0, 0, (), ()),
    ("sv_vif_clocking_output_skew_scope", "standard", 0, 0, (), ()),
    ("sv_clocking_static_output_skew_scope", "standard", 0, 0, (), ()),
    ("sv_clocking_selected_output_static", "standard", 0, 0, (), ()),
    ("sv_clocking_selected_output_alias", "standard", 0, 0, (), ()),
    ("sv_clocking_selected_output_dynamic_fail", "standard", 0, 0, (), ()),
    ("sv_clocking_class_handle_shadow_selected", "standard", 0, 0, (), ()),
    ("sv_clocking_vif_skew_precision_order", "standard", 0, 0, (), ()),
    ("sv_clocking_vif_skew_type_only", "standard", 0, 0, (), ()),
    ("sv_clocking_vif_selected_dynamic_fail", "standard", 0, 0, (), ()),
    ("sv_vif_clocking_output_complex_alias", "standard", 0, 0, (), ()),
    ("sv_vif_clocking_output_target_select_fail", "standard", 0, 0, (), ()),
    ("sv_clocking_vif_modport_output", "standard", 0, 0, (), ()),
    ("sv_clocking_vif_modport_input_event", "standard", 0, 0, (), ()),
    (
        "sv_clocking_vif_modport_raw_member_fail",
        "standard",
        1,
        0,
        ("cannot access 'raw' via modport",),
        (),
    ),
    (
        "sv_clocking_vif_modport_unexported_clocking_fail",
        "standard",
        1,
        0,
        ("cannot access 'hidden_cb' via modport",),
        (),
    ),
    ("sv_clocking_class_vif_modport_output", "standard", 0, 0, (), ()),
    ("sv_clocking_class_vif_modport_input_event", "standard", 0, 0, (), ()),
    (
        "sv_clocking_class_vif_modport_raw_member_fail",
        "standard",
        1,
        0,
        ("cannot access 'raw' via modport",),
        (),
    ),
    (
        "sv_clocking_class_vif_modport_unexported_clocking_fail",
        "standard",
        1,
        0,
        ("cannot access 'hidden_cb' via modport",),
        (),
    ),
    (
        "sv_clocking_class_vif_modport_clocking_collision_fail",
        "standard",
        1,
        0,
        ("cannot access 'hidden_cb' via modport",),
        (),
    ),
    (
        "sv_clocking_class_vif_modport_property_isolation",
        "standard",
        0,
        0,
        (),
        (),
    ),
    (
        "sv_clocking_vif_modport_typedef_raw_member_fail",
        "standard",
        1,
        0,
        ("cannot access 'raw' via modport",),
        (),
    ),
    (
        "sv_clocking_class_typeparam_vif_modport_raw_member_fail",
        "standard",
        2,
        0,
        ("cannot access 'raw' via modport",) * 2,
        (),
    ),
    (
        "sv_clocking_struct_vif_modport_raw_member_fail",
        "standard",
        2,
        0,
        ("cannot access 'raw' via modport",) * 2,
        (),
    ),
    (
        "sv_clocking_vif_numeric_input_skew_zero_order",
        "standard",
        0,
        0,
        (),
        (),
    ),
    (
        "sv_clocking_vif_numeric_input_skew_delay_order",
        "standard",
        0,
        0,
        (),
        (),
    ),
    (
        "sv_clocking_concat_member_lvalue_fail",
        "standard",
        1,
        0,
        ("cannot be part of a concatenation or assignment pattern lvalue",),
        (),
    ),
    (
        "sv_clocking_indexed_class_receiver_fail",
        "ieee-accepted-icarus-ni",
        0,
        0,
        (),
        (),
    ),
    (
        "sv_clocking_root_indexed_class_receiver_fail",
        "ieee-accepted-icarus-ni",
        0,
        0,
        (),
        (),
    ),
    (
        "sv_clocking_unpacked_output_storage_fail",
        "ieee-accepted-icarus-ni",
        0,
        0,
        (),
        (),
    ),
    (
        "sv_clocking_selected_decl_assign_target_fail",
        "ieee-accepted-icarus-ni",
        0,
        0,
        (),
        (),
    ),
    (
        "sv_clocking_vif_input_sys_task_arg",
        "standard",
        0,
        0,
        (),
        (),
    ),
    (
        "sv_clocking_vif_vpi_write_fail",
        "standard",
        3,
        0,
        (
            "cannot write to input clocking signal",
            "can only be written via a synchronous drive",
            "cannot assign to input port",
        ),
        (),
    ),
    (
        "sv_clocking_nonconstant_output_skew_fail",
        "standard",
        1,
        0,
        ("reference to non-constant variable",),
        (),
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


def check_messages(diagnostics, severity, fragments):
    messages = [
        item.get("message", "")
        for item in diagnostics
        if item.get("severity") == severity
    ]
    failures = []
    if len(messages) == len(fragments):
        for index, (message, fragment) in enumerate(zip(messages, fragments), 1):
            if fragment not in message:
                failures.append(
                    f"{severity} {index} lacks {fragment!r}: {message!r}"
                )
    return failures


def check_case(slang, source_dir, temp_dir, case):
    name, boundary, expected_errors, expected_warnings, errors, warnings = case
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

    actual_errors = [
        item for item in diagnostics if item.get("severity") == "error"
    ]
    actual_warnings = [
        item for item in diagnostics if item.get("severity") == "warning"
    ]
    failures = []
    should_accept = expected_errors == 0
    if (result.returncode == 0) != should_accept:
        failures.append(f"return code {result.returncode}")
    if len(actual_errors) != expected_errors:
        failures.append(f"{len(actual_errors)} errors, expected {expected_errors}")
    if len(actual_warnings) != expected_warnings:
        failures.append(
            f"{len(actual_warnings)} warnings, expected {expected_warnings}"
        )
    failures.extend(check_messages(diagnostics, "error", errors))
    failures.extend(check_messages(diagnostics, "warning", warnings))

    if failures:
        detail = "; ".join(failures)
        if result.stderr:
            detail += f"\n{result.stderr.rstrip()}"
        return False, detail

    return (
        True,
        f"{boundary}: {len(actual_errors)} errors, "
        f"{len(actual_warnings)} warnings",
    )


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
    with tempfile.TemporaryDirectory(prefix="ivtest-slang-caliptra-") as temp_name:
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
