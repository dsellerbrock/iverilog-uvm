#!/usr/bin/env python3
"""Read-only provenance check for the active copied-source Caliptra L0 sweep."""

import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import sys

HERE = Path(__file__).resolve().parent
WORKTREE = HERE.parents[1]
WORKSPACE = WORKTREE.parent
SOURCE = WORKSPACE / "caliptra-rtl"
RUN = WORKTREE / "evidence/caliptra-icarus-l0-diagnostic-combined-all-p1-20260924"
PREFIX = WORKSPACE / "evidence/caliptra-exact-riscv-toolchain-20260923/toolchain/bin/riscv-none-elf"
PATCHED = {
    "smoke_test_hw_config": (
        "src/integration/test_suites/smoke_test_hw_config/caliptra_isr.h",
        "aab3df95a2619a006022c229681777412bcb0ff2a7bc6e279bae299a51469c0a"),
    "smoke_test_hmac_errortrigger": (
        "src/integration/test_suites/smoke_test_hmac_errortrigger/smoke_test_hmac_errortrigger.c",
        "c56c7d49ce280090e20bfccdc58cbc4170c39d843d728d889f6e5f7c4210ff12"),
}


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def tree(root):
    entries = {}
    pending = [(root, Path())]
    while pending:
        directory, relative = pending.pop()
        for item in os.scandir(directory):
            if item.name == ".git":
                continue
            child = relative / item.name
            key = child.as_posix()
            info = item.stat(follow_symlinks=False)
            common = {"mode": oct(stat.S_IMODE(info.st_mode))}
            if stat.S_ISDIR(info.st_mode):
                entries[key] = {"type": "directory", **common}
                pending.append((Path(item.path), child))
            elif stat.S_ISLNK(info.st_mode):
                entries[key] = {"type": "symlink", "target": os.readlink(item.path), **common}
            elif stat.S_ISREG(info.st_mode):
                entries[key] = {"type": "file", "sha256": sha256(item.path), **common}
            else:
                entries[key] = {"type": "other", **common}
    return entries


def binary(path):
    path = Path(path).absolute()
    resolved = path.resolve(strict=True)
    before = resolved.stat()
    if not stat.S_ISREG(before.st_mode) or not before.st_mode & 0o111:
        raise RuntimeError(f"not an executable regular file: {path}")
    digest = sha256(resolved)
    after = resolved.stat()
    if (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns) != (
        after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns
    ):
        raise RuntimeError(f"binary changed during hash: {path}")
    return {"invoked_path": str(path), "resolved_path": str(resolved),
            "symlink_target": os.readlink(path) if path.is_symlink() else None,
            "sha256": digest, "size": before.st_size, "mtime_ns": before.st_mtime_ns,
            "mtime_utc": dt.datetime.fromtimestamp(before.st_mtime, dt.timezone.utc).isoformat()}


def main():
    gcc = Path(str(PREFIX) + "-gcc")
    first_log = RUN / "smoke_test_veer/firmware.log"
    observed = first_log.read_text()
    if str(gcc) not in observed or str(PREFIX) + "-objcopy" not in observed:
        raise RuntimeError("active firmware log does not show the expected xPack GCC and objcopy")
    source_items = tree(SOURCE)
    copies = {}
    for name, (expected_path, expected_hash) in PATCHED.items():
        copy = RUN / "firmware-source" / name
        copy_items = tree(copy)
        changed = [{"path": key, "source": source_items.get(key), "copy": copy_items.get(key)}
                   for key in sorted(source_items.keys() | copy_items.keys())
                   if source_items.get(key) != copy_items.get(key)]
        ok = (len(changed) == 1 and changed[0]["path"] == expected_path
              and changed[0]["source"]["type"] == "file"
              and changed[0]["copy"]["type"] == "file"
              and changed[0]["source"]["mode"] == changed[0]["copy"]["mode"]
              and changed[0]["copy"]["sha256"] == expected_hash)
        copies[name] = {"root": str(copy), "entries": len(copy_items),
                        "expected_only_patch": ok, "differences": changed}
    direct_names = ("gcc", "cpp", "as", "objcopy", "objdump", "size")
    if any(str(PREFIX) + "-" + name not in observed for name in direct_names):
        raise RuntimeError("active firmware log does not show every expected direct tool")
    direct = {suffix: binary(str(PREFIX) + "-" + suffix) for suffix in direct_names}
    internal = {}
    for program in ("cc1", "collect2", "as", "ld"):
        reported = subprocess.check_output(
            [str(gcc), f"-print-prog-name={program}"], text=True).strip()
        internal[program] = binary(reported)
    pin = subprocess.check_output(["git", "-C", str(SOURCE), "rev-parse", "HEAD"], text=True).strip()
    clean = not subprocess.check_output(
        ["git", "-C", str(SOURCE), "status", "--porcelain", "--untracked-files=all"],
        text=True).strip()
    data = {"qualification": "diagnostic_reset_checker_source_overlay; not IEEE conformance",
            "run": str(RUN), "observed_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
            "script_sha256": sha256(__file__), "source": str(SOURCE),
            "source_commit": pin, "source_clean": clean, "source_entries_excluding_git": len(source_items),
            "copies": copies, "firmware_prefix": str(PREFIX),
            "toolchain": {"direct_make_commands": direct, "gcc_reported_subprograms": internal},
            "gcc_version": subprocess.check_output([str(gcc), "--version"], text=True).splitlines()[0],
            "observed_firmware_log": str(first_log),
            "all_expected_only_patch": all(item["expected_only_patch"] for item in copies.values())}
    print(json.dumps(data, indent=2, sort_keys=True))
    return 0 if clean and pin == "49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e" and data["all_expected_only_patch"] else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"attestation failed: {error}", file=sys.stderr)
        sys.exit(2)
