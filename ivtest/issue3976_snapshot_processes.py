"""Exercise assertion snapshots across independent compiler and VVP processes."""

import os
from pathlib import Path
import subprocess
import tempfile


def check_edition(edition, bindir, hdl, work):
    source = work / "design.sv"
    copy_dir = work / "independent"
    copy_dir.mkdir()
    source_copy = copy_dir / source.name
    snapshot = work / "assertions.db"
    top = "issue3976_assertion_snapshot"

    def compile_design(output, *args, root=top, input_file=source):
        subprocess.run(
            [str(bindir / "iverilog"), f"-g{edition}", "-s", root,
             "-o", str(work / output), *args, input_file.name],
            cwd=input_file.parent, check=True, timeout=30,
        )

    def simulate(image, mode=None, **kwargs):
        args = [str(bindir / "vvp"), image, f"+snapshot={snapshot}"]
        if mode:
            args.append(f"+{mode}")
        result = subprocess.run(
            args, cwd=work, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, timeout=30, **kwargs,
        )
        print(f"{edition} {image} {mode or ''}\n{result.stdout}", end="")
        result.check_returncode()
        if not result.stdout.endswith("PASSED\n"):
            raise RuntimeError("simulation did not reach PASSED")

    source.write_text(hdl, encoding="ascii")
    source_copy.write_text(hdl, encoding="ascii")
    compile_design("save.vvp")
    compile_design("same.vvp", input_file=source_copy)
    compile_design("parameter.vvp", f"-P{top}.CFG=2")
    compile_design("empty.vvp", root="issue3976_empty")
    source.write_text(hdl.replace("(sample == CFG)", "(sample >= CFG)"),
                      encoding="ascii")
    compile_design("changed.vvp")
    source.unlink()
    source_copy.unlink()

    simulate("empty.vvp")
    if snapshot.exists():
        raise RuntimeError("NOCOV save created a database entry")
    simulate("save.vvp", "save_only")
    simulate("same.vvp", "merge_only")
    simulate("parameter.vvp", "reject_only")
    simulate("changed.vvp", "reject_only")

    if os.name == "posix":
        import resource
        import signal

        def fail_snapshot_write():
            signal.signal(signal.SIGXFSZ, signal.SIG_IGN)
            resource.setrlimit(resource.RLIMIT_FSIZE, (1, 1))

        simulate("save.vvp", "save_error", preexec_fn=fail_snapshot_write)
        if list(work.glob("assertions.db*")):
            raise RuntimeError("failed save left a database entry or temporary file")


if __name__ == "__main__":
    ivtest = Path(__file__).resolve().parent
    bindir = ivtest.parent / "local-install" / "bin"
    hdl = (ivtest / "ivltests" / "issue3976_assertion_snapshot.sv").read_text()
    for edition in (2017, 2023):
        with tempfile.TemporaryDirectory(prefix=f"ivl3976-{edition}-") as directory:
            check_edition(edition, bindir, hdl, Path(directory))
