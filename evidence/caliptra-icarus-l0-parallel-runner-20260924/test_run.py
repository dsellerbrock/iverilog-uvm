#!/usr/bin/env python3
"""Focused, read-only checks for parallel L0 result aggregation."""

import copy
import json

import run


BASE = run.ROOT / "evidence/caliptra-icarus-l0-diagnostic-combined-p1-20260924"
SUMMARY = json.loads((BASE / "summary.json").read_text())
RESULT = json.loads((BASE / "smoke_test_veer/result.json").read_text())


def case(profile_hash, input_hash):
    summary, result = copy.deepcopy(SUMMARY), copy.deepcopy(RESULT)
    provenance = {"listen_port_after": 0,
                  "source_sha256_after": run.JTAG_EPHEMERAL_TOP_SHA256,
                  "profile_sha256_after": profile_hash,
                  "profile_sha256_before": input_hash}
    for item in (summary, result):
        item.update(qualification=run.QUALIFICATION, ephemeral_jtag_port=True,
                    jtag_port_provenance=provenance)
    result["jtag_server_errors"] = 0
    for key in ("fingerprints_before", "fingerprints_after"):
        summary[key].update(profile=profile_hash, jtag_profile_input=input_hash,
                            jtag_top_source="same pinned source",
                            jtag_top_overlay=run.JTAG_EPHEMERAL_TOP_SHA256)
    return summary, result


first_summary, first_result = case("case-one-profile", "case-one-input")
next_summary, next_result = case("case-two-profile", "case-two-input")
assert run.classify("smoke_test_veer", 0, first_summary, first_result)[0] == "PASS"
assert run.classify("smoke_test_veer", 0, next_summary, next_result)[0] == "PASS"
assert run.stable_fingerprints_match([
    first_summary["fingerprints_before"], next_summary["fingerprints_before"]])
changed = copy.deepcopy(next_summary["fingerprints_before"])
changed["compiler"] = "different compiler"
assert not run.stable_fingerprints_match([first_summary["fingerprints_before"], changed])
bad_port = copy.deepcopy(first_result)
bad_port["jtag_port_provenance"]["listen_port_after"] = 63224
assert run.classify("smoke_test_veer", 0, first_summary, bad_port)[0] == "INVALIDATED"
bad_top = copy.deepcopy(first_result)
bad_top["jtag_port_provenance"]["source_sha256_after"] = "different top"
assert run.classify("smoke_test_veer", 0, first_summary, bad_top)[0] == "INVALIDATED"
print("PASS: distinct temporary profiles, stable-key mismatch, JTAG port/source guards")
