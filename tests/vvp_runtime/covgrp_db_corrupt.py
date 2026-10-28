#!/usr/bin/env python3
"""Create checksum-valid malformed coverage DB files for regression tests."""

import sys


UINT32_MAX = (1 << 32) - 1
UNKNOWN_FAMILY = (1 << 32) - 1


def find_record(records, tag, predicate=lambda fields: True):
    for index, line in enumerate(records):
        fields = line.split()
        if fields and fields[0] == tag and predicate(fields):
            return index, fields
    raise ValueError(f"seed has no matching {tag} record")


def malformed(records, case):
    if case == "duplicate-dyn":
        index, _ = find_record(records, "dyn")
        records.insert(index + 1, records[index])
    elif case == "adjacent-range":
        index, fields = find_record(records, "range")
        family, lo, hi = fields[1], int(fields[2]), int(fields[3])
        if hi - lo < 1:
            raise ValueError("range is too short to split")
        mid = lo + (hi - lo) // 2
        records[index : index + 1] = [
            f"range {family} {lo} {mid}",
            f"range {family} {mid + 1} {hi}",
        ]
    elif case == "sized-index-outside-total":
        total_index, total = find_record(records, "total")
        family = total[1]
        dyn_index, dyn = find_record(
            records, "dyn", lambda fields: fields[1] == family
        )
        records[total_index] = f"total {family} 1"
        records[dyn_index] = f"dyn {family} 1 {dyn[3]}"
    elif case == "unknown-dyn-family":
        index, fields = find_record(records, "dyn")
        records[index] = f"dyn {UNKNOWN_FAMILY} " + " ".join(fields[2:])
    elif case == "dyn-count-overflow":
        index, fields = find_record(records, "dyn")
        records[index] = " ".join(fields[:-1] + [str(UINT32_MAX + 1)])
    elif case == "sord-dynamic-family":
        _, dyn = find_record(records, "dyn")
        type_index, _ = find_record(records, "type")
        records.insert(type_index + 1, f"sord {dyn[1]} 0 1")
    elif case == "sord-unknown-family":
        index, fields = find_record(records, "sord")
        records[index] = f"sord {UNKNOWN_FAMILY} {fields[2]} {fields[3]}"
    elif case == "sord-out-of-range":
        index, fields = find_record(records, "sord")
        records[index] = f"sord {fields[1]} 2 {fields[3]}"
    elif case == "duplicate-sord":
        index, _ = find_record(records, "sord")
        records.insert(index + 1, records[index])
    elif case == "sord-count-overflow":
        index, fields = find_record(records, "sord")
        records[index] = " ".join(fields[:-1] + [str(UINT32_MAX + 1)])
    elif case == "duplicate-total":
        index, _ = find_record(records, "total")
        records.insert(index + 1, records[index])
    elif case == "duplicate-cross":
        index, _ = find_record(records, "cross")
        records.insert(index + 1, records[index])
    elif case == "cross-count-overflow":
        index, fields = find_record(records, "cross")
        records[index] = " ".join(fields[:-1] + [str(UINT32_MAX + 1)])
    elif case == "cross-dynamic-value-outside-range":
        index, fields = find_record(records, "cross")
        term, _ = fields[3].split(":", 1)
        fields[3] = f"{term}:99"
        records[index] = " ".join(fields)
    elif case == "duplicate-cross-named":
        index, _ = find_record(records, "cross_named")
        records.insert(index + 1, records[index])
    elif case == "duplicate-trans":
        index, _ = find_record(records, "trans")
        records.insert(index + 1, records[index])
    elif case == "trans-count-overflow":
        index, fields = find_record(records, "trans")
        records[index] = " ".join(fields[:-1] + [str(UINT32_MAX + 1)])
    elif case == "duplicate-pop":
        index, _ = find_record(records, "pop")
        records.insert(index + 1, records[index])
    elif case == "missing-pop":
        index, _ = find_record(records, "pop")
        records.pop(index)
    elif case == "pop-nan":
        index, fields = find_record(records, "pop")
        fields[2] = "nan"
        records[index] = " ".join(fields)
    elif case == "pop-infinity":
        index, fields = find_record(records, "pop")
        fields[2] = "inf"
        records[index] = " ".join(fields)
    elif case == "pop-negative":
        index, fields = find_record(records, "pop")
        fields[2] = "-1"
        records[index] = " ".join(fields)
    elif case == "pop-over-100":
        index, fields = find_record(records, "pop")
        fields[2] = str(int(fields[1]) * 100 + 1)
        records[index] = " ".join(fields)
    elif case == "pop-zero-weight-positive":
        index, fields = find_record(records, "pop")
        fields[1] = "0"
        fields[2] = "1e-30"
        records[index] = " ".join(fields)
    elif case == "pop-item-zero-weight-positive":
        index, fields = find_record(records, "pop")
        fields[5] = "0"
        fields[6] = "1e-30"
        records[index] = " ".join(fields)
    elif case == "pop-fractional-weight":
        index, fields = find_record(records, "pop")
        fields[1] = "1.5"
        records[index] = " ".join(fields)
    elif case == "pop-vector-length":
        index, fields = find_record(records, "pop")
        fields[3] = str(int(fields[3]) + 1)
        records[index] = " ".join(fields)
    elif case == "pop-item-over-100":
        index, fields = find_record(records, "pop")
        fields[6] = str(int(fields[5]) * 100 + 1)
        records[index] = " ".join(fields)
    elif case == "pop-invalid-bin-flag":
        index, fields = find_record(records, "pop")
        fields[7] = "2"
        records[index] = " ".join(fields)
    elif case == "pop-invalid-at-least":
        index, fields = find_record(records, "pop")
        fields[8] = str(UINT32_MAX + 1)
        records[index] = " ".join(fields)
    elif case == "legacy-v1":
        if records[0] != "IVL_COVDB 2":
            raise ValueError("legacy conversion requires a version 2 database")
        records[0] = "IVL_COVDB 1"
        records[:] = [line for line in records if not line.startswith("pop ")]
    elif case == "merge-mismatch":
        index, fields = find_record(records, "type")
        fields[4] = "1" if fields[4] == "0" else "0"
        records[index] = " ".join(fields)
    else:
        raise ValueError(f"unknown mutation case: {case}")


def fnv1a64(data):
    value = 14695981039346656037
    for byte in data:
        value = ((value ^ byte) * 1099511628211) & ((1 << 64) - 1)
    return value


def main():
    if len(sys.argv) != 4:
        raise SystemExit("usage: covgrp_db_corrupt.py INPUT OUTPUT CASE")
    input_path, output_path, case = sys.argv[1:]
    with open(input_path, encoding="ascii") as source:
        lines = source.read().splitlines()
    if (
        len(lines) < 3
        or lines[0] not in ("IVL_COVDB 1", "IVL_COVDB 2")
        or not lines[-1].startswith("END ")
    ):
        raise SystemExit("invalid seed database")
    records = lines[:-1]
    malformed(records, case)
    body = ("\n".join(records) + "\n").encode("ascii")
    with open(output_path, "wb") as output:
        output.write(body)
        output.write(f"END {len(records)} {fnv1a64(body):016x}\n".encode("ascii"))


if __name__ == "__main__":
    main()
