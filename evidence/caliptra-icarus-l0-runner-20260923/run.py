#!/usr/bin/env python3
"""Run the pinned Caliptra L0 selection on Icarus, one case or all 52."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import signal
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
WORKTREE = HERE.parents[1]
WORKSPACE = WORKTREE.parent
SOURCE = WORKSPACE / "caliptra-rtl"
PROFILE = WORKTREE / "evidence/caliptra-l0-icarus-baseline-20260923/caliptra_top_tb_icarus_profile.vf"
CC = WORKTREE / "local-install/bin/iverilog"
IVL = WORKTREE / "local-install/lib/ivl/ivl"
TARGET = WORKTREE / "local-install/lib/ivl/vvp.tgt"
VVP = WORKTREE / "local-install/bin/vvp"
GCC_PREFIX = WORKSPACE / "evidence/caliptra-exact-riscv-toolchain-20260923/toolchain/bin/riscv-none-elf"
JTAGDPI = WORKTREE / "evidence/caliptra-jtagdpi-native-20260923/jtagdpi.vpi"
JTAGDPI_MANIFEST = JTAGDPI.parent / "result.json"
VECTORS = WORKTREE / "evidence/caliptra-native-vectors-20260923"
RESET_OVERLAY = WORKTREE / "evidence/caliptra-l0-timezero-reset-overlay-20260923/prepare_overlay.py"
RELEASE_PATCHES = WORKTREE / "docs/conformance/release_overlays/caliptra"
CHECKER_SOURCE = SOURCE / "src/integration/asserts/caliptra_top_sva.sv"
CHECKER_PATCH = RELEASE_PATCHES / "l0_pure_checker_functions.patch"
CHECKER_SOURCE_SHA256 = "6bd2ade137a90c0701aab28951ba6f8918724e0467c21756b0c308e6e9081c89"
CHECKER_PATCH_SHA256 = "b3cdf87a5c819820fbb02d8b183e6209ab7f5fdb062228046ba27cdaae9dbd19"
CHECKER_PATCHED_SHA256 = "6e67d67966b030931ec222aacfd0863086c7d35b5e916acd5f358a90ed538654"
JTAG_TOP = SOURCE / "src/integration/tb/caliptra_top_tb.sv"
JTAG_TOP_SHA256 = "c212c32da99e90cd3991da65e653998cac3e945d7479abfd640b9d82f47659f9"
JTAG_EPHEMERAL_TOP_SHA256 = "df8d51cc7ad84000288f5d7c19641f433d59ae213314fa81b9d9e5f8a6b76c6e"
FIRMWARE_PATCHES = {
    "smoke_test_hw_config": ("hw_config_inline_c11.patch",
                             "src/integration/test_suites/smoke_test_hw_config/caliptra_isr.h"),
    "smoke_test_hmac_errortrigger": ("hmac_errortrigger_stdlib.patch",
                                     "src/integration/test_suites/smoke_test_hmac_errortrigger/smoke_test_hmac_errortrigger.c"),
}
FIRMWARE_HASHES = {
    "smoke_test_hw_config": (
        "36aa05fef48b9358556ffd67bcfa9c6f6e62dcbeee20607ef3fb8cb36f664a9c",
        "db796220e45fd7bfcb21906bd167ee49d89611d83d2db4d8d41f764e5898b1c8",
        "aab3df95a2619a006022c229681777412bcb0ff2a7bc6e279bae299a51469c0a"),
    "smoke_test_hmac_errortrigger": (
        "ed5e27f4b6806a22373943030d31b84396535f21b8d6ef96b8d527ef4efed621",
        "c5c056fbbc10950f61bb5295e73f2c410ff32bdea1350d73db6e82d590623edb",
        "c56c7d49ce280090e20bfccdc58cbc4170c39d843d728d889f6e5f7c4210ff12"),
}
PIN = "49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e"
ADAMS_PIN = "b77e3d899e828d626cfc2a0d26a6b5704cc121e0"
JTAGDPI_SHA256 = "434b73346370213147b12a265a1b2d453ce05496035d854a4fe87ac3dee23c16"
SEED_HASHES = {
    "program.hex": "87c35ddfd7da3aecaefcfede18ca09cdd196668a3887f84b2378775093650657",
    "dccm.hex": "b73e91a51835232d301b0c07fd17510d862819e4809c0ff1e558d8cdecd73b98",
    "iccm.hex": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "mailbox.hex": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
}
EXCLUDE = re.compile(r"^smoke_test_(?:clk_gating|cg_wdt|mbox_cg|kv_cg|doe_cg|dma|wdt_rst)")
YAML_ENTRY = re.compile(r"\s*-\s+\.\./test_suites/([^/]+)/([^/]+)\.yml\s*")
FINISH = re.compile(r"Finished : minstret = (\d+), mcycle = (\d+)")
TRACE = re.compile(r"^\s*\d+\s*:\s*#\d+", re.MULTILINE)
BAD = re.compile(r"\b(?:UVM_)?(?:ERROR|FATAL)\b|\bassert(?:ion)?\b[^\n]*\b(?:fail(?:ed|ure)?|error)\b", re.IGNORECASE)
MISSING_DPI = re.compile(r"DPI error: symbol '.+' not found in any loaded DPI library", re.IGNORECASE)
JTAG_SERVER_ERROR = re.compile(r"(?m)^jtag0: (?:Failed to|Unable to|Socket read failed|Error while|Client disappeared)")
SAMPLING_WARNING = re.compile(r"cannot be sampled in the Preponed region")
VECTOR_OUTPUTS = {
    "ecc_secp384r1.exe": "ecc_secp384r1.exe",
    "test_dilithium5": "test_dilithium5",
    "doe_test_gen.py": "doe_test_gen.py",
    "sha256_wntz_test_gen.py": "sha256_wntz_test_gen.py",
    "smoke_test_mldsa_vector.hex": "smoke_test_mldsa_vector.hex",
    "ml-kem/native_mlkem": "native_mlkem",
    "ml-kem/random_test_ml_kem.py": "random_test_ml_kem.py",
}


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def runtime_diagnostics_ok(sim):
    return not (BAD.search(sim) or MISSING_DPI.search(sim) or JTAG_SERVER_ERROR.search(sim))


def git(*args):
    return subprocess.check_output(["git", "-C", str(SOURCE), *args], text=True).strip()


def verify_sources():
    if git("rev-parse", "HEAD") != PIN:
        raise RuntimeError("Caliptra source is not the pinned release")
    if git("status", "--porcelain", "--untracked-files=all"):
        raise RuntimeError("Caliptra source has tracked or untracked changes")
    adams = SOURCE / "submodules/adams-bridge"
    gitlink = git("ls-tree", PIN, "submodules/adams-bridge")
    if gitlink != f"160000 commit {ADAMS_PIN}\tsubmodules/adams-bridge":
        raise RuntimeError("Pinned Caliptra tree does not reference expected Adams Bridge")
    submodule_status = subprocess.check_output(
        ["git", "-C", str(SOURCE), "submodule", "status", "--", "submodules/adams-bridge"], text=True
    ).rstrip("\n")
    if not submodule_status.startswith(f" {ADAMS_PIN} "):
        raise RuntimeError("Adams Bridge is uninitialized or differs from the pinned gitlink")
    if subprocess.check_output(["git", "-C", str(adams), "rev-parse", "HEAD"], text=True).strip() != ADAMS_PIN:
        raise RuntimeError("Adams Bridge HEAD is not pinned")
    if subprocess.check_output(["git", "-C", str(adams), "status", "--porcelain", "--untracked-files=all"], text=True).strip():
        raise RuntimeError("Adams Bridge has tracked or untracked changes")
    return {"caliptra_commit": PIN, "caliptra_clean": True,
            "adams_bridge_commit": ADAMS_PIN, "adams_bridge_clean": True}


def prepare_firmware_overlays(output, run_cases):
    roots = {case["name"]: SOURCE for case in run_cases}
    applied = {}
    for name in roots:
        if name not in FIRMWARE_PATCHES:
            continue
        copied = output / "firmware-source" / name
        shutil.copytree(SOURCE, copied, symlinks=True,
                        ignore=shutil.ignore_patterns(".git"))
        roots[name] = copied
        patch_name, relative = FIRMWARE_PATCHES[name]
        patch_file = RELEASE_PATCHES / patch_name
        target = copied / relative
        before = sha256(target)
        expected_patch, expected_before, expected_after = FIRMWARE_HASHES[name]
        if sha256(patch_file) != expected_patch or before != expected_before:
            raise RuntimeError(f"Frozen firmware patch or pinned source hash mismatch: {name}")
        command = ["patch", "--batch", "--fuzz=0", "-p1", "-d", str(copied),
                   "-i", str(patch_file)]
        subprocess.run([*command[:1], "--dry-run", *command[1:]], check=True,
                       capture_output=True, text=True)
        subprocess.run(command, check=True, capture_output=True, text=True)
        after = sha256(target)
        if after != expected_after:
            raise RuntimeError(f"Firmware patch produced unexpected source: {name}")
        applied[name] = {"source_root": str(copied),
                         "patch": str(patch_file), "patch_sha256": expected_patch,
                         "source": relative, "source_sha256_before": before,
                         "source_sha256_after": after}
    return roots, applied


def verify_firmware_overlays(roots, applied):
    for name, root in roots.items():
        if name not in FIRMWARE_PATCHES:
            if root != SOURCE or name in applied:
                raise RuntimeError(f"Unpatched firmware case did not use pinned source: {name}")
            continue
        overlay = applied[name]
        if root != Path(overlay["source_root"]):
            raise RuntimeError(f"Firmware source root changed: {name}")
        patch_name, _ = FIRMWARE_PATCHES[name]
        if sha256(RELEASE_PATCHES / patch_name) != overlay["patch_sha256"]:
            raise RuntimeError(f"Selected firmware patch changed: {name}")
        for target_name, (_, relative) in FIRMWARE_PATCHES.items():
            expected = (overlay["source_sha256_after"] if target_name == name
                        else FIRMWARE_HASHES[target_name][1])
            if sha256(root / relative) != expected:
                raise RuntimeError(f"Firmware source isolation failed: {name}, {target_name}")


def prepare_checker_source_overlay(profile):
    if sha256(CHECKER_SOURCE) != CHECKER_SOURCE_SHA256 or sha256(CHECKER_PATCH) != CHECKER_PATCH_SHA256:
        raise RuntimeError("Pinned checker source or frozen overlay patch hash mismatch")
    overlay_dir = Path(tempfile.mkdtemp(prefix="caliptra-l0-checker-", dir="/tmp"))
    relative = Path("src/integration/asserts/caliptra_top_sva.sv")
    patched = overlay_dir / relative
    patched.parent.mkdir(parents=True)
    shutil.copy2(CHECKER_SOURCE, patched)
    command = ["patch", "--batch", "--fuzz=0", "-p1", "-d", str(overlay_dir),
               "-i", str(CHECKER_PATCH)]
    subprocess.run([*command[:1], "--dry-run", *command[1:]], check=True,
                   capture_output=True, text=True)
    subprocess.run(command, check=True, capture_output=True, text=True)
    if sha256(patched) != CHECKER_PATCHED_SHA256:
        raise RuntimeError("Checker overlay produced unexpected source")
    original_entry = "${CALIPTRA_ROOT}/" + str(relative)
    source_list = profile.read_text()
    if source_list.splitlines().count(original_entry) != 1:
        raise RuntimeError("Checker source must occur exactly once in the compile profile")
    overlay_profile = overlay_dir / profile.name
    overlay_profile.write_text(source_list.replace(original_entry, str(patched)))
    return overlay_profile, patched


def prepare_ephemeral_jtag_port(profile):
    if sha256(JTAG_TOP) != JTAG_TOP_SHA256:
        raise RuntimeError("Pinned JTAG top source hash mismatch")
    source = JTAG_TOP.read_bytes()
    old = b".ListenPort     (63224)"
    if source.count(old) != 1:
        raise RuntimeError("Expected exactly one pinned JTAG ListenPort setting")
    overlay_dir = Path(tempfile.mkdtemp(prefix="caliptra-l0-jtag-port-", dir="/tmp"))
    copied = overlay_dir / "caliptra_top_tb.sv"
    copied.write_bytes(source.replace(old, b".ListenPort     (0)"))
    if sha256(copied) != JTAG_EPHEMERAL_TOP_SHA256:
        raise RuntimeError("Ephemeral JTAG port overlay produced unexpected source")
    original_entry = "${CALIPTRA_ROOT}/src/integration/tb/caliptra_top_tb.sv"
    source_list = profile.read_text()
    if source_list.splitlines().count(original_entry) != 1:
        raise RuntimeError("JTAG top source must occur exactly once in the compile profile")
    overlay_profile = overlay_dir / profile.name
    overlay_profile.write_text(source_list.replace(original_entry, str(copied)))
    provenance = {
        "source": str(JTAG_TOP), "source_sha256_before": JTAG_TOP_SHA256,
        "copied_source": str(copied), "source_sha256_after": sha256(copied),
        "listen_port_before": 63224, "listen_port_after": 0,
        "profile_before": str(profile), "profile_sha256_before": sha256(profile),
        "profile_after": str(overlay_profile), "profile_sha256_after": sha256(overlay_profile),
    }
    return overlay_profile, copied, provenance


def verify_jtagdpi():
    recorded = json.loads(JTAGDPI_MANIFEST.read_text()).get("sha256", {}).get("jtagdpi_bundle")
    if recorded != JTAGDPI_SHA256 or sha256(JTAGDPI) != JTAGDPI_SHA256:
        raise RuntimeError("Recorded native JTAG DPI bundle hash mismatch")
    return JTAGDPI_SHA256


def preflight_vectors():
    if sys.platform != "darwin" or platform.machine() != "arm64":
        raise RuntimeError("Native vector preparation currently requires macOS ARM64")
    executables = {name: shutil.which(name) for name in ("brew", "clang", "make", "openssl", "xxd", "python3.12")}
    if any(path is None for path in executables.values()):
        raise RuntimeError(f"Missing native vector tools: {[name for name, path in executables.items() if path is None]}")
    roots = {name: Path(subprocess.check_output([executables["brew"], "--prefix", name], text=True).strip())
             for name in ("openssl@3", "mbedtls@3")}
    inputs = {
        "native_mlkem.c": VECTORS / "native_mlkem.c",
        "random_test_ml_kem.py": VECTORS / "random_test_ml_kem.py",
        "check_native_mlkem.py": VECTORS / "check_native_mlkem.py",
        "check_native_mldsa.py": VECTORS / "check_native_mldsa.py",
        "stage_mldsa.py": VECTORS / "stage_mldsa.py",
        "stage_sha256_wntz.py": VECTORS / "stage_sha256_wntz.py",
        "ecc_secp384r1.c": SOURCE / "src/ecc/tb/ecc_secp384r1.c",
        "doe_test_gen.py": SOURCE / "src/doe/tb/doe_test_gen.py",
        "sha256_wntz_test_gen.py": SOURCE / "src/sha256/tb/sha256_wntz_test_gen.py",
        "test_dilithium.c": SOURCE / "submodules/adams-bridge/src/abr_top/uvmf/Dilithium_ref/dilithium/ref/test/test_dilithium.c",
        "smoke_test_mldsa_vector.hex": SOURCE / "src/mldsa/tb/smoke_test_mldsa_vector.hex",
        "openssl_libcrypto": roots["openssl@3"] / "lib/libcrypto.dylib",
        "mbedtls_libcrypto": roots["mbedtls@3"] / "lib/libmbedcrypto.dylib",
        "mbedtls_libx509": roots["mbedtls@3"] / "lib/libmbedx509.dylib",
        "mbedtls_libtls": roots["mbedtls@3"] / "lib/libmbedtls.dylib",
    }
    if any(not path.is_file() for path in inputs.values()):
        raise RuntimeError(f"Missing native vector inputs: {[name for name, path in inputs.items() if not path.is_file()]}")
    return {"executables": executables, "roots": {name: str(path) for name, path in roots.items()},
            "tool_sha256": {name: sha256(Path(path)) for name, path in executables.items()},
            "input_sha256": {name: sha256(path) for name, path in inputs.items()}}


def prepare_vectors(output, timeout, env, preflight):
    native = output / "native_vectors"
    native.mkdir()
    openssl_root = Path(preflight["roots"]["openssl@3"])
    mbedtls_root = Path(preflight["roots"]["mbedtls@3"])
    adams = SOURCE / "submodules/adams-bridge"
    ref = native / "dilithium-ref"
    shutil.copytree(adams / "src/abr_top/uvmf/Dilithium_ref/dilithium/ref", ref)
    (ref / "test/test_dilithium5").unlink()  # copied Linux ELF
    commands = [
        [preflight["executables"]["clang"], "-Wall", "-Wextra", "-Werror", "-O2",
         f"-I{openssl_root / 'include'}", str(VECTORS / "native_mlkem.c"),
         f"-L{openssl_root / 'lib'}", "-lcrypto", "-o", str(native / "native_mlkem")],
        [preflight["executables"]["clang"], "-O2", f"-I{mbedtls_root / 'include'}",
         str(SOURCE / "src/ecc/tb/ecc_secp384r1.c"), f"-L{mbedtls_root / 'lib'}",
         "-lmbedtls", "-lmbedx509", "-lmbedcrypto", "-o", str(native / "ecc_secp384r1.exe")],
        [sys.executable, str(VECTORS / "stage_mldsa.py"),
         str(adams / "src/abr_top/uvmf/Dilithium_ref/dilithium/ref/test/test_dilithium.c"),
         str(ref / "test/test_dilithium.c")],
        [preflight["executables"]["make"], "-C", str(ref),
         f"CC={preflight['executables']['clang']}", "test/test_dilithium5"],
        [sys.executable, str(VECTORS / "stage_sha256_wntz.py"),
         str(SOURCE / "src/sha256/tb/sha256_wntz_test_gen.py"),
         str(native / "sha256_wntz_test_gen.py")],
        [sys.executable, str(VECTORS / "check_native_mlkem.py"), str(adams), str(native / "native_mlkem")],
        [sys.executable, str(VECTORS / "check_native_mldsa.py"), str(adams), str(ref / "test/test_dilithium5")],
    ]
    for index, command in enumerate(commands):
        code, timed_out = invoke(command, native, env, native / f"step_{index}.log", timeout)
        if code != 0:
            raise RuntimeError(f"Native vector preparation step {index} failed (exit={code}, timeout={timed_out})")
    files = {
        "ecc_secp384r1.exe": native / "ecc_secp384r1.exe",
        "test_dilithium5": ref / "test/test_dilithium5",
        "doe_test_gen.py": SOURCE / "src/doe/tb/doe_test_gen.py",
        "sha256_wntz_test_gen.py": native / "sha256_wntz_test_gen.py",
        "smoke_test_mldsa_vector.hex": SOURCE / "src/mldsa/tb/smoke_test_mldsa_vector.hex",
        "native_mlkem": native / "native_mlkem",
        "random_test_ml_kem.py": VECTORS / "random_test_ml_kem.py",
    }
    hashes = {name: sha256(path) for name, path in files.items()}
    (native / "result.json").write_text(json.dumps({"preflight": preflight, "commands": commands,
                                                     "staged_sha256": hashes}, indent=2) + "\n")
    return files, hashes


def stage_vectors(run, files, hashes, preflight):
    (run / "ml-kem/tv").mkdir(parents=True)
    bin_dir = run / ".bin"
    bin_dir.mkdir()
    for relative, name in VECTOR_OUTPUTS.items():
        target = run / relative
        shutil.copy2(files[name], target)
        if sha256(target) != hashes[name]:
            raise RuntimeError(f"Native vector stage hash mismatch: {relative}")
    for alias, path in (("python", preflight["executables"]["python3.12"]),
                        ("python3.9", preflight["executables"]["python3.12"]),
                        ("openssl", preflight["executables"]["openssl"]),
                        ("xxd", preflight["executables"]["xxd"])):
        (bin_dir / alias).symlink_to(path)
    return {relative: hashes[name] for relative, name in VECTOR_OUTPUTS.items()}


def cases():
    yaml = SOURCE / "src/integration/stimulus/L0_regression.yml"
    selected = []
    for line in yaml.read_text().splitlines():
        match = YAML_ENTRY.fullmatch(line)
        if match and not EXCLUDE.match(match.group(1)):
            name = match.group(2)
            case_yaml = SOURCE / "src/integration/test_suites" / match.group(1) / f"{name}.yml"
            case_text = case_yaml.read_text()
            seeds = re.findall(r"(?m)^seed:\s*(\S+)\s*$", case_text)
            testnames = re.findall(r"(?m)^testname:\s*(\S+)\s*$", case_text)
            if len(seeds) != 1 or len(testnames) != 1:
                raise RuntimeError(f"Expected one seed and testname in {case_yaml}")
            seed = 1 if seeds[0] == "${PLAYBOOK_RANDOM_SEED}" else int(seeds[0])
            plusargs = re.findall(r"(?m)^\s*-\s+(\+\S+)\s*$", case_text)
            selected.append({"name": name, "yaml": str(case_yaml), "yaml_sha256": sha256(case_yaml),
                             "yaml_testname": testnames[0], "seed": seed, "plusargs": plusargs})
    found = {case["name"] for case in selected}
    if len(selected) != 52 or len(found) != 52:
        raise RuntimeError(f"Expected 52 distinct released L0 tests, found {len(selected)} rows / {len(found)} names")
    return selected


def invoke(argv, cwd, env, log, timeout):
    with log.open("w") as stream:
        process = subprocess.Popen(argv, cwd=cwd, env=env, stdout=stream,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            return process.wait(timeout=timeout), False
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            except PermissionError:
                process.terminate()
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                except PermissionError:
                    process.kill()
                process.wait()
            return None, True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--list", action="store_true", help="print the 52 names without building or running")
    parser.add_argument("--all", action="store_true", help="run all 52; default is smoke_test_veer only")
    parser.add_argument("--case", help="run one released L0 test by name")
    parser.add_argument("--commercial-unsafe", action="store_true",
                        help="opt into nonstandard Icarus compatibility mode")
    parser.add_argument("--reset-overlay", action="store_true",
                        help="use a hash-guarded copied BFM to diagnose the time-zero reset race")
    parser.add_argument("--checker-source-overlay", action="store_true",
                        help="use a hash-guarded copied checker with pure KV/MLDSA predicates")
    parser.add_argument("--ephemeral-jtag-port", action="store_true",
                        help="use a hash-guarded copied top with JTAG ListenPort 0")
    parser.add_argument("--output", type=Path, help="new isolated results directory")
    parser.add_argument("--timeout", type=int, default=900, help="seconds per command")
    args = parser.parse_args()
    selected = cases()
    if args.list:
        print("\n".join(case["name"] for case in selected))
        return 0
    if args.output is None:
        parser.error("--output is required for a run")
    if args.all and args.case:
        parser.error("--all and --case cannot be combined")
    if args.case and args.case not in {case["name"] for case in selected}:
        parser.error(f"unknown released L0 test: {args.case}")
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    run_cases = selected if args.all else [next(case for case in selected
                                                if case["name"] == (args.case or "smoke_test_veer"))]
    source_before = verify_sources()
    jtagdpi_hash = verify_jtagdpi()
    vector_preflight = preflight_vectors()
    if args.reset_overlay and not args.commercial_unsafe:
        parser.error("--reset-overlay requires --commercial-unsafe")
    if args.checker_source_overlay and not args.commercial_unsafe:
        parser.error("--checker-source-overlay requires --commercial-unsafe")
    if args.ephemeral_jtag_port and not args.commercial_unsafe:
        parser.error("--ephemeral-jtag-port requires --commercial-unsafe")
    profile = PROFILE
    bfm_overlay = None
    checker_overlay = None
    jtag_top_overlay = None
    jtag_port_provenance = None
    if args.reset_overlay:
        overlay_dir = Path(tempfile.mkdtemp(prefix="caliptra-l0-reset-", dir="/tmp"))
        subprocess.run([sys.executable, str(RESET_OVERLAY), str(overlay_dir)],
                       check=True, stdout=subprocess.DEVNULL)
        profile = overlay_dir / PROFILE.name
        bfm_overlay = overlay_dir / "caliptra_top_tb_soc_bfm.sv"
    if args.checker_source_overlay:
        profile, checker_overlay = prepare_checker_source_overlay(profile)
    if args.ephemeral_jtag_port:
        profile, jtag_top_overlay, jtag_port_provenance = prepare_ephemeral_jtag_port(profile)
    checker_overlay_provenance = ({
        "source": str(CHECKER_SOURCE),
        "source_sha256_before": sha256(CHECKER_SOURCE),
        "patch": str(CHECKER_PATCH),
        "patch_sha256": sha256(CHECKER_PATCH),
        "copied_source": str(checker_overlay),
        "source_sha256_after": sha256(checker_overlay),
    } if checker_overlay else None)
    fingerprints_before = {"runner": sha256(Path(__file__)),
                           "compiler": sha256(CC), "ivl": sha256(IVL),
                           "vvp_target": sha256(TARGET), "vvp": sha256(VVP),
                           "profile": sha256(profile), "jtagdpi": jtagdpi_hash}
    if bfm_overlay:
        fingerprints_before["reset_bfm_overlay"] = sha256(bfm_overlay)
    if checker_overlay:
        fingerprints_before["checker_sva_overlay"] = sha256(checker_overlay)
        fingerprints_before["checker_patch"] = sha256(CHECKER_PATCH)
    if jtag_top_overlay:
        fingerprints_before["jtag_top_source"] = sha256(JTAG_TOP)
        fingerprints_before["jtag_top_overlay"] = sha256(jtag_top_overlay)
        fingerprints_before["jtag_profile_input"] = sha256(Path(jtag_port_provenance["profile_before"]))
    output = args.output.resolve()
    if SOURCE.resolve() == output or SOURCE.resolve() in output.parents:
        raise RuntimeError("Output directory must not be inside the pinned Caliptra source")
    output.mkdir(parents=True, exist_ok=False)
    env = os.environ.copy()
    env.update(CALIPTRA_ROOT=str(SOURCE), CALIPTRA_PRIM_ROOT=str(SOURCE / "src/caliptra_prim_generic"),
               CALIPTRA_PRIM_MODULE_PREFIX="caliptra_prim_generic",
               CALIPTRA_AXI4PC_DIR=str(SOURCE / "src/integration/tb"))
    compiler = [str(CC), "-g2017", "-gassertions"]
    if args.commercial_unsafe:
        compiler.append("-gcommercial-unsafe")
    compiler += ["-s", "caliptra_top_tb", "-D", "RV_OPENSOURCE", "-D", "CLP_ASSERT_ON",
                 "-D", "CALIPTRA_INTERNAL_TRNG",
                 "-f", str(profile), "-o", str(output / "caliptra_top_tb.vvp")]
    diagnostic_overlays = [name for enabled, name in (
        (args.reset_overlay, "reset"),
        (args.checker_source_overlay, "checker_source"),
        (args.ephemeral_jtag_port, "ephemeral_jtag_port"),
    ) if enabled]
    qualification = (f"diagnostic_{'_'.join(diagnostic_overlays)}_overlay"
                     if diagnostic_overlays else
                     "nonstandard_compatibility" if args.commercial_unsafe else "strict")
    compiler_flags = compiler[1:]
    (output / "compile.command.json").write_text(json.dumps({
        "argv": compiler, "source_commit": PIN, "fingerprints": fingerprints_before,
        "commercial_unsafe": args.commercial_unsafe,
        "reset_overlay": args.reset_overlay,
        "checker_source_overlay": args.checker_source_overlay,
        "checker_overlay_provenance": checker_overlay_provenance,
        "ephemeral_jtag_port": args.ephemeral_jtag_port,
        "jtag_port_provenance": jtag_port_provenance,
        "qualification": qualification, "compiler_flags": compiler_flags,
        "expected_smoke_readmemh_sha256": SEED_HASHES, "jtagdpi_bundle_sha256": jtagdpi_hash,
        "vector_preflight": vector_preflight,
    }, indent=2) + "\n")
    compile_error = None
    try:
        compile_code, compile_timeout = invoke(compiler, output, env, output / "compile.log", args.timeout)
    except OSError as exc:
        compile_code, compile_timeout, compile_error = 127, False, str(exc)
    sampling_warnings = len(SAMPLING_WARNING.findall((output / "compile.log").read_text(errors="replace")))
    if compile_code != 0:
        source_after = None
        source_error = None
        try:
            source_after = verify_sources()
        except (OSError, RuntimeError, subprocess.CalledProcessError) as exc:
            source_error = str(exc)
        (output / "summary.json").write_text(json.dumps({
            "qualification": qualification, "commercial_unsafe": args.commercial_unsafe,
            "reset_overlay": args.reset_overlay,
            "checker_source_overlay": args.checker_source_overlay,
            "checker_overlay_provenance": checker_overlay_provenance,
            "ephemeral_jtag_port": args.ephemeral_jtag_port,
            "jtag_port_provenance": jtag_port_provenance,
            "compiler_flags": compiler_flags, "selected": 52, "attempted": 0,
            "passed": 0, "failed": 0, "unrun": 52, "status": "BLOCKED",
            "blocker": "top compile timed out" if compile_timeout else "top compile failed",
            "compile_exit": compile_code, "compile_timeout": compile_timeout,
            "compile_sampling_warnings": sampling_warnings,
            "compile_error": compile_error,
            "source_integrity_before": source_before, "source_integrity_after": source_after,
            "source_integrity_error": source_error,
        }, indent=2) + "\n")
        print(f"compile failed: exit={compile_code}, timeout={compile_timeout}; see {output / 'compile.log'}", file=sys.stderr)
        return 1
    try:
        vector_files, vector_hashes = prepare_vectors(output, args.timeout, env, vector_preflight)
        firmware_roots, firmware_overlays = prepare_firmware_overlays(output, run_cases)
    except (OSError, RuntimeError, subprocess.CalledProcessError) as exc:
        (output / "summary.json").write_text(json.dumps({
            "qualification": qualification, "commercial_unsafe": args.commercial_unsafe,
            "reset_overlay": args.reset_overlay,
            "checker_source_overlay": args.checker_source_overlay,
            "checker_overlay_provenance": checker_overlay_provenance,
            "ephemeral_jtag_port": args.ephemeral_jtag_port,
            "jtag_port_provenance": jtag_port_provenance,
            "selected": 52, "attempted": 0, "passed": 0, "failed": 0, "unrun": 52,
            "status": "BLOCKED", "blocker": f"run preparation failed: {exc}",
            "source_integrity_before": source_before,
        }, indent=2) + "\n")
        print(f"run preparation failed: {exc}", file=sys.stderr)
        return 1
    failed = 0
    for case in run_cases:
        name = case["name"]
        firmware_root = firmware_roots[name]
        run = output / name
        run.mkdir()
        firmware_command = ["make", "-f", str(SOURCE / "tools/scripts/Makefile"),
                            f"TESTNAME={name}", f"GCC_PREFIX={GCC_PREFIX}",
                            "CALIPTRA_INTERNAL_TRNG=1", f"PLAYBOOK_RANDOM_SEED={case['seed']}",
                            "BUILD_CFLAGS=-std=gnu11 -O2", "program.hex"]
        firmware_env = env.copy()
        firmware_env["CALIPTRA_ROOT"] = str(firmware_root)
        firmware_env["CALIPTRA_PRIM_ROOT"] = str(firmware_root / "src/caliptra_prim_generic")
        firmware_code, firmware_timeout = invoke(firmware_command, run, firmware_env,
                                                  run / "firmware.log", args.timeout)
        images = {name: run / name for name in SEED_HASHES}
        missing_images = [name for name, path in images.items() if not path.is_file()]
        image_hashes = {name: sha256(path) if path.is_file() else None
                        for name, path in images.items()}
        expected_match = image_hashes == SEED_HASHES if name == "smoke_test_veer" else None
        image_ok = (not missing_images and images["program.hex"].stat().st_size > 0
                    and expected_match is not False)
        sim_command = [str(VVP), "-d", str(JTAGDPI), "-n", str(output / "caliptra_top_tb.vvp"),
                       "+CLP_REGRESSION", "+CLP_BUS_LOGS", *case["plusargs"]]
        sim_code, sim_timeout = (None, False)
        staged_hashes = None
        vector_integrity_ok = False
        if firmware_code == 0 and image_ok:
            staged_hashes = stage_vectors(run, vector_files, vector_hashes, vector_preflight)
            sim_env = env.copy()
            sim_env["PATH"] = f"{run / '.bin'}:{env['PATH']}"
            sim_code, sim_timeout = invoke(sim_command, run, sim_env, run / "sim.log", args.timeout)
            vector_integrity_ok = all(sha256(run / relative) == digest
                                      for relative, digest in staged_hashes.items())
        sim = (run / "sim.log").read_text(errors="replace") if (run / "sim.log").exists() else ""
        trace = (run / "exec.log").read_text(errors="replace") if (run / "exec.log").exists() else ""
        finish = FINISH.search(sim)
        retired = int(finish.group(1)) if finish else 0
        cycles = int(finish.group(2)) if finish else 0
        commits = len(TRACE.findall(trace))
        missing_dpi = len(MISSING_DPI.findall(sim))
        jtag_server_errors = len(JTAG_SERVER_ERROR.findall(sim))
        passed = (firmware_code == 0 and image_ok and sim_code == 0 and not sim_timeout
                  and vector_integrity_ok
                  and sim.count("* TESTCASE PASSED") == 1 and "TESTCASE FAILED" not in sim
                  and runtime_diagnostics_ok(sim)
                  and sampling_warnings == 0
                  and retired > 0 and cycles > 0 and commits > 0)
        result = {"test": name, "passed": passed, "firmware_command": firmware_command,
                  "firmware_source": str(firmware_root),
                  "selected_firmware_overlay": firmware_overlays.get(name),
                  "released_case": case,
                  "qualification": qualification, "commercial_unsafe": args.commercial_unsafe,
                  "reset_overlay": args.reset_overlay,
                  "checker_source_overlay": args.checker_source_overlay,
                  "checker_overlay_provenance": checker_overlay_provenance,
                  "ephemeral_jtag_port": args.ephemeral_jtag_port,
                  "jtag_port_provenance": jtag_port_provenance,
                  "compiler_flags": compiler_flags, "jtagdpi_bundle_sha256": jtagdpi_hash,
                  "firmware_exit": firmware_code, "firmware_timeout": firmware_timeout,
                  "readmemh_sha256": image_hashes, "missing_readmemh": missing_images,
                  "expected_smoke_readmemh_match": expected_match,
                  "native_vector_sha256": staged_hashes,
                  "native_vector_integrity_ok": vector_integrity_ok,
                  "program_sha256": image_hashes["program.hex"],
                  "sim_command": sim_command if firmware_code == 0 and image_ok else None,
                  "sim_exit": sim_code, "sim_timeout": sim_timeout,
                  "pass_markers": sim.count("* TESTCASE PASSED"),
                  "failed_markers": sim.count("TESTCASE FAILED"),
                  "bad_diagnostics": len(BAD.findall(sim)),
                  "missing_dpi_symbols": missing_dpi,
                  "jtag_server_errors": jtag_server_errors,
                  "compile_sampling_warnings": sampling_warnings,
                  "retired_instructions": retired, "cycles": cycles, "trace_commits": commits}
        (run / "result.json").write_text(json.dumps(result, indent=2) + "\n")
        print(f"{'PASS' if passed else 'FAIL'} {name}: retired={retired} trace={commits}", flush=True)
        failed += not passed
    source_after = None
    source_error = None
    try:
        source_after = verify_sources()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as exc:
        source_error = str(exc)
    fingerprints_after = {"runner": sha256(Path(__file__)),
                          "compiler": sha256(CC), "ivl": sha256(IVL),
                          "vvp_target": sha256(TARGET), "vvp": sha256(VVP),
                          "profile": sha256(profile), "jtagdpi": sha256(JTAGDPI)}
    if bfm_overlay:
        fingerprints_after["reset_bfm_overlay"] = sha256(bfm_overlay)
    if checker_overlay:
        fingerprints_after["checker_sva_overlay"] = sha256(checker_overlay)
        fingerprints_after["checker_patch"] = sha256(CHECKER_PATCH)
    if jtag_top_overlay:
        fingerprints_after["jtag_top_source"] = sha256(JTAG_TOP)
        fingerprints_after["jtag_top_overlay"] = sha256(jtag_top_overlay)
        fingerprints_after["jtag_profile_input"] = sha256(Path(jtag_port_provenance["profile_before"]))
    fingerprint_error = ("Tool, profile, or DPI bundle changed during run"
                         if fingerprints_after != fingerprints_before else None)
    try:
        verify_firmware_overlays(firmware_roots, firmware_overlays)
    except (OSError, RuntimeError) as exc:
        fingerprint_error = str(exc)
    try:
        if preflight_vectors() != vector_preflight or any(
            sha256(path) != vector_hashes[name] for name, path in vector_files.items()
        ):
            fingerprint_error = "Native vector tools or built generators changed during run"
    except (OSError, RuntimeError, subprocess.CalledProcessError) as exc:
        fingerprint_error = f"Native vector integrity check failed: {exc}"
    integrity_error = source_error or fingerprint_error
    for case in run_cases:
        result_path = output / case["name"] / "result.json"
        if not result_path.exists():
            continue
        result = json.loads(result_path.read_text())
        if integrity_error:
            failed += result["passed"]
            result["simulation_passed"] = result["passed"]
            result["passed"] = False
        result["source_integrity_ok"] = source_error is None
        result["source_integrity_error"] = source_error
        result["fingerprint_integrity_ok"] = fingerprint_error is None
        result["fingerprint_integrity_error"] = fingerprint_error
        result_path.write_text(json.dumps(result, indent=2) + "\n")
    attempted = len(run_cases)
    (output / "summary.json").write_text(json.dumps({"selected": 52, "attempted": attempted,
                                                       "passed": attempted - failed,
                                                       "failed": failed, "unrun": 52 - attempted,
                                                       "status": "COMPLETE" if not integrity_error else "INVALIDATED",
                                                       "qualification": qualification,
                                                       "commercial_unsafe": args.commercial_unsafe,
                                                       "reset_overlay": args.reset_overlay,
                                                       "checker_source_overlay": args.checker_source_overlay,
                                                       "checker_overlay_provenance": checker_overlay_provenance,
                                                       "ephemeral_jtag_port": args.ephemeral_jtag_port,
                                                       "jtag_port_provenance": jtag_port_provenance,
                                                       "firmware_sources": {name: str(root) for name, root in firmware_roots.items()},
                                                       "selected_firmware_overlays": firmware_overlays,
                                                       "compiler_flags": compiler_flags,
                                                       "compile_sampling_warnings": sampling_warnings,
                                                       "fingerprints_before": fingerprints_before,
                                                       "fingerprints_after": fingerprints_after,
                                                       "source_integrity_before": source_before,
                                                       "source_integrity_after": source_after,
                                                       "source_integrity_error": source_error,
                                                       "fingerprint_integrity_error": fingerprint_error}, indent=2) + "\n")
    return int(failed != 0 or integrity_error is not None)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, ValueError, subprocess.CalledProcessError) as exc:
        print(f"setup error: {exc}", file=sys.stderr)
        sys.exit(2)
