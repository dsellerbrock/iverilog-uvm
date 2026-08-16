#!/usr/bin/env python3
"""Focused IEEE 1800 Chapter 21 EVCD regression and polarity runner."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys


IVTEST = Path(__file__).resolve().parent
SOURCES = IVTEST / "ivltests"
DEFAULT_IVERILOG = IVTEST.parent / "local-install" / "bin" / "iverilog"
DEFAULT_VVP = IVTEST.parent / "local-install" / "bin" / "vvp"


class FocusFailure(RuntimeError):
    pass


def command_text(command: list[str]) -> str:
    return " ".join(command)


class FocusRunner:
    def __init__(self, args: argparse.Namespace) -> None:
        self.iverilog = str(Path(args.iverilog).resolve())
        self.vvp = str(Path(args.vvp).resolve())
        self.slang = str(Path(args.slang).resolve()) if args.slang else None
        self.prefix = [str(Path(args.resource_runner).resolve())] \
            if args.resource_runner else []
        self.work = Path(args.work).resolve()
        self.work.mkdir(parents=True, exist_ok=True)
        self.skip_limit_stress = args.skip_limit_stress

    def run(self, command: list[str], *, expect: int | None = 0,
            contains: str | None = None, timeout: int = 30) \
            -> subprocess.CompletedProcess[str]:
        full = self.prefix + command
        try:
            result = subprocess.run(
                full, cwd=IVTEST, text=True, stdout=subprocess.PIPE,
                stderr=subprocess.PIPE, timeout=timeout, check=False,
                env={**os.environ, "LC_ALL": "C"})
        except subprocess.TimeoutExpired as exc:
            raise FocusFailure(f"timeout: {command_text(full)}") from exc
        output = result.stdout + result.stderr
        if expect is not None and result.returncode != expect:
            raise FocusFailure(
                f"unexpected rc={result.returncode}: {command_text(full)}\n"
                f"{output}")
        if contains is not None and contains not in output:
            raise FocusFailure(
                f"missing {contains!r}: {command_text(full)}\n{output}")
        return result

    def compile(self, basename: str, *, target: str = "vvp") -> Path:
        source = SOURCES / f"{basename}.v"
        suffix = "vvp" if target == "vvp" else target
        output = self.work / f"{basename}.{suffix}"
        command = [self.iverilog, "-g2012", f"-t{target}", "-o",
                   str(output), str(source)]
        self.run(command)
        return output

    def simulate(self, image: Path, *, expect: int = 0,
                 contains: str | None = None) -> subprocess.CompletedProcess[str]:
        return self.run([self.vvp, str(image), "-no-date"], expect=expect,
                        contains=contains)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise FocusFailure(message)


def evcd_by_time(path: Path) -> tuple[str, dict[int, list[str]]]:
    text = path.read_text(encoding="ascii")
    records: dict[int, list[str]] = {}
    current: int | None = None
    for line in text.splitlines():
        if line.startswith("#"):
            current = int(line[1:])
            records.setdefault(current, [])
        elif current is not None:
            records[current].append(line)
    return text, records


def has_record(records: dict[int, list[str]], time: int, ident: int,
               prefix: str) -> bool:
    return any(line.startswith(prefix) and line.endswith(f" <{ident}")
               for line in records.get(time, []))


def check_runtime_evcd(runner: FocusRunner) -> None:
    output = IVTEST / "work" / "sv_dumpports_runtime.evcd"
    output.unlink(missing_ok=True)
    image = runner.compile("sv_dumpports_runtime")
    runner.simulate(image, contains="PASSED")
    text, records = evcd_by_time(output)

    declarations = [line for line in text.splitlines()
                    if line.startswith("$var port")]
    require(len(declarations) == 19, "expected exactly 19 EVCD port records")
    require(declarations[0] == "$var port 1 <0 in_s $end",
            "EVCD identifiers are not declaration-ordered from <0")
    require("$var port [3:2] <16 selected_bus $end" in declarations and
            "$var port [1:0] <17 selected_bus $end" in declarations,
            "declared concatenated part components were not kept separate")
    require("$scope module sv_dumpports_runtime.dut $end" in text,
            "full module scope is missing from EVCD")

    checks = [
        (0, 12, "pF 0 0"),       # structurally unconnected inout
        (0, 13, "pf 0 0"),       # connected, all-Z inout
        (0, 2, "r1.5"),          # standard real-number exception
        (1000, 0, "pD 6 0"),     # strength-only input change
        (1000, 6, "pd 6 0"),     # one -> two input drivers
        (2000, 6, "pD 6 0"),     # two -> one input driver
        (1000, 7, "pl 6 0"),     # one -> two output drivers
        (2000, 7, "pL 6 0"),     # two -> one output drivers
        (2000, 11, "pd 6 0"),    # two fixture-side inout drivers
        (3000, 11, "pD 6 0"),    # driver removed, value unchanged
        (4000, 11, "pd 6 0"),    # driver restored, value unchanged
        (7000, 2, "rNaN"),       # $dumpportsoff real value
        (9000, 13, "pf 0 0"),
    ]
    for time, ident, prefix in checks:
        require(has_record(records, time, ident, prefix),
                f"missing EVCD record t={time} id=<{ident} {prefix!r}")
    require(8000 not in records,
            "$dumpportsoff leaked value records while dumping was disabled")
    require(text.rstrip().endswith("$vcdclose #11000 $end"),
            "EVCD file was not deterministically closed")


def check_finish_and_controls(runner: FocusRunner) -> None:
    finish_path = IVTEST / "work" / "sv_dumpports_finish_pending.evcd"
    finish_path.unlink(missing_ok=True)
    runner.simulate(runner.compile("sv_dumpports_finish_pending"))
    finish_text, finish_records = evcd_by_time(finish_path)
    require(has_record(finish_records, 1, 0, "pU 0 6"),
            "same-slot $finish lost the final scheduled port sample")
    require(finish_text.rstrip().endswith("$vcdclose #1 $end"),
            "same-slot $finish did not close EVCD after final sampling")

    limit_path = IVTEST / "work" / "sv_dumpports_limit.evcd"
    limit_path.unlink(missing_ok=True)
    runner.simulate(runner.compile("sv_dumpports_limit_prestart"),
                    contains="PASSED")
    limit_text = limit_path.read_text(encoding="ascii")
    require("#0" not in limit_text and "$dumpports\n" not in limit_text,
            "$dumpportslimit did not suppress startup values after full")

    runner.simulate(runner.compile("sv_dumpports_multifile"), contains="PASSED")
    first = (IVTEST / "work" / "sv_dumpports_a.evcd").read_text(encoding="ascii")
    second = (IVTEST / "work" / "sv_dumpports_b.evcd").read_text(encoding="ascii")
    require("$dumpportsoff" in first and "$dumpportson" in first,
            "filename-scoped off/on controls were not recorded")
    require("$dumpportsoff" not in second,
            "a filename-scoped control affected another EVCD file")


def check_corpus_and_no_use(runner: FocusRunner) -> None:
    runner.simulate(runner.compile("sv_dumpports_svtests_21_7"),
                    contains="PASSED")
    no_use = runner.compile("sv_dumpports_no_use_inout")
    runner.simulate(no_use, contains="PASSED")
    no_use_text = no_use.read_text(encoding="ascii")
    require(".port_info/evcd" not in no_use_text and
            '"$ivl_evcd_fixture"' not in no_use_text,
            "an ordinary inout design acquired EVCD-only VVP metadata")

    for target in ("vlog95", "stub"):
        runner.compile("sv_dumpports_no_use_inout_synth", target=target)
    fpga_conf = IVTEST.parent / "local-install" / "lib" / "ivl" / "fpga.conf"
    if fpga_conf.exists():
        runner.compile("sv_dumpports_no_use_inout_synth", target="fpga")
    else:
        print("SKIP: FPGA target is not installed in local-install")


def expect_runtime_error(runner: FocusRunner, basename: str,
                         fragment: str) -> None:
    image = runner.compile(basename)
    runner.simulate(image, expect=1, contains=fragment)


def check_task_errors(runner: FocusRunner) -> None:
    errors = {
        "sv_dumpports_args_fail":
            "$dumpports: a filename with no scope requires a leading comma",
        "sv_dumpports_control_args_fail":
            "$dumpportsoff: takes at most one filename argument",
        "sv_dumpports_limit_args_fail":
            "$dumpportslimit: requires a numeric file size argument",
        "sv_dumpports_duplicate_scope_fail":
            "module scope 'sv_dumpports_duplicate_scope_fail.dut' was selected more than once",
        "sv_dumpports_duplicate_file_fail":
            "filename 'work/sv_dumpports_duplicate_file.evcd' was specified more than once",
        "sv_dumpports_late_fail":
            "all $dumpports calls must execute at the same simulation time",
    }
    for basename, fragment in errors.items():
        expect_runtime_error(runner, basename, fragment)


def replace_once(text: str, old: str, new: str, label: str) -> str:
    require(text.count(old) == 1,
            f"raw-VVP seed does not contain one {label} pattern")
    return text.replace(old, new, 1)


def check_raw_metadata(runner: FocusRunner) -> None:
    seed_image = runner.compile("sv_dumpports_metadata_base")
    seed = seed_image.read_text(encoding="ascii")
    output = IVTEST / "work" / "sv_dumpports_metadata_base.evcd"
    cases: list[tuple[str, str, str]] = []

    base = '    .port_info/evcd 0 0 4 "io" "3" "0" 4 0 1 '
    cases.append(("range_text", replace_once(
        seed, base, '    .port_info/evcd 0 0 4 "io" "bad" "0" 4 0 1 ',
        "range-text"), "invalid .port_info/evcd component metadata"))
    cases.append(("range_overflow", replace_once(
        seed, base,
        '    .port_info/evcd 0 0 4 "io" "999999999999999999999" "0" 4 0 1 ',
        "range-overflow"), "invalid .port_info/evcd component metadata"))
    cases.append(("component_width", replace_once(
        seed, base, '    .port_info/evcd 0 0 5 "io" "3" "0" 4 0 1 ',
        "component-width"), "invalid .port_info/evcd component metadata"))
    cases.append(("fixture_base", replace_once(
        seed, base, '    .port_info/evcd 0 0 4 "io" "3" "0" 4 4 1 ',
        "fixture-base"), "invalid .port_info/evcd component metadata"))

    dut_pattern = re.compile(
        r'(EVD_[^ ]+ \.net8 \* "\$ivl_evcd_dut", )3 0,')
    undersized, changed = dut_pattern.subn(r'\g<1>1 0,', seed, count=1)
    require(changed == 1, "raw-VVP seed has no DUT side probe")
    cases.append(("undersized_dut", undersized,
                  "strength net declaration width does not match source signal"))
    cases.append(("scope_whitespace", replace_once(
        seed, '.scope module, "dut"', '.scope module, "bad scope"',
        "scope-name"), "cannot be represented as an EVCD scope_identifier"))

    cap_seed = replace_once(seed, '.port_info 0 /INOUT 4 "io";',
                            '.port_info 0 /INOUT 4097 "io";',
                            "port-width")
    original_component = re.compile(r'^    \.port_info/evcd 0 0 4 .*;$',
                                    re.MULTILINE)
    cap_components = "\n".join(
        f'    .port_info/evcd 0 {idx} 1 "io" "0" "0";'
        for idx in range(4097))
    cap_seed, changed = original_component.subn(cap_components, cap_seed,
                                                count=1)
    require(changed == 1, "raw-VVP seed has no component metadata record")
    cases.append(("component_cap", cap_seed,
                  ".port_info/evcd metadata exceeds the safe aggregate record/width budget"))

    for name, payload, fragment in cases:
        mutated = runner.work / f"dumpports_bad_{name}.vvp"
        mutated.write_text(payload, encoding="ascii")
        output.unlink(missing_ok=True)
        result = runner.run([runner.vvp, str(mutated), "-no-date"],
                            expect=None, contains=fragment)
        require(result.returncode != 0,
                f"malformed VVP case {name} unexpectedly succeeded")
        require(not output.exists(),
                f"malformed VVP case {name} created partial EVCD output")


def write_port_cap_source(path: Path, count: int) -> None:
    names = [f"p{idx}" for idx in range(count)]
    text = "module dumpports_port_cap_leaf(output wire " \
           + ", ".join(names) + ");\nendmodule\n\n"
    text += "module dumpports_port_cap;\n  dumpports_port_cap_leaf dut();\n"
    text += "  initial $dumpports(dut, \"work/sv_dumpports_port_cap.evcd\");\n"
    text += "endmodule\n"
    path.write_text(text, encoding="ascii")


def write_file_cap_source(path: Path, count: int) -> None:
    lines = ["module dumpports_file_cap_leaf(output wire value);",
             "  assign value = 1'b0;", "endmodule", "",
             "module dumpports_file_cap;"]
    for idx in range(count):
        lines.append(f"  wire value_{idx};")
        lines.append(f"  dumpports_file_cap_leaf d{idx}(value_{idx});")
    lines.append("  initial begin")
    for idx in range(count):
        lines.append(
            f"    $dumpports(d{idx}, \"work/dumpports_file_cap_{idx}.evcd\");")
    lines.extend(["  end", "endmodule", ""])
    path.write_text("\n".join(lines), encoding="ascii")


def write_scope_cap_source(path: Path, count: int) -> None:
    instances = [f"d{idx}" for idx in range(count)]
    lines = ["module dumpports_scope_cap_leaf; endmodule", "",
             "module dumpports_scope_cap;"]
    lines.extend(f"  dumpports_scope_cap_leaf {name}();" for name in instances)
    lines.append("  initial $dumpports(" + ", ".join(instances) +
                 ', "work/sv_dumpports_scope_cap.evcd");')
    lines.extend(["endmodule", ""])
    path.write_text("\n".join(lines), encoding="ascii")


def write_two_file_scope_cap_source(path: Path, count: int) -> None:
    split = count // 2
    instances = [f"d{idx}" for idx in range(count)]
    lines = ["module dumpports_two_file_scope_cap_leaf; endmodule", "",
             "module dumpports_two_file_scope_cap;"]
    lines.extend(
        f"  dumpports_two_file_scope_cap_leaf {name}();"
        for name in instances)
    lines.append("  initial begin")
    lines.append("    $dumpports(" + ", ".join(instances[:split]) +
                 ', "work/sv_dumpports_scope_cap_a.evcd");')
    lines.append("    $dumpports(" + ", ".join(instances[split:]) +
                 ', "work/sv_dumpports_scope_cap_b.evcd");')
    lines.extend(["  end", "endmodule", ""])
    path.write_text("\n".join(lines), encoding="ascii")


def compile_generated(runner: FocusRunner, source: Path, image: Path,
                      timeout: int = 120) -> None:
    runner.run([runner.iverilog, "-g2012", "-o", str(image), str(source)],
               timeout=timeout)


def check_resource_limits(runner: FocusRunner) -> None:
    if runner.skip_limit_stress:
        print("SKIP: generated cap+1 resource-boundary cases")
        return

    port_source = runner.work / "dumpports_port_cap.v"
    port_image = runner.work / "dumpports_port_cap.vvp"
    write_port_cap_source(port_source, 4097)
    result = runner.run(
        [runner.iverilog, "-g2012", "-o", str(port_image), str(port_source)],
        expect=None,
        contains="EVCD metadata exceeds the safe aggregate record/width budget",
        timeout=120)
    require(result.returncode != 0,
            "target emitted more than 4096 EVCD metadata records")

    scope_source = runner.work / "dumpports_scope_cap.v"
    scope_image = runner.work / "dumpports_scope_cap.vvp"
    write_scope_cap_source(scope_source, 4097)
    compile_generated(runner, scope_source, scope_image)
    runner.run([runner.vvp, str(scope_image), "-no-date"], expect=1,
               contains="too many $dumpports arguments", timeout=60)

    two_file_source = runner.work / "dumpports_two_file_scope_cap.v"
    two_file_image = runner.work / "dumpports_two_file_scope_cap.vvp"
    write_two_file_scope_cap_source(two_file_source, 4097)
    compile_generated(runner, two_file_source, two_file_image)
    runner.run([runner.vvp, str(two_file_image), "-no-date"], expect=1,
               contains="safe aggregate EVCD scope-record limit", timeout=60)

    file_source = runner.work / "dumpports_file_cap.v"
    file_image = runner.work / "dumpports_file_cap.vvp"
    write_file_cap_source(file_source, 65)
    compile_generated(runner, file_source, file_image)
    runner.run([runner.vvp, str(file_image), "-no-date"], expect=1,
               contains="too many EVCD files are open", timeout=60)


def check_slang(runner: FocusRunner) -> None:
    if not runner.slang:
        print("SKIP: Slang path not supplied")
        return
    for basename in ("sv_dumpports_svtests_21_7", "sv_dumpports_runtime",
                     "sv_dumpports_no_use_inout"):
        runner.run([runner.slang, str(SOURCES / f"{basename}.v")])


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--iverilog", default=str(DEFAULT_IVERILOG))
    parser.add_argument("--vvp", default=str(DEFAULT_VVP))
    parser.add_argument("--slang")
    parser.add_argument("--resource-runner")
    parser.add_argument("--work", default=str(IVTEST / "work" /
                                               "dumpports-focus"))
    parser.add_argument("--skip-limit-stress", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    runner = FocusRunner(args)
    try:
        check_runtime_evcd(runner)
        check_finish_and_controls(runner)
        check_corpus_and_no_use(runner)
        check_task_errors(runner)
        check_raw_metadata(runner)
        check_resource_limits(runner)
        check_slang(runner)
    except FocusFailure as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    print("PASS: Chapter 21 dumpports focused regression")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
