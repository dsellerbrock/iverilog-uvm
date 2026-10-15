#!/usr/bin/env python3
"""Extract the selected Callgrind function-node costs used in WP0 evidence."""

import argparse
import csv
import gzip
import re
from collections import defaultdict
from pathlib import Path

FUNCTIONS = (
    "vthread_run(vthread_s*)",
    "vthread_run(vthread_s*)'2",
    "of_CAST2(vthread_s*, vvp_code_s*)",
    "of_DELAY(vthread_s*, vvp_code_s*)",
    "schedule_event_(event_s*, unsigned long, event_queue_e)",
    "schedule_simulate()",
    "vthread_run_unpin_(vthread_s*)",
    "vvp_send_vec4(vvp_sub_pointer_t<vvp_net_t>, vvp_vector4_t const&, void**)",
)


def first_function_costs(profile):
    names = {}
    first_cost = {}
    current = None
    skip_call_cost = False
    with gzip.open(profile, "rt", errors="replace") as stream:
        for line in stream:
            match = re.match(r"(?:fn|cfn)=\((\d+)\)(?:\s+(.*))?\s*$", line.rstrip())
            if match:
                ident, name = match.groups()
                if name:
                    names[ident] = name
                if line.startswith("fn="):
                    current = ident
                continue
            if line.startswith("calls="):
                skip_call_cost = True
            elif re.match(r"^\d+\s+\d+(?:\s+\d+)*\s*$", line):
                if skip_call_cost:
                    skip_call_cost = False
                elif current is not None and current not in first_cost:
                    # Match the first direct function-node cost used by job 1135.
                    first_cost[current] = int(line.split()[-1])

    result = defaultdict(list)
    for ident, value in first_cost.items():
        if ident in names:
            result[names[ident]].append(value)
    missing = [name for name in FUNCTIONS if name not in result]
    assert not missing, f"functions absent from profile: {missing}"
    assert all(len(result[name]) == 1 for name in FUNCTIONS), "duplicate function IDs"
    return {name: result[name][0] for name in FUNCTIONS}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("reference", type=Path)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    reference = first_function_costs(args.reference)
    candidate = first_function_costs(args.candidate)
    with args.output.open("w", newline="") as stream:
        writer = csv.writer(stream, lineterminator="\n")
        writer.writerow(["function", "reference_ir", "candidate_ir", "identical"])
        for name in FUNCTIONS:
            writer.writerow([
                name,
                reference[name],
                candidate[name],
                "yes" if reference[name] == candidate[name] else "no",
            ])


if __name__ == "__main__":
    main()
