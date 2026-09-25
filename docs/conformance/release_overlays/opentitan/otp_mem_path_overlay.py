#!/usr/bin/env python3
"""Flatten two OTP path macros in a disposable copy of the pinned testbench."""

import argparse
import hashlib
from pathlib import Path
from tempfile import TemporaryDirectory


SOURCE_SHA256 = "9ae010405678fbaad44c83143793345af6e5aa1e0152bd2e06a9c838f3d63f1a"
OVERLAY_SHA256 = "a7bd1964e2c7e626d5a25a04597129417a7c47f89c95069da6af86dd094689c6"
OLD = (b"    `define MEM_MODULE_PATH \\\n"
       b"        tb.dut.u_otp.gen_generic.u_impl_generic.u_prim_ram_1p_adv\n"
       b"\n"
       b"    `define MEM_ARRAY_PATH \\\n"
       b"        `MEM_MODULE_PATH.u_mem.gen_generic.u_impl_generic.mem\n")
NEW = (b"    `define MEM_MODULE_PATH tb.dut.u_otp.gen_generic.u_impl_generic.u_prim_ram_1p_adv\n"
       b"\n"
       b"    `define MEM_ARRAY_PATH `MEM_MODULE_PATH.u_mem.gen_generic.u_impl_generic.mem\n")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def apply(source: Path, output: Path) -> None:
    if source.resolve() == output.resolve():
        raise ValueError("output must be a separate disposable file")
    original = source.read_bytes()
    if sha256(original) != SOURCE_SHA256 or original.count(OLD) != 1:
        raise ValueError("source is not the pinned OpenTitan OTP tb.sv")
    overlaid = original.replace(OLD, NEW)
    if sha256(overlaid) != OVERLAY_SHA256:
        raise ValueError("unexpected OTP overlay result")
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("xb") as stream:
        stream.write(overlaid)
    print(f"OTP overlay: {SOURCE_SHA256} -> {OVERLAY_SHA256}: {output}")


def self_check(source: Path) -> None:
    with TemporaryDirectory() as directory:
        root = Path(directory)
        apply(source, root / "tb.sv")
        if sha256((root / "tb.sv").read_bytes()) != OVERLAY_SHA256:
            raise AssertionError("overlay output changed")
        changed = root / "changed.sv"
        changed.write_bytes(source.read_bytes() + b"\n")
        try:
            apply(changed, root / "rejected.sv")
        except ValueError:
            pass
        else:
            raise AssertionError("changed source was accepted")
        if (root / "rejected.sv").exists():
            raise AssertionError("changed source produced an overlay")
    print("OTP overlay self-check passed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="pinned or generated OTP tb.sv")
    parser.add_argument("output", type=Path, nargs="?", help="new disposable tb.sv")
    parser.add_argument("--self-check", action="store_true")
    args = parser.parse_args()
    if args.self_check:
        if args.output is not None:
            parser.error("--self-check takes only the source path")
        self_check(args.source)
    elif args.output is None:
        parser.error("an output path is required")
    else:
        apply(args.source, args.output)
