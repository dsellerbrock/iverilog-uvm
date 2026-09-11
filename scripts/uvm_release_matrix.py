#!/usr/bin/env python3
"""Fetch pinned unmodified UVM releases and probe them (POSIX, Python >=3.12).

SV libraries are compiled with a self-checking test, not into portable binaries.
The installed Icarus DPI backend is used; this is not per-release qualification.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import tarfile
import tempfile
import time
import urllib.request

REPO = Path(__file__).resolve().parents[1]


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def tree_digest(root):
    result = hashlib.sha256()
    for path in sorted(root.rglob("*")):
        if ".git" in path.relative_to(root).parts:
            continue
        if path.is_symlink() or path.is_file():
            result.update(str(path.relative_to(root)).encode() + b"\0")
            result.update((os.readlink(path) if path.is_symlink() else digest(path)).encode())
            result.update(b"\0")
    return result.hexdigest()


def acquire(release, cache):
    if "git" in release:
        pin = release["git"]
        home = REPO / pin["path"]
        if not (home / ".git").exists():
            subprocess.run(["git", "submodule", "update", "--init", "--depth", "1", "--", pin["path"]],
                           cwd=REPO, check=True, timeout=300)
        head = subprocess.check_output(["git", "-C", str(home), "rev-parse", "HEAD"], text=True).strip()
        dirty = subprocess.check_output(["git", "-C", str(home), "status", "--porcelain", "--untracked-files=all"], text=True)
        if head != pin["commit"] or dirty:
            raise ValueError("submodule differs from pin or has changes; preserve/review it first")
        return home, tree_digest(home), home
    archives, sources = cache / "archives", cache / "sources"
    archives.mkdir(parents=True, exist_ok=True)
    sources.mkdir(parents=True, exist_ok=True)
    archive = archives / (release["id"] + ".tar.gz")
    if not archive.exists():
        with urllib.request.urlopen(release["url"], timeout=60) as response:
            data = response.read()
        if hashlib.sha256(data).hexdigest() != release["sha256"]:
            raise ValueError("download checksum mismatch")
        archive.write_bytes(data)
    if digest(archive) != release["sha256"]:
        raise ValueError("cached archive checksum mismatch")
    target = sources / release["id"]
    stamp = sources / (release["id"] + ".json")
    if target.exists():
        saved = json.loads(stamp.read_text())
        if saved["archive_sha256"] != release["sha256"] or saved["tree_sha256"] != tree_digest(target):
            raise ValueError("cached source changed; preserve/review it before reacquiring")
    else:
        with tempfile.TemporaryDirectory(dir=sources) as temporary:
            unpacked = Path(temporary) / "tree"
            unpacked.mkdir()
            with tarfile.open(archive) as package:
                package.extractall(unpacked, filter="data")
            candidates = [p for p in unpacked.rglob("src/uvm_pkg.sv")
                          if "docs" not in p.relative_to(unpacked).parts]
            if len(candidates) != 1:
                raise ValueError("archive does not contain one UVM source root")
            saved = {"archive_sha256": release["sha256"],
                     "tree_sha256": tree_digest(unpacked),
                     "uvm_home": str(candidates[0].parent.parent.relative_to(unpacked))}
            unpacked.rename(target)
            stamp.write_text(json.dumps(saved, indent=2) + "\n")
    return target / saved["uvm_home"], saved["tree_sha256"], target


def register_release(version, home, prefix):
    """Expose a verified source tree to the driver's release picker."""
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", version):
        raise ValueError("invalid release ID")
    catalog = prefix / "lib/ivl/uvm/releases"
    catalog.mkdir(parents=True, exist_ok=True)
    link = catalog / version
    if link.is_symlink() and link.resolve() == home.resolve():
        return
    if link.exists() or link.is_symlink():
        raise ValueError(f"refusing to replace existing release registration: {link}")
    link.symlink_to(home.resolve(), target_is_directory=True)


def execute(command, cwd, log, timeout):
    started = time.monotonic()
    # The CPU limit is inherited by compiler children; wall timeout kills the group.
    launch = ["sh", "-c", 'ulimit -t 300; exec "$@"', "uvm-release-probe", *command]
    with log.open("w") as stream:
        process = subprocess.Popen(launch, cwd=cwd, stdout=stream, stderr=subprocess.STDOUT,
                                   start_new_session=True)
        timed_out = False
        try:
            process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
        except BaseException:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
            raise
    return {"command": command, "cwd": str(cwd), "log": str(log),
            "returncode": process.returncode, "timed_out": timed_out,
            "seconds": round(time.monotonic() - started, 3)}


def smoke_passed(result, output):
    if result["returncode"] != 0 or result["timed_out"]:
        return False
    if "UVM_RELEASE_SMOKE_PASSED" not in output.splitlines():
        return False
    # Simulator diagnostics bypass UVM reporting and can leave a zero exit code.
    if re.search(r"^(?!UVM_INFO[ \t])(?:(?:.*:\d+:[ \t]*)?(?:error|fatal|warning):|"
                 r"DPI error:|unresolved functor stub:)", output, re.MULTILINE | re.IGNORECASE):
        return False
    for severity in ("ERROR", "FATAL", "WARNING"):
        counts = re.findall(r"^\s*UVM_" + severity + r"\s*:\s*(\d+)\s*$", output, re.MULTILINE)
        if not counts or any(int(count) != 0 for count in counts):
            return False
    return True


def finalize(results, fingerprints, output):
    changed = [str(p) for p, old in fingerprints.items() if not p.is_file() or digest(p) != old]
    results.update(complete=True, baseline_valid=not changed, changed_inputs=changed)
    if changed:
        for row in results["results"]:
            row["probe_status"] = row["status"]
            row["status"] = "INVALIDATED_INPUT_CHANGE"
    (output / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    return bool(changed)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release", action="append", help="manifest ID; repeatable, default all")
    parser.add_argument("--cache", type=Path, default=REPO / "third_party/uvm-releases")
    parser.add_argument("--prefix", type=Path, default=REPO / "local-install")
    parser.add_argument("--fetch-only", action="store_true")
    parser.add_argument("--register", action="store_true",
                        help="register verified sources under --prefix for iverilog --uvm=ID")
    parser.add_argument("--timeout", type=int, default=300)
    args = parser.parse_args()
    if os.name != "posix" or not hasattr(tarfile, "data_filter"):
        parser.error("requires POSIX and Python >=3.12 with safe tar extraction")
    if args.timeout <= 0:
        parser.error("timeout must be positive")
    releases = json.loads((REPO / "scripts/uvm-releases.json").read_text())["releases"]
    if args.release:
        unknown = set(args.release) - {r["id"] for r in releases}
        if unknown:
            parser.error("unknown releases: " + ", ".join(sorted(unknown)))
        releases = [r for r in releases if r["id"] in args.release]
    cache, prefix = args.cache.resolve(), args.prefix.resolve()
    compiler, runtime = prefix / "bin/iverilog", prefix / "bin/vvp"
    tools = [compiler, runtime, prefix / "lib/ivl/ivl", prefix / "lib/ivl/vvp.tgt",
             prefix / "lib/ivl/ivlpp", prefix / "lib/ivl/system.vpi",
             prefix / "lib/ivl/vvp.conf", prefix / "lib/ivl/uvm_dpi.vpi"]
    if not args.fetch_only and any(not p.is_file() for p in tools):
        parser.error("prefix must contain the compiler, runtime, target and real UVM DPI backend")
    cache.mkdir(parents=True, exist_ok=True)
    output = Path(tempfile.mkdtemp(prefix="results-", dir=cache))
    inputs = [REPO / "scripts/uvm-releases.json", Path(__file__).resolve(),
              REPO / "tests/uvm_releases/smoke.sv"]
    fingerprints = {p: digest(p) for p in inputs + ([] if args.fetch_only else tools)}
    results = {"generation": "2012", "source_manifest": str(REPO / "scripts/uvm-releases.json"),
               "complete": False, "baseline_valid": None,
               "inputs": {str(p): fingerprints[p] for p in inputs},
               "tools": {str(p): digest(p) for p in tools} if not args.fetch_only else {},
               "dpi": "installed Icarus backend; release-specific ABI qualification not claimed",
               "scope": "unmodified library compile and factory/copy/phase/regex/HDL smoke only",
               "results": []}
    failed = False
    for release in releases:
        row = {"release": release["id"], "archive_sha256": release["sha256"]}
        work = output / release["id"]
        work.mkdir()
        try:
            home, source_hash, source_root = acquire(release, cache)
            if args.register:
                register_release(release["id"], home, prefix)
            row.update(uvm_home=str(home), source_tree_sha256=source_hash, status="FETCHED",
                       acquisition=release.get("git", {"url": release["url"]}))
            if not args.fetch_only:
                program = work / "smoke.vvp"
                row["compile"] = execute([str(compiler), "-g2012", "--uvm-home=" + str(home),
                    "-suvm_release_smoke", "-o", str(program),
                    str(REPO / "tests/uvm_releases/smoke.sv")], work, work / "compile.log", args.timeout)
                compiled = row["compile"]
                if compiled["returncode"] != 0 or compiled["timed_out"]:
                    row["status"] = "COMPILE_TIMEOUT" if compiled["timed_out"] else "COMPILE_FAIL"
                else:
                    row["runtime"] = execute([str(runtime), str(program)], work, work / "runtime.log", args.timeout)
                    ran = row["runtime"]
                    row["status"] = "SMOKE_PASS" if smoke_passed(ran, (work / "runtime.log").read_text(errors="replace")) else "RUNTIME_FAIL"
                    if ran["timed_out"]:
                        row["status"] = "RUNTIME_TIMEOUT"
                if tree_digest(source_root) != source_hash:
                    raise ValueError("source changed during probe")
        except (OSError, ValueError, tarfile.TarError, subprocess.SubprocessError) as error:
            row.update(status="ACQUISITION_OR_HARNESS_FAIL", error=str(error))
        failed |= row["status"] not in ("FETCHED", "SMOKE_PASS")
        results["results"].append(row)
        (output / "results.json").write_text(json.dumps(results, indent=2) + "\n")
        print(release["id"], row["status"], flush=True)
    failed |= finalize(results, fingerprints, output)
    print("Results:", output / "results.json")
    return int(failed)


if __name__ == "__main__":
    raise SystemExit(main())
