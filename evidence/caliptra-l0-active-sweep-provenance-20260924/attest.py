#!/usr/bin/env python3
"""Read-only provenance check for the active copied-source Caliptra L0 sweep."""

import argparse
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
JTAG_TOP = SOURCE / "src/integration/tb/caliptra_top_tb.sv"
JTAG_ENTRY = "${CALIPTRA_ROOT}/src/integration/tb/caliptra_top_tb.sv"
JTAG_OLD = b".ListenPort     (63224)"
JTAG_NEW = b".ListenPort     (0)"
SELECTION = WORKTREE / "evidence/caliptra-icarus-l0-runner-20260923/selected_52.txt"


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


def verify_jtag_profile(case_root, name):
    command = json.loads((case_root / "compile.command.json").read_text())
    summary = json.loads((case_root / "summary.json").read_text())
    result = json.loads((case_root / name / "result.json").read_text())
    jtag = command["jtag_port_provenance"]
    if summary["jtag_port_provenance"] != jtag or result["jtag_port_provenance"] != jtag:
        raise RuntimeError(f"JTAG provenance differs among case records: {case_root}")
    source, copied = JTAG_TOP.read_bytes(), Path(jtag["copied_source"])
    before, after = Path(jtag["profile_before"]), Path(jtag["profile_after"])
    original_profile = before.read_text()
    argv = command["argv"]
    if (jtag["source"] != str(JTAG_TOP) or SOURCE in copied.parents
            or source.count(JTAG_OLD) != 1
            or copied.read_bytes() != source.replace(JTAG_OLD, JTAG_NEW)
            or jtag["listen_port_before"] != 63224 or jtag["listen_port_after"] != 0
            or original_profile.splitlines().count(JTAG_ENTRY) != 1
            or after.read_text() != original_profile.replace(JTAG_ENTRY, str(copied))
            or argv.count("-f") != 1 or argv.index("-f") + 1 >= len(argv)
            or argv[argv.index("-f") + 1] != str(after)
            or jtag["source_sha256_before"] != sha256(JTAG_TOP)
            or jtag["source_sha256_after"] != sha256(copied)
            or jtag["profile_sha256_before"] != sha256(before)
            or jtag["profile_sha256_after"] != sha256(after)):
        raise RuntimeError(f"JTAG top or compile filelist differs beyond port overlay: {case_root}")
    return {"copied_source": str(copied), "source_sha256": sha256(copied),
            "profile_sha256": sha256(after)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", type=Path, default=RUN,
                        help="completed sequential or parallel sweep output")
    run = parser.parse_args().run.resolve()
    parallel = (run / "cases").is_dir()
    case_root = lambda name: run / "cases" / name if parallel else run
    gcc = Path(str(PREFIX) + "-gcc")
    first_log = case_root("smoke_test_veer") / "smoke_test_veer/firmware.log"
    observed = first_log.read_text()
    if str(gcc) not in observed or str(PREFIX) + "-objcopy" not in observed:
        raise RuntimeError("active firmware log does not show the expected xPack GCC and objcopy")
    source_items = tree(SOURCE)
    copies = {}
    for name, (expected_path, expected_hash) in PATCHED.items():
        copy = case_root(name) / "firmware-source" / name
        copy_items = tree(copy)
        changed = [{"path": key, "source": source_items.get(key), "copy": copy_items.get(key)}
                   for key in sorted(source_items.keys() | copy_items.keys())
                   if source_items.get(key) != copy_items.get(key)]
        ok = (len(changed) == 1 and changed[0]["path"] == expected_path
              and changed[0]["source"]["type"] == "file"
              and changed[0]["copy"]["type"] == "file"
              and changed[0]["source"]["mode"] == changed[0]["copy"]["mode"]
              and changed[0]["copy"]["sha256"] == expected_hash)
        if parallel:
            summary = json.loads((case_root(name) / "summary.json").read_text())
            result = json.loads((case_root(name) / name / "result.json").read_text())
            overlay = summary["selected_firmware_overlays"][name]
            ok &= (summary["firmware_sources"][name] == str(copy)
                   and overlay["source_root"] == str(copy)
                   and overlay == result["selected_firmware_overlay"]
                   and result["firmware_source"] == str(copy))
        copies[name] = {"root": str(copy), "entries": len(copy_items),
                        "expected_only_patch": ok, "differences": changed}
    jtag_profiles = {}
    if parallel:
        names = SELECTION.read_text().splitlines()
        if len(names) != 52 or len(set(names)) != 52:
            raise RuntimeError("expected 52 distinct selected tests")
        jtag_profiles = {name: verify_jtag_profile(case_root(name), name) for name in names}
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
    qualification = ("diagnostic_reset_checker_source_ephemeral_jtag_port_overlay; not IEEE conformance"
                     if parallel else "diagnostic_reset_checker_source_overlay; not IEEE conformance")
    data = {"qualification": qualification,
            "run": str(run), "observed_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
            "script_sha256": sha256(__file__), "source": str(SOURCE),
            "source_commit": pin, "source_clean": clean, "source_entries_excluding_git": len(source_items),
            "copies": copies, "firmware_prefix": str(PREFIX),
            "toolchain": {"direct_make_commands": direct, "gcc_reported_subprograms": internal},
            "gcc_version": subprocess.check_output([str(gcc), "--version"], text=True).splitlines()[0],
            "observed_firmware_log": str(first_log),
            "all_expected_only_patch": all(item["expected_only_patch"] for item in copies.values())}
    if parallel:
        data["jtag_profiles"] = jtag_profiles
    print(json.dumps(data, indent=2, sort_keys=True))
    return 0 if clean and pin == "49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e" and data["all_expected_only_patch"] else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, ValueError, KeyError, IndexError,
            subprocess.CalledProcessError) as error:
        print(f"attestation failed: {error}", file=sys.stderr)
        sys.exit(2)
