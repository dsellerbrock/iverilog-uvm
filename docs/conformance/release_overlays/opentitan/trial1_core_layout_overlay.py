#!/usr/bin/env python3
"""Relocate Trial1's FuseSoC core file in a disposable OpenTitan source copy."""

import argparse
import hashlib
from pathlib import Path
from tempfile import TemporaryDirectory


SOURCE_SHA256 = "813a80976210fa4f7fcdecc9652fdf29c8d5c9e457cd82b664b2aaa3194fb010"
OVERLAY_SHA256 = "bc7ddd308b293338a8669618cd1bb42c770040097f66abb4cae8cf38db8c5a37"
OLD_PATH = Path("hw/ip/trial1/dv/trial1_sim.core")
NEW_PATH = Path("hw/ip/trial1/trial1_sim.core")
REWRITES = (
    (b"      - ../rtl/trial1_reg_pkg.sv\n", b"      - rtl/trial1_reg_pkg.sv\n"),
    (b"      - ../rtl/trial1_reg_top.sv\n", b"      - rtl/trial1_reg_top.sv\n"),
    (b"      - bus_pkg.sv\n", b"      - dv/bus_pkg.sv\n"),
    (b"      - trial1_test.sv\n", b"      - dv/trial1_test.sv\n"),
    (b"      - tb.sv\n", b"      - dv/tb.sv\n"),
)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def apply(root: Path) -> None:
    if (root / ".git").exists():
        raise ValueError("apply only to a disposable copy without .git")
    old, new = root / OLD_PATH, root / NEW_PATH
    if (not old.resolve().is_relative_to(root.resolve())
            or not new.parent.resolve().is_relative_to(root.resolve())):
        raise ValueError("Trial1 core path escapes the disposable source root")
    original = old.read_bytes()
    if digest(original) != SOURCE_SHA256 or new.exists() or new.is_symlink():
        raise ValueError("Trial1 core preimage or destination differs from pinned source")
    updated = original
    for before, after in REWRITES:
        if updated.count(before) != 1:
            raise ValueError("Trial1 core file path layout differs from pinned source")
        updated = updated.replace(before, after)
    if digest(updated) != OVERLAY_SHA256:
        raise ValueError("unexpected Trial1 overlay output")
    with new.open("xb") as stream:
        stream.write(updated)
    old.unlink()
    print(f"Trial1 core overlay: {SOURCE_SHA256} -> {OVERLAY_SHA256}: {new}")


def self_check(source_root: Path) -> None:
    original = (source_root / OLD_PATH).read_bytes()
    if digest(original) != SOURCE_SHA256:
        raise ValueError("self-check needs the pinned Trial1 core")
    with TemporaryDirectory() as temp:
        root = Path(temp)
        old = root / OLD_PATH
        old.parent.mkdir(parents=True)
        old.write_bytes(original)
        apply(root)
        assert not old.exists()
        assert digest((root / NEW_PATH).read_bytes()) == OVERLAY_SHA256
        changed_root = root / "changed"
        changed = changed_root / OLD_PATH
        changed.parent.mkdir(parents=True)
        changed.write_bytes(original + b"\n")
        try:
            apply(changed_root)
        except ValueError:
            pass
        else:
            raise AssertionError("a changed core preimage was accepted")
        assert not (changed_root / NEW_PATH).exists()
    print("Trial1 core overlay self-check passed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path, help="disposable OpenTitan source root")
    parser.add_argument("--self-check", action="store_true")
    args = parser.parse_args()
    if args.self_check:
        self_check(args.root)
    else:
        apply(args.root)
