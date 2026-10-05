#!/usr/bin/env python3
# Apple Silicon campaign hint: invoke with
# /opt/homebrew/opt/python@3.13/bin/python3.13.
# Override with --fusesoc-python only for an equivalent 3.13 environment.
# Use the OpenTitan tool environment's Python; see --fusesoc-python below.
"""Run a reproducible Icarus Verilog conformance matrix over OpenTitan cores.

The matrix deliberately distinguishes a clean compile from a successful process
exit that emitted semantic-degradation warnings.  Its output is intended to be
both a gap census and a durable record of exactly which OpenTitan revision,
compiler, provider mappings, and commands produced each result.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import dataclasses
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import shlex
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from typing import Callable, Iterable, Sequence


def _require_python313(
    version: str,
    *,
    role: str = "Python",
) -> None:
    """Require the OpenTitan campaign's supported Python 3.13."""
    if role == "matrix driver Python":
        hint = (
            "Invoke this script with "
            "/opt/homebrew/opt/python@3.13/bin/python3.13."
        )
    else:
        hint = (
            "Use --fusesoc-python with "
            "/opt/homebrew/opt/python@3.13/bin/python3.13 or another "
            "matching native interpreter."
        )
    try:
        major, minor = (int(part) for part in version.split(".", 2)[:2])
    except (TypeError, ValueError):
        major, minor = (-1, -1)
    if (major, minor) != (3, 13):
        raise RuntimeError(
            f"OpenTitan's {role} must use Python 3.13; "
            f"the interpreter reports {version!r}. {hint}"
        )


LANES = ("rtl", "sva", "uvm", "runtime")
TARGETS = {"rtl": "default", "sva": "formal", "uvm": "sim", "runtime": "sim"}
SIMULATION_CATEGORIES = ("uvm", "directed", "verilator", "elaboration")
SVA_DEFAULT_TARGETS = {"lowrisc:fpv:prim_keccak_fpv:0.1"}
SVA_UVM_CORES = {
    "lowrisc:dv:adc_ctrl_sva:0.1",
    "lowrisc:dv:spi_host_sva:0.1",
}
# Build-mode defines that dvsim's sim cfgs pass with +define+ and the
# fusesoc targets never carry. Values mirror the DUT's default RTL
# parameterization (aes.sv elaborates with SecMasking = 1).
SVA_EXTRA_DEFINES = {
    "lowrisc:dv:aes_sva:0.1": ("-DEN_MASKING=1",),
}
# Same idea for the uvm/runtime lanes: dvsim's per-core sim cfgs pass
# +define+ build options the fusesoc sim target never carries. Values
# mirror the DUT's default RTL parameterization (lc_ctrl.sv elaborates
# with SecVolatileRawUnlockEn = 0).
UVM_EXTRA_DEFINES = {
    "lowrisc:dv:lc_ctrl_sim:0.1": ("-DSEC_VOLATILE_RAW_UNLOCK_EN=0",),
    # aes_base_sim_cfg.hjson runs both EN_MASKING=0 and EN_MASKING=1
    # variants; without either, hw/ip/aes/dv/sva/aes_bind.sv's `if
    # (`EN_MASKING) begin : gen_prng_bind` sees the macro undefined
    # (assumed null), producing `if ()` -- a raw syntax error that
    # looks like a parser gap but is really a missing build define.
    # Matches SVA_EXTRA_DEFINES's aes_sva entry above; picks the
    # EN_MASKING=1 variant as the default, same as that one.
    "lowrisc:dv:aes_sim:0.1": ("-DEN_MASKING=1",),
    # spi_device_sim.core has no SRAM mode; its bare target represents the
    # documented RTL default. The separate 2p HJSON configuration is not
    # covered by this row.
    "lowrisc:dv:spi_device_sim:0.1": (
        "-DSRAM_TYPE=spi_device_pkg::SramType1r1w",
    ),
}
UVM_REGEX_NO_DPI_BUILD_OPTION = "+define+UVM_REGEX_NO_DPI"
DEFAULT_TOPS = {
    "earlgrey": "lowrisc:systems:top_earlgrey:0.1",
    "darjeeling": "lowrisc:systems:top_darjeeling:0.1",
}
TOP_VARIANTS = (*DEFAULT_TOPS, "englishbreakfast")
# Earlgrey-PROD-M6 (the pinned OpenTitan release, see opentitan-root) predates
# the single umbrella "lowrisc:prim_generic:all" provider core that later
# OpenTitan revisions ship: at M6 each technology-dependent prim is its own
# separate core (hw/ip/prim_generic/prim_generic_*.core, no version suffix),
# and the abstract "lowrisc:prim:X" VLNVs each need their own mapping entry.
# This synthetic core supplies exactly that -- one entry per prim_generic
# core that actually exists at this revision -- mirroring the
# ENGLISHBREAKFAST_MAPPING_CORE pattern below rather than depending on a
# provider core this revision doesn't have.
PRIM_MAPPING = "local:matrix:prim_generic_all:0.1"
PRIM_MAPPING_CORE = """CAPI=2:
name: local:matrix:prim_generic_all:0.1
description: Deterministic prim_generic provider mapping for Earlgrey-PROD-M6
mapping:
  "lowrisc:prim:and2": "lowrisc:prim_generic:and2"
  "lowrisc:prim:buf": "lowrisc:prim_generic:buf"
  "lowrisc:prim:clock_buf": "lowrisc:prim_generic:clock_buf"
  "lowrisc:prim:clock_div": "lowrisc:prim_generic:clock_div"
  "lowrisc:prim:clock_gating": "lowrisc:prim_generic:clock_gating"
  "lowrisc:prim:clock_inv": "lowrisc:prim_generic:clock_inv"
  "lowrisc:prim:clock_mux2": "lowrisc:prim_generic:clock_mux2"
  "lowrisc:prim:flash": "lowrisc:prim_generic:flash"
  "lowrisc:prim:flop": "lowrisc:prim_generic:flop"
  "lowrisc:prim:flop_2sync": "lowrisc:prim_generic:flop_2sync"
  "lowrisc:prim:flop_en": "lowrisc:prim_generic:flop_en"
  "lowrisc:prim:otp": "lowrisc:prim_generic:otp"
  "lowrisc:prim:pad_attr": "lowrisc:prim_generic:pad_attr"
  "lowrisc:prim:pad_wrapper": "lowrisc:prim_generic:pad_wrapper"
  "lowrisc:prim:ram_1p": "lowrisc:prim_generic:ram_1p"
  "lowrisc:prim:ram_1r1w": "lowrisc:prim_generic:ram_1r1w"
  "lowrisc:prim:ram_2p": "lowrisc:prim_generic:ram_2p"
  "lowrisc:prim:rom": "lowrisc:prim_generic:rom"
  "lowrisc:prim:usb_diff_rx": "lowrisc:prim_generic:usb_diff_rx"
  "lowrisc:prim:xnor2": "lowrisc:prim_generic:xnor2"
  "lowrisc:prim:xor2": "lowrisc:prim_generic:xor2"
"""
MATRIX_SOURCE_CORE_DEPENDENCIES = (
    (
        "hw/ip/prim/prim_mubi.core",
        "lowrisc:prim:flop",
        ("lowrisc:prim:flop_2sync",),
    ),
    (
        "hw/ip/prim/prim_ram_1p_adv.core",
        "lowrisc:prim:ram_1p",
        ("lowrisc:prim:mubi",),
    ),
    (
        "hw/top_earlgrey/ip_autogen/flash_ctrl/flash_ctrl_prim_reg_top.core",
        "lowrisc:ip_interfaces:flash_ctrl_pkg",
        ("lowrisc:prim:reg_we_check",),
    ),
    (
        "hw/ip/otp_ctrl/otp_ctrl_prim_reg_top.core",
        "lowrisc:ip:otp_ctrl_pkg",
        (
            "lowrisc:prim:reg_we_check",
            "lowrisc:tlul:trans_intg",
            "lowrisc:tlul:adapter_reg",
            "lowrisc:prim:subreg",
        ),
    ),
    (
        "hw/ip/prim/prim_dom_and_2share.core",
        "lowrisc:prim:assert",
        ("lowrisc:prim:xor2", "lowrisc:prim:flop_en"),
    ),
    (
        "hw/ip/tlul/tlul_lc_gate.core",
        "lowrisc:tlul:common",
        ("lowrisc:tlul:socket_1n", "lowrisc:prim:sec_anchor"),
    ),
)
SPI_HOST_SVA_CORE = "hw/ip/spi_host/dv/sva/spi_host_sva.core"
SPI_HOST_SVA_CORE_SOURCE_SHA256 = (
    "16322a562961389fd9f0b4ca4ff7a266e60adb32547ba16b4921f2efbbc27122"
)
SPI_HOST_SVA_CORE_OVERLAY_SHA256 = (
    "7d7b4e3297492e04f77a44cec2c050f475172a9a723f1e6c43fc88512072be11"
)
ENGLISHBREAKFAST_MAPPING = "local:matrix:top_englishbreakfast:0.1"
ENGLISHBREAKFAST_MAPPING_CORE = """CAPI=2:
name: local:matrix:top_englishbreakfast:0.1
description: Deterministic virtual-core providers for the OpenTitan matrix
mapping:
  "lowrisc:virtual_constants:top_racl_pkg": "lowrisc:englishbreakfast_constants:top_racl_pkg"
  "lowrisc:systems:ast_pkg": "lowrisc:systems:top_englishbreakfast_ast_pkg"
  "lowrisc:virtual_ip:flash_ctrl_prim_reg_top": "lowrisc:englishbreakfast_ip:flash_ctrl_prim_reg_top"
  "lowrisc:virtual_ip:flash_ctrl_top_specific_pkg": "lowrisc:englishbreakfast_ip:flash_ctrl_top_specific_pkg"
  "lowrisc:virtual_constants:rnd_cnst_pkg": "lowrisc:englishbreakfast_constants:testing_rnd_cnst_pkg"
  "lowrisc:virtual_constants:lc_ctrl_token_pkg": "lowrisc:earlgrey_constants:testing_lc_ctrl_token_pkg"
"""

CORE_LINE_RE = re.compile(r"^(?P<core>[^\s:]+:[^\s:]+:[^\s:]+:[^\s]+)\s+:\s+")
MAKE_ASSIGN_RE = re.compile(r"^(?P<name>[A-Z_]+)\s*:?=\s*(?P<value>.*)$")
HARD_ERROR_PATTERNS = (
    re.compile(r"\bsyntax error\b", re.I),
    re.compile(r"(?:^|\s)(?:error|sorry):", re.I),
    re.compile(r"\binternal error\b", re.I),
    re.compile(r"\bsegmentation fault\b", re.I),
    re.compile(r"\bassertion (?:failed|failure)\b", re.I),
    re.compile(r"\bfailed assertion\b", re.I),
    re.compile(r"\babort trap\b", re.I),
    re.compile(r"\bcore dumped\b", re.I),
)
DEBT_PATTERNS = (
    re.compile(r"\bwarning:", re.I),
    re.compile(r"compile-progress", re.I),
    re.compile(r"\b(?:ignored|dropp(?:ed|ing))\b", re.I),
    re.compile(r"\b(?:degraded|fallback|approximat(?:e|ed|ion|ing))\b", re.I),
    re.compile(r"\bnot yet (?:supported|implemented)\b", re.I),
    re.compile(r"\b(?:did not|unable to) (?:resolve|bind)\b", re.I),
    re.compile(r"\bunknown (?:task|function|method)\b", re.I),
    re.compile(r"nonblocking .* blocking", re.I),
)
OPENTITAN_RUNTIME_PASS_RE = re.compile(
    r"^TEST PASSED (?:UVM_)?CHECKS$", re.I | re.M
)
SPID_JEDEC_CHECKED_PASS_RE = re.compile(r"^SPI Flash Read JEDEC ID Tested!!:$", re.M)
SPID_UPLOAD_CHECKED_PASS_RE = re.compile(r"^All payloads are read out\.$", re.M)
SPI_TPM_COMPLETION_RE = re.compile(r"^Host transactions has ended\.$", re.M)
SPI_TPM_PASS_RE = re.compile(r"^TEST PASSED!$", re.M)


def opentitan_runtime_pass_marker(core: str, output: str) -> bool:
    return bool(
        OPENTITAN_RUNTIME_PASS_RE.search(output)
        or (
            core == "lowrisc:dv:spid_jedec_sim:0.1"
            and SPID_JEDEC_CHECKED_PASS_RE.search(output)
        )
        or (
            core == "lowrisc:dv:spid_upload_sim:0.1"
            and SPID_UPLOAD_CHECKED_PASS_RE.search(output)
        )
        or (
            core == "lowrisc:dv:spi_tpm_sim:0.1"
            and SPI_TPM_COMPLETION_RE.search(output)
            and SPI_TPM_PASS_RE.search(output)
            and not re.search(r"^TEST TIMED OUT!!$", output, re.M)
        )
    )


OPENTITAN_RUNTIME_FAIL_PATTERNS = (
    re.compile(r"^UVM_ERROR\s[^:].*$", re.I),
    re.compile(r"^UVM_FATAL\s[^:].*$", re.I),
    re.compile(r"^UVM_WARNING\s[^:].*$", re.I),
    re.compile(r"^Assert failed: ", re.I),
    re.compile(r"^\s*Offending '.*'", re.I),
    re.compile(r"^TEST FAILED (?:UVM_)?CHECKS$", re.I),
    re.compile(r"(?:^|:\s*)TEST TIMED OUT!!$"),
    re.compile(r"^Error:.*$", re.I),
    re.compile(r"^DPI error:.*$", re.I),
)
RUNTIME_ERROR_ALLOWLIST = (
    re.compile(r"^----\| has Configuration error:\s+FALSE$"),
)
RUNTIME_DEBT_ALLOWLIST = (
    # IEEE 1800 permits a function call as a statement with its return value
    # discarded. Icarus deliberately emits this optional diagnostic from its
    # VPI runtime; Slang and Verilator accept the same call without warning.
    re.compile(r"Warning: Calling system function \$system\(\) as a task\.", re.I),
    re.compile(r"The functions return value will be ignored\.", re.I),
    # OpenTitan's scoreboard reports these counters as info; zero means no data
    # was dropped. Positive counts remain runtime debt.
    re.compile(r"\b(?:seeds|words) assumed dropped from [^:]+:\s*0\s*$", re.I),
)
# Compiler warnings that describe the source accurately and change nothing
# about how it simulates. They stay in the record as benign diagnostics.
COMPILE_DEBT_ALLOWLIST = (
    # A lint notice: IEEE 1800 does not forbid nonblocking assignments in
    # always_comb, and OpenTitan's generated CSR assertion modules use them.
    re.compile(r"warning: A non-blocking assignment should not be used in an "
               r"always_comb process\.", re.I),
    # Port coercion of an input driven from both sides (IEEE 1800 23.3.3);
    # the net resolves exactly as declared inout.
    re.compile(r"warning: input port \S+ is coerced to inout\.", re.I),
    # IEEE 1800 13.4.1: a function may be called as a statement; its
    # return value is discarded.
    re.compile(r"warning: User function '\S+' is being called as a task\.", re.I),
    # Synthesizability lint for always_* bodies, including subroutines they
    # call (a UVM report from an assertion action). IEEE 1800 does not require
    # these processes to be synthesizable, and simulation is unaffected.
    re.compile(r"warning: .* (?:cannot be synthesized|must be automatic to be "
               r"synthesized) in an always_(?:comb|ff|latch) process\.", re.I),
)
TIMESCALE_MIXED_WARNING_RE = re.compile(
    r"^warning: Found both default and explicit timescale based delays\. Use$",
    re.I,
)


def compile_debt_allowlist(timescale: str | None) -> tuple[re.Pattern[str], ...]:
    """Allow mixed-timescale notice only when the job declares its default."""
    if not timescale:
        return COMPILE_DEBT_ALLOWLIST
    # OpenTitan's simulation config supplies the default for modules without
    # timeunit declarations; modules with explicit timeunits keep their units.
    return (*COMPILE_DEBT_ALLOWLIST, TIMESCALE_MIXED_WARNING_RE)


SETUP_ALLOWLIST = (
    re.compile(r"No trustfile configured .* signatures will not be checked", re.I),
    # This is an Edalize API-lifecycle notice.  It does not change the selected
    # sources, provider mapping, compiler invocation, or HDL semantics.
    re.compile(r"This backend is deprecated .* migrate to the flow API", re.I),
)
NATIVE_SOURCE_SETUP_WARNING_RE = re.compile(
    r"^WARNING: (?P<path>.+) has unknown file type '(?:cSource|cppSource)'$"
)
PYTHON_SOURCE_SETUP_WARNING_RE = re.compile(
    r"^WARNING: (?P<path>.+\.py) has unknown file type ''$"
)
NO_TOPLEVEL_RE = re.compile(r"Target '[^']+' has no toplevel", re.I)
MODULE_DECL_RE = re.compile(
    r"^\s*(?:module|macromodule)\s+(?:automatic\s+|static\s+)?([A-Za-z_][\w$]*)",
    re.M,
)


@dataclasses.dataclass(frozen=True)
class UpstreamDefect:
    """A pinned-revision OpenTitan source or metadata defect.

    A record is reclassified only when the phase matches and every hard
    diagnostic matches the fingerprint, so any new failure mode still
    surfaces as FAIL.
    """

    core: str  # VLNV without the version component
    phase: str  # "setup" or "compile"
    fingerprint: re.Pattern[str]
    note: str


KNOWN_UPSTREAM_DEFECTS = (
    UpstreamDefect(
        "lowrisc:darjeeling_dv:rstmgr_sim",
        "compile",
        re.compile(
            r"fixed unpacked-array value and queue/dynamic-array context "
            r"may differ only in the slowest-varying unpacked dimension"
        ),
        "rstmgr_base_vseq.sv passes ral.sw_rst_ctrl_n -- a FIXED unpacked "
        "array of a DERIVED register type -- to rstmgr_csr_wr_unpack's "
        "`input uvm_object ptr[]', a dynamic array of the BASE class. IEEE "
        "1800-2017/2023 7.6 permits fixed <-> dynamic assignment only when "
        "the element types are EQUIVALENT; base and derived class handles "
        "are assignment-compatible but not equivalent. slang 11.0.448 "
        "rejects the identical line under --std 1800-2017 and 1800-2023, "
        "and the equivalent-element case compiles and runs correctly on "
        "Icarus, so this is not a fixed-to-dynamic gap.",
    ),
    UpstreamDefect(
        "lowrisc:earlgrey_dv:rstmgr_sim",
        "compile",
        re.compile(
            r"fixed unpacked-array value and queue/dynamic-array context "
            r"may differ only in the slowest-varying unpacked dimension"
        ),
        "rstmgr_base_vseq.sv passes ral.sw_rst_ctrl_n -- a FIXED unpacked "
        "array of a DERIVED register type -- to rstmgr_csr_wr_unpack's "
        "`input uvm_object ptr[]', a dynamic array of the BASE class. IEEE "
        "1800-2017/2023 7.6 permits fixed <-> dynamic assignment only when "
        "the element types are EQUIVALENT; base and derived class handles "
        "are assignment-compatible but not equivalent. slang 11.0.448 "
        "rejects the identical line under both editions.",
    ),
    UpstreamDefect(
        "lowrisc:ip:ascon",
        "compile",
        re.compile(r"This assignment requires an explicit cast"),
        "ascon_core.sv assigns plain logic vectors to enum-typed signals "
        "(duplex_op_e and friends). IEEE 1800-2017 6.19.3 requires an "
        "explicit cast; slang 11.0 rejects the same lines.",
    ),
    UpstreamDefect(
        "lowrisc:ip:aes_wrap",
        "compile",
        re.compile(
            r"cannot have multiple drivers"
            r"|must support a continuous assignment"
        ),
        "aes_wrap.sv drives all of h2d_intg from tlul_cmd_intg_gen and "
        "separately drives h2d_intg.a_user.data_intg from "
        "prim_secded_inv_39_32_enc. IEEE 1800-2017 10.3 forbids "
        "overlapping continuous drives of one variable; slang rejects "
        "the same overlap.",
    ),
    UpstreamDefect(
        "lowrisc:darjeeling_ip:otp_ctrl_top_specific_pkg",
        "compile",
        re.compile(r"Unknown package `otp_ctrl_macro_pkg'"),
        "otp_ctrl_top_specific_pkg.core omits the otp_ctrl_macro_pkg "
        "dependency its own package imports, so the standalone fileset "
        "cannot compile with any tool.",
    ),
    UpstreamDefect(
        "lowrisc:earlgrey_ip:otp_ctrl_top_specific_pkg",
        "compile",
        re.compile(r"Unknown package `otp_ctrl_macro_pkg'"),
        "otp_ctrl_top_specific_pkg.core omits the otp_ctrl_macro_pkg "
        "dependency its own package imports, so the standalone fileset "
        "cannot compile with any tool.",
    ),
    UpstreamDefect(
        "lowrisc:englishbreakfast_ip:rstmgr",
        "compile",
        re.compile(r"rstmgr\.sv:\d+: (?:syntax error|error:)"),
        "englishbreakfast rstmgr.sv references alert_handler_pkg but the "
        "core fileset never provides it (englishbreakfast has no alert "
        "handler), so the standalone compile fails on the unresolved "
        "package type.",
    ),
    UpstreamDefect(
        "lowrisc:prim:prim_dom_and_2share",
        "compile",
        re.compile(r"Unknown module type: prim_(?:xor2|flop_en)"),
        "prim_dom_and_2share.core does not depend on the prim xor2 / "
        "flop_en abstraction cores its RTL instantiates.",
    ),
    UpstreamDefect(
        "lowrisc:tlul:lc_gate",
        "compile",
        re.compile(
            r"Unknown module type: (?:tlul_err_resp|prim_sec_anchor_buf)"
        ),
        "tlul_lc_gate.core does not depend on the tlul err_resp and prim "
        "sec_anchor_buf providers its RTL instantiates.",
    ),
    UpstreamDefect(
        "lowrisc:tlul:request_loopback",
        "compile",
        re.compile(r"Unknown module type: tlul_socket_1n"),
        "tlul_request_loopback.core does not depend on the tlul "
        "socket_1n core it instantiates.",
    ),
    UpstreamDefect(
        "lowrisc:earlgrey_ip:flash_ctrl_prim_reg_top",
        "compile",
        re.compile(
            r"Unknown module type: (?:tlul_cmd_intg_chk|tlul_rsp_intg_gen"
            r"|tlul_adapter_reg|prim_reg_we_check)"
        ),
        "flash_ctrl_prim_reg_top.core declares a stale lc_ctrl toplevel "
        "and omits the tlul adapter / integrity and prim_reg_we_check "
        "dependencies its reg_top instantiates; the standalone fileset "
        "cannot elaborate with any tool.",
    ),
    UpstreamDefect(
        "lowrisc:englishbreakfast_ip:flash_ctrl_prim_reg_top",
        "compile",
        re.compile(
            r"Unknown module type: (?:tlul_cmd_intg_chk|tlul_rsp_intg_gen"
            r"|tlul_adapter_reg|prim_reg_we_check)"
        ),
        "flash_ctrl_prim_reg_top.core declares a stale lc_ctrl toplevel "
        "and omits the tlul adapter / integrity and prim_reg_we_check "
        "dependencies its reg_top instantiates; the standalone fileset "
        "cannot elaborate with any tool.",
    ),
    UpstreamDefect(
        "lowrisc:fpv:prim_alert_rxtx_fatal_fpv",
        "compile",
        re.compile(
            r"bind target module/interface 'prim_alert_rxtx(?:_async)?_tb' "
            r"is not defined"
        ),
        "The fatal-variant FPV core binds assertions into "
        "prim_alert_rxtx_tb, but its fileset never provides that "
        "testbench module (it lives in the non-fatal prim_alert_rxtx_fpv "
        "core); the bind target is absent from the compilation.",
    ),
    UpstreamDefect(
        "lowrisc:fpv:prim_alert_rxtx_async_fatal_fpv",
        "compile",
        re.compile(
            r"bind target module/interface 'prim_alert_rxtx(?:_async)?_tb' "
            r"is not defined"
        ),
        "The fatal-variant FPV core binds assertions into "
        "prim_alert_rxtx_async_tb, but its fileset never provides that "
        "testbench module (it lives in the non-fatal FPV core); the "
        "bind target is absent from the compilation.",
    ),
    UpstreamDefect(
        "lowrisc:darjeeling_systems:pinmux_chip_fpv",
        "compile",
        re.compile(r"Unknown package `top_darjeeling_pkg'"),
        "pinmux_chip_fpv imports the full chip package but its fileset "
        "does not depend on the top package core; the standalone "
        "compile cannot resolve the import with any tool.",
    ),
    UpstreamDefect(
        "lowrisc:earlgrey_systems:pinmux_chip_fpv",
        "compile",
        re.compile(r"Unknown package `top_earlgrey_pkg'"),
        "pinmux_chip_fpv imports the full chip package but its fileset "
        "does not depend on the top package core; the standalone "
        "compile cannot resolve the import with any tool.",
    ),
    UpstreamDefect(
        "lowrisc:englishbreakfast_systems:pinmux_chip_fpv",
        "compile",
        re.compile(r"Unknown package `top_englishbreakfast_pkg'"),
        "pinmux_chip_fpv imports the full chip package but its fileset "
        "does not depend on the top package core; the standalone "
        "compile cannot resolve the import with any tool.",
    ),
    UpstreamDefect(
        "lowrisc:englishbreakfast_dv:rstmgr_sva",
        "compile",
        re.compile(r"rstmgr\.sv:\d+: (?:syntax error|error: )"),
        "englishbreakfast rstmgr.sv references alert_handler_pkg but "
        "the fileset never provides it (englishbreakfast has no alert "
        "handler), so the standalone compile fails on the unresolved "
        "package type.",
    ),
    UpstreamDefect(
        "lowrisc:englishbreakfast_dv:clkmgr_sva",
        "compile",
        re.compile(
            r"Failed to elaborate .*port .*clk_hints"
            r"|Member clk_main_aes_\w+ is not a member"
        ),
        "The shared clkmgr SVA collateral connects "
        "reg2hw.clk_hints.clk_main_aes_hint and the matching status "
        "field, but englishbreakfast's autogen clkmgr_reg_pkg declares "
        "no such registers; the bind expressions cannot elaborate "
        "against this top's RTL with any tool.",
    ),
    UpstreamDefect(
        "lowrisc:darjeeling_dv:otp_ctrl_sva",
        "compile",
        re.compile(
            r"bind target module/interface 'otp_macro' is not defined"
        ),
        "otp_ctrl_bind.sv binds tlul_assert into otp_macro, but the "
        "otp_ctrl_sva fileset only depends on otp_macro_pkg, never the "
        "otp_macro module; the bind target is absent from the "
        "compilation, so the standalone fileset cannot elaborate with "
        "any tool.",
    ),
    UpstreamDefect(
        "lowrisc:earlgrey_dv:otp_ctrl_sva",
        "compile",
        re.compile(
            r"bind target module/interface 'otp_macro' is not defined"
        ),
        "otp_ctrl_bind.sv binds tlul_assert into otp_macro, but the "
        "otp_ctrl_sva fileset only depends on otp_macro_pkg, never the "
        "otp_macro module; the bind target is absent from the "
        "compilation, so the standalone fileset cannot elaborate with "
        "any tool.",
    ),
    UpstreamDefect(
        "lowrisc:fpv:sha3_fpv",
        "compile",
        re.compile(
            r"Wildcard named port connection \(\.\*\) did not find a "
            r"matching identifier for port"
        ),
        "sha3_fpv.sv instantiates sha3 with .* but declares no "
        "rand_update_o (and related entropy ports) in its own port "
        "list; IEEE 1800-2017 23.3.2.4 requires a matching identifier "
        "for every port, so the stale FPV wrapper cannot elaborate "
        "against the pinned RTL with any tool.",
    ),
    UpstreamDefect(
        "lowrisc:fpv:sha3pad_fpv",
        "compile",
        re.compile(
            r"Wildcard named port connection \(\.\*\) did not find a "
            r"matching identifier for port"
        ),
        "sha3pad_fpv.sv instantiates its DUT with .* but does not "
        "declare the rand/entropy ports the pinned RTL added; "
        "IEEE 1800-2017 23.3.2.4 requires a matching identifier for "
        "every port, so the stale FPV wrapper cannot elaborate with "
        "any tool.",
    ),
    UpstreamDefect(
        "lowrisc:systems:chip_earlgrey_asic",
        "compile",
        re.compile(r"Unable to bind wire/reg/memory `u_state_regs\.err_o'"),
        "otp_macro.sv's PrimRegWeOneHotCheck ASSUME_FPV references "
        "u_state_regs.err_o, but prim_sparse_fsm_flop declares only "
        "unused_err_o (the sibling assumptions use it); the signal does "
        "not exist, so no tool can bind the reference.",
    ),
    UpstreamDefect(
        "lowrisc:systems:chip_darjeeling_asic",
        "compile",
        re.compile(r"Unable to bind wire/reg/memory `u_state_regs\.err_o'"),
        "otp_macro.sv's PrimRegWeOneHotCheck ASSUME_FPV references "
        "u_state_regs.err_o, but prim_sparse_fsm_flop declares only "
        "unused_err_o (the sibling assumptions use it); the signal does "
        "not exist, so no tool can bind the reference.",
    ),
    UpstreamDefect(
        "lowrisc:systems:top_earlgrey",
        "compile",
        re.compile(r"Unable to bind wire/reg/memory `.*u_otp_macro"
                   r"|Unable to bind wire/reg/memory `u_state_regs\.err_o'"),
        "otp_macro.sv's PrimRegWeOneHotCheck ASSUME_FPV references "
        "u_state_regs.err_o, but prim_sparse_fsm_flop declares only "
        "unused_err_o; the signal does not exist, so no tool can bind "
        "the reference.",
    ),
    UpstreamDefect(
        "lowrisc:systems:top_darjeeling",
        "compile",
        re.compile(r"Unable to bind wire/reg/memory `.*u_otp_macro"
                   r"|Unable to bind wire/reg/memory `u_state_regs\.err_o'"),
        "otp_macro.sv's PrimRegWeOneHotCheck ASSUME_FPV references "
        "u_state_regs.err_o, but prim_sparse_fsm_flop declares only "
        "unused_err_o; the signal does not exist, so no tool can bind "
        "the reference.",
    ),
    UpstreamDefect(
        "lowrisc:fpv:keccak_round_fpv",
        "compile",
        re.compile(r"of module keccak_round expects 4 bit\(s\), given 1"),
        "keccak_round_fpv.sv still drives the 1-bit clear signal it was "
        "written for, but the pinned keccak_round.sv converted clear_i "
        "to prim_mubi_pkg::mubi4_t (a 4-bit enum). The padded value is "
        "never a valid mubi constant and slang rejects the implicit "
        "logic-to-enum port conversion; the FPV testbench is stale "
        "against the RTL.",
    ),
    UpstreamDefect(
        "lowrisc:fpv:keccak_2share_fpv",
        "compile",
        re.compile(
            r"keccak_2share_fpv\.sv:\d+: (?:syntax error|error: )"
        ),
        "At the pinned revision, keccak_2share_fpv.sv is missing an `end` "
        "after the StPhase1 else block and does not import prim_mubi_pkg. "
        "Correcting those exposes obsolete cycle_i and rand_aux_i port "
        "connections on both keccak_2share instances; the current DUT instead "
        "has DOM control and lifecycle inputs. Matching those requires an "
        "FPV control-model update, so this target remains upstream-invalid. "
        "Slang 11.0 independently reports the original missing `end`.",
    ),
    UpstreamDefect(
        "lowrisc:fpv:rv_timer_fpv",
        "compile",
        re.compile(
            r"Variable '\w+' cannot be driven by a continuous assignment"
            r"|Output port expression must support a continuous assignment"
        ),
        "rv_timer_interrupts_assert_fpv is an empty 'TODO: populate me' "
        "stub that declares intr_o and the hw2reg_intr_state ports as "
        "outputs; the wildcard bind into prim_intr_hw therefore drives "
        "the target's own outputs a second time (IEEE 1800-2017 10.3). "
        "The checker's port directions are wrong upstream.",
    ),
    UpstreamDefect(
        "lowrisc:fpv:prim_packer_fpv",
        "compile",
        re.compile(
            r"Variable '\w+' cannot have multiple drivers"
            r"|Output port expression must support a continuous assignment"
        ),
        "prim_packer_tb.sv instantiates sixteen prim_packer DUTs in one "
        "generate loop, all driving the same valid_o/ready_o/"
        "flush_done_o/err_o scalars and overlapping data_o/mask_o "
        "slices. IEEE 1800-2017 10.3 forbids overlapping continuous "
        "drives of one variable; the FPV testbench relies on formal-tool "
        "net resolution.",
    ),
    UpstreamDefect(
        "lowrisc:fpv:prim_lfsr_fpv",
        "compile",
        re.compile(
            r"Variable 'state_o' cannot have multiple drivers"
            r"|Output port expression must support a continuous assignment"
        ),
        "prim_lfsr_tb.sv's gen_gal_xor_duts_nonlinear loop reuses the "
        "linear loop's index (Idx = k - GalXorMinLfsrDw), so both "
        "generate blocks drive state_o[Idx] for every power-of-two "
        "width. IEEE 1800-2017 10.3 forbids overlapping continuous "
        "drives of one variable; the FPV testbench is only tolerated by "
        "JasperGold's net resolution.",
    ),
    UpstreamDefect(
        "lowrisc:earlgrey_fpv:pinmux_fpv",
        "compile",
        re.compile(
            r"An assignment pattern needs a context that gives it a type"
        ),
        "pinmux_assert_fpv.sv compares mio_attr_o entries against bare "
        "assignment patterns ('{schmitt_en: 1'b1, default: '0}') inside "
        "property expressions. IEEE 1800-2017 10.9 gives assignment "
        "patterns no self-determined type in an equality operand; slang "
        "11.0 rejects the same construct ('assignment pattern target "
        "type cannot be deduced in this context').",
    ),
    UpstreamDefect(
        "lowrisc:englishbreakfast_fpv:pinmux_fpv",
        "compile",
        re.compile(
            r"An assignment pattern needs a context that gives it a type"
        ),
        "pinmux_assert_fpv.sv compares mio_attr_o entries against bare "
        "assignment patterns ('{schmitt_en: 1'b1, default: '0}') inside "
        "property expressions. IEEE 1800-2017 10.9 gives assignment "
        "patterns no self-determined type in an equality operand; slang "
        "11.0 rejects the same construct ('assignment pattern target "
        "type cannot be deduced in this context').",
    ),
    UpstreamDefect(
        "lowrisc:darjeeling_dv:rv_core_ibex_sva",
        "compile",
        re.compile(
            r"Failed to elaborate .*port .* in instance "
            r"dut\.tlul_assert_host_(?:instr|data)"
        ),
        "rv_core_ibex_bind.sv connects tlul_assert to rv_core_ibex "
        "signals tl_i_o/tl_i_i/tl_d_o/tl_d_i that do not exist in the "
        "pinned rv_core_ibex.sv (its TL ports are cfg_tl_d_i/cfg_tl_d_o); "
        "the bind collateral is stale against the RTL.",
    ),
    UpstreamDefect(
        "lowrisc:earlgrey_dv:rv_core_ibex_sva",
        "compile",
        re.compile(
            r"Failed to elaborate .*port .* in instance "
            r"dut\.tlul_assert_host_(?:instr|data)"
        ),
        "rv_core_ibex_bind.sv connects tlul_assert to rv_core_ibex "
        "signals tl_i_o/tl_i_i/tl_d_o/tl_d_i that do not exist in the "
        "pinned rv_core_ibex.sv (its TL ports are cfg_tl_d_i/cfg_tl_d_o); "
        "the bind collateral is stale against the RTL.",
    ),
    UpstreamDefect(
        "lowrisc:englishbreakfast_dv:rv_core_ibex_sva",
        "compile",
        re.compile(
            r"Failed to elaborate .*port .* in instance "
            r"dut\.tlul_assert_host_(?:instr|data)"
        ),
        "rv_core_ibex_bind.sv connects tlul_assert to rv_core_ibex "
        "signals tl_i_o/tl_i_i/tl_d_o/tl_d_i that do not exist in the "
        "pinned rv_core_ibex.sv (its TL ports are cfg_tl_d_i/cfg_tl_d_o); "
        "the bind collateral is stale against the RTL.",
    ),
    UpstreamDefect(
        "lowrisc:systems:top_englishbreakfast",
        "compile",
        re.compile(r"of module prim_ram_1p_scr expects \d+ bit"),
        "top_englishbreakfast.sv autogen declares SramCtrlMainInstSize "
        "= 4096 with SramCtrlMainNumRamInst = 1, which is internally "
        "inconsistent for its main SRAM (32 instances would be needed); "
        "only an ASSERT_INIT that -DSYNTHESIS strips guards it, so the "
        "sram_ctrl/prim_ram_1p_scr cfg ports genuinely mismatch. "
        "Earlgrey's autogen uses InstSize = 131072 and is consistent.",
    ),
    UpstreamDefect(
        "lowrisc:systems:chip_englishbreakfast_verilator",
        "compile",
        re.compile(r"of module prim_ram_1p_scr expects \d+ bit"),
        "top_englishbreakfast.sv autogen declares SramCtrlMainInstSize "
        "= 4096 with SramCtrlMainNumRamInst = 1, which is internally "
        "inconsistent for its main SRAM (32 instances would be needed); "
        "only an ASSERT_INIT that -DSYNTHESIS strips guards it, so the "
        "sram_ctrl/prim_ram_1p_scr cfg ports genuinely mismatch. "
        "Earlgrey's autogen uses InstSize = 131072 and is consistent.",
    ),
    UpstreamDefect(
        "lowrisc:darjeeling_fpv:pinmux_fpv",
        "compile",
        re.compile(r"parameter `SecVolatileRawUnlockEn` not found"
                   r"|Unable to bind parameter `SecVolatileRawUnlockEn'"),
        "darjeeling's pinmux_tb.sv overrides SecVolatileRawUnlockEn, "
        "but darjeeling's autogen pinmux.sv no longer declares that "
        "parameter; IEEE 1800-2017 23.10 makes overriding a "
        "nonexistent parameter an error, so the FPV testbench is stale "
        "against the RTL.",
    ),
    UpstreamDefect(
        "lowrisc:dv:spi_host_sva",
        "setup",
        re.compile(
            r"Fileset 'files_formal', requested by target 'formal', "
            r"was not found"
        ),
        "spi_host_sva.core's formal target requests a files_formal "
        "fileset the core never defines; FuseSoC cannot set the job up "
        "at the pinned revision.",
    ),
    UpstreamDefect(
        "lowrisc:ibex:ibex_riscv_compliance",
        "setup",
        re.compile(r"has no target 'default'"),
        "The vendored ibex core defines no default target at this "
        "revision.",
    ),
    UpstreamDefect(
        "lowrisc:ibex:tb_cs_registers",
        "setup",
        re.compile(r"has no target 'default'"),
        "The vendored ibex core defines no default target at this "
        "revision.",
    ),
    UpstreamDefect(
        "lowrisc:ibex:ibex_simple_system_cosim",
        "setup",
        re.compile(r"depends on missing packages"),
        "The core depends on packages absent from the pinned OpenTitan "
        "revision.",
    ),
    UpstreamDefect(
        "lowrisc:ip:i3c",
        "setup",
        re.compile(r"depends on missing packages"),
        "The core depends on packages absent from the pinned OpenTitan "
        "revision (lowrisc:ip:i3c_pkg is not in the tree).",
    ),
    UpstreamDefect(
        "lowrisc:systems:chip_earlgrey_cw340",
        "setup",
        re.compile(r"Conflicting requirements"),
        "The core depends on board/support packages absent from the "
        "pinned OpenTitan revision.",
    ),
    UpstreamDefect(
        "lowrisc:systems:chip_englishbreakfast_cw305",
        "setup",
        re.compile(r"Conflicting requirements"),
        "The core depends on board/support packages absent from the "
        "pinned OpenTitan revision.",
    ),
)


def upstream_defect_for(
    core_vlnv: str, phase: str, diagnostics: Sequence[str]
) -> UpstreamDefect | None:
    """Match a known upstream defect; every diagnostic must fit."""
    base = core_vlnv.rsplit(":", 1)[0]
    for defect in KNOWN_UPSTREAM_DEFECTS:
        if defect.core != base or defect.phase != phase:
            continue
        if diagnostics and all(
            defect.fingerprint.search(line) for line in diagnostics
        ):
            return defect
    return None


@dataclasses.dataclass(frozen=True)
class Core:
    vlnv: str
    description: str

    @property
    def library(self) -> str:
        return self.vlnv.split(":", 3)[1]

    @property
    def name(self) -> str:
        return self.vlnv.split(":", 3)[2]


@dataclasses.dataclass(frozen=True)
class SimulationTarget:
    """Authoritative metadata for one literal FuseSoC `sim` target."""

    vlnv: str
    category: str
    default_tool: str
    toplevels: tuple[str, ...]
    core_file: str
    runtime_args: tuple[str, ...] = ()
    dvsim_config: str | None = None
    dvsim_test: str | None = None
    uvm_test: str | None = None
    uvm_test_seq: str | None = None
    dvsim_regression: str | None = None
    build_mode: str | None = None
    build_options: tuple[str, ...] = ()
    native_dependencies: tuple[str, ...] = ()
    dpi_dependencies: tuple[str, ...] = ()
    orchestration_requirements: tuple[str, ...] = ()
    unresolved_runtime_options: tuple[str, ...] = ()
    metadata_warnings: tuple[str, ...] = ()
    timescale: str | None = None
    requires_uvm_library: bool = False
    native_sources: tuple[str, ...] = ()
    native_include_dirs: tuple[str, ...] = ()

    @property
    def uvm_runtime_configured(self) -> bool:
        return bool(self.uvm_test and self.uvm_test_seq)


@dataclasses.dataclass(frozen=True)
class Job:
    lane: str
    core: Core
    simulation: SimulationTarget | None = None

    @property
    def target(self) -> str:
        if self.lane == "sva" and self.core.vlnv in SVA_DEFAULT_TARGETS:
            return "default"
        return TARGETS[self.lane]


@dataclasses.dataclass
class CommandResult:
    command: list[str]
    returncode: int
    output: str
    duration_seconds: float
    timed_out: bool = False
    memory_limit_hit: bool = False
    peak_physical_footprint_bytes: int | None = None
    memory_monitor_error: str | None = None


ACTIVE_PROCESSES: set[subprocess.Popen[str]] = set()
ACTIVE_PROCESSES_LOCK = threading.Lock()


def signal_command_tree(process: subprocess.Popen[str], sig: int) -> None:
    """Signal a command and every child in the session created for it."""
    try:
        if os.name == "posix":
            os.killpg(process.pid, sig)
        elif process.poll() is None:
            process.send_signal(sig)
    except (ProcessLookupError, PermissionError):
        if process.poll() is None:
            process.send_signal(sig)


def terminate_active_commands() -> None:
    """Stop in-flight command trees when the matrix itself is interrupted."""
    with ACTIVE_PROCESSES_LOCK:
        processes = tuple(ACTIVE_PROCESSES)
    for process in processes:
        signal_command_tree(process, signal.SIGTERM)


def command_result(
    command: Sequence[str],
    *,
    cwd: Path,
    env: dict[str, str],
    timeout: int,
    memory_limit_bytes: int | None = None,
) -> CommandResult:
    if memory_limit_bytes is not None:
        return memory_guarded_command_result(
            command, cwd=cwd, env=env, timeout=timeout,
            memory_limit_bytes=memory_limit_bytes,
        )
    started = time.monotonic()
    process = subprocess.Popen(
        list(command),
        cwd=cwd,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        start_new_session=os.name == "posix",
    )
    with ACTIVE_PROCESSES_LOCK:
        ACTIVE_PROCESSES.add(process)
    try:
        output, _ = process.communicate(timeout=timeout)
        return CommandResult(
            list(command),
            process.returncode,
            output,
            time.monotonic() - started,
        )
    except subprocess.TimeoutExpired:
        signal_command_tree(process, signal.SIGTERM)
        try:
            output, _ = process.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            signal_command_tree(process, signal.SIGKILL)
            output, _ = process.communicate()
        return CommandResult(
            list(command), 124, output, time.monotonic() - started, True
        )
    except KeyboardInterrupt:
        signal_command_tree(process, signal.SIGTERM)
        try:
            process.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            signal_command_tree(process, signal.SIGKILL)
            process.communicate()
        raise
    finally:
        with ACTIVE_PROCESSES_LOCK:
            ACTIVE_PROCESSES.discard(process)


def memory_guarded_command_result(
    command: Sequence[str],
    *,
    cwd: Path,
    env: dict[str, str],
    timeout: int,
    memory_limit_bytes: int,
) -> CommandResult:
    """Stop one runtime process group when macOS reports excessive footprint."""
    started = time.monotonic()
    peak = 0
    timed_out = False
    memory_limit_hit = False
    monitor_error = None
    with tempfile.TemporaryFile(mode="w+t", encoding="utf-8", errors="replace") as output_file:
        process = subprocess.Popen(
            list(command), cwd=cwd, env=env, stdout=output_file,
            stderr=subprocess.STDOUT, text=True, start_new_session=True,
        )
        with ACTIVE_PROCESSES_LOCK:
            ACTIVE_PROCESSES.add(process)
        try:
            while process.poll() is None:
                if time.monotonic() - started >= timeout:
                    timed_out = True
                    break
                try:
                    sample = subprocess.run(
                        ["/usr/bin/footprint", "--noCategories", "--swapped",
                         "-f", "bytes", "-p", str(process.pid)],
                        capture_output=True, text=True, timeout=10, check=False,
                    )
                except subprocess.TimeoutExpired:
                    monitor_error = "footprint sampling timed out"
                    break
                except OSError as exc:
                    monitor_error = f"footprint launch failed: {exc}"
                    break
                if time.monotonic() - started >= timeout:
                    timed_out = True
                    break
                if process.poll() is not None and sample.returncode != 0:
                    break
                if sample.returncode != 0:
                    # A large process can sit in exit teardown for seconds
                    # after $finish: footprint no longer finds it but poll()
                    # still reports it running. That is a normal exit, not a
                    # monitor failure, so give it a grace period to finish.
                    try:
                        process.wait(timeout=30)
                        break
                    except subprocess.TimeoutExpired:
                        pass
                match = re.search(r"^\s*phys_footprint:\s*(\d+) B\s*$",
                                  sample.stdout, re.MULTILINE)
                if sample.returncode != 0 or match is None:
                    monitor_error = (
                        sample.stderr.strip() or "footprint output had no phys_footprint"
                    )
                    break
                peak = max(peak, int(match.group(1)))
                if peak > memory_limit_bytes:
                    memory_limit_hit = True
                    break
                time.sleep(min(1, max(0, timeout - (time.monotonic() - started))))
            if time.monotonic() - started >= timeout:
                timed_out = True
            if timed_out or memory_limit_hit or monitor_error:
                signal_command_tree(process, signal.SIGTERM)
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    pass
                signal_command_tree(process, signal.SIGKILL)
                process.wait()
            output_file.seek(0)
            output = output_file.read()
            if memory_limit_hit:
                output += (f"\nmatrix runtime memory limit: {peak} > "
                           f"{memory_limit_bytes} physical-footprint bytes\n")
            if monitor_error:
                output += f"\nmatrix runtime memory monitor failed: {monitor_error}\n"
            return CommandResult(
                list(command),
                124 if timed_out else 125 if memory_limit_hit else 126 if monitor_error
                else process.returncode,
                output,
                time.monotonic() - started,
                timed_out,
                memory_limit_hit,
                peak or None,
                monitor_error,
            )
        except KeyboardInterrupt:
            signal_command_tree(process, signal.SIGTERM)
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                pass
            signal_command_tree(process, signal.SIGKILL)
            process.wait()
            raise
        finally:
            with ACTIVE_PROCESSES_LOCK:
                ACTIVE_PROCESSES.discard(process)


def short_command(command: Sequence[str]) -> str:
    return shlex.join(str(part) for part in command)


def git_value(root: Path, *args: str) -> str:
    completed = subprocess.run(
        ["git", *args],
        cwd=root,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        check=False,
    )
    return completed.stdout.strip() if completed.returncode == 0 else "unknown"


def tool_version(command: Sequence[str], cwd: Path, env: dict[str, str]) -> str:
    result = command_result(command, cwd=cwd, env=env, timeout=30)
    lines = [line.strip() for line in result.output.splitlines() if line.strip()]
    return lines[0] if lines else "unknown"


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def directory_sha256(root: Path) -> str:
    """Hash file names and contents so an installed source tree is identifiable."""
    digest = hashlib.sha256()
    for path in sorted(
        candidate for candidate in root.rglob("*") if candidate.is_file()
    ):
        digest.update(path.relative_to(root).as_posix().encode())
        digest.update(b"\0")
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
        digest.update(b"\0")
    return digest.hexdigest()


def compiler_fingerprint(
    iverilog: Path, vvp: Path, uvm_home: Path | None = None
) -> dict[str, object]:
    """Fingerprint the engine and targets, not only the stable driver binary."""
    ivl_root = iverilog.parent.parent / "lib" / "ivl"
    candidates = {
        "driver": iverilog,
        "compiler_engine": ivl_root / "ivl",
        "vvp_target": ivl_root / "vvp.tgt",
        "vvp_runtime": vvp,
        "normal_config": ivl_root / "vvp.conf",
        "synthesis_config": ivl_root / "vvp-s.conf",
        "uvm_dpi": ivl_root / "uvm_dpi.vpi",
    }
    components = {
        name: {"path": str(path), "sha256": file_sha256(path)}
        for name, path in candidates.items()
        if path.is_file()
    }
    uvm_sources = uvm_home or ivl_root / "uvm" / "src"
    result: dict[str, object] = {"components": components}
    if uvm_sources.is_dir():
        result["uvm_sources"] = {
            "path": str(uvm_sources),
            "sha256": directory_sha256(uvm_sources),
        }
    return result


def _python_interpreter(
    path: Path, arguments: Sequence[str] = ()
) -> tuple[str, ...] | None:
    """Return a safe Python command prefix, rejecting other shebang programs."""
    # Keep a virtual environment's logical symlink path. Resolving it to the
    # base interpreter bypasses pyvenv.cfg and silently changes sys.path.
    executable = path.expanduser().absolute()
    if not executable.is_file() or not os.access(executable, os.X_OK):
        return None
    if not re.fullmatch(
        r"(?:python(?:\d+(?:\.\d+)*)?|pypy(?:\d+(?:\.\d+)*)?)(?:\.exe)?",
        executable.name,
        re.I,
    ):
        return None
    safe_arguments = {
        "-B", "-E", "-I", "-O", "-OO", "-P", "-S", "-s", "-q", "-u"
    }
    if any(argument not in safe_arguments for argument in arguments):
        return None
    return (str(executable), *arguments)


def resolve_fusesoc_python(
    fusesoc: Path,
    explicit: Path | None,
    env: dict[str, str],
) -> tuple[str, ...]:
    """Find the interpreter that owns the FuseSoC Python packages.

    Virtual environments normally put ``python`` beside ``fusesoc``. User
    installs often do not, so an explicit interpreter or a conventional
    Python shebang is also accepted. The shebang is parsed as data; no shell
    fragment from the executable is evaluated.
    """
    if explicit is not None:
        command = _python_interpreter(explicit)
        if command is None:
            raise RuntimeError(
                "--fusesoc-python must name an executable Python interpreter: "
                f"{explicit.expanduser()}"
            )
        return command

    adjacent_names = ("python", "python3", "python.exe")
    for name in adjacent_names:
        command = _python_interpreter(fusesoc.with_name(name))
        if command is not None:
            return command

    try:
        with fusesoc.open("rb") as stream:
            raw_shebang = stream.readline(4097)
    except OSError as exc:
        raise RuntimeError(f"cannot inspect FuseSoC shebang: {exc}") from exc
    if len(raw_shebang) <= 4096 and raw_shebang.startswith(b"#!"):
        try:
            tokens = shlex.split(raw_shebang[2:].decode("utf-8").strip())
        except (UnicodeDecodeError, ValueError):
            tokens = []
        if tokens:
            interpreter = Path(tokens[0])
            arguments = tokens[1:]
            if interpreter.name == "env":
                if arguments[:1] == ["-S"]:
                    arguments = arguments[1:]
                if arguments[:1] == ["--"]:
                    arguments = arguments[1:]
                if arguments and "=" not in arguments[0]:
                    executable = shutil.which(
                        arguments[0], path=env.get("PATH", "")
                    )
                    if executable is not None:
                        command = _python_interpreter(
                            Path(executable), arguments[1:]
                        )
                        if command is not None:
                            return command
            elif interpreter.is_absolute():
                command = _python_interpreter(interpreter, arguments)
                if command is not None:
                    return command

    checked = ", ".join(str(fusesoc.with_name(name)) for name in adjacent_names)
    raise RuntimeError(
        "FuseSoC target discovery could not identify its Python environment. "
        f"Checked adjacent interpreters ({checked}) and the executable shebang. "
        "Provide --fusesoc-python with the Python that imports the same "
        "FuseSoC version and OpenTitan dependencies."
    )


def validate_fusesoc_python(
    command: Sequence[str],
    *,
    require_hjson: bool,
    cwd: Path,
    env: dict[str, str],
    timeout: int,
) -> dict[str, object]:
    """Validate and fingerprint the Python environment used by API probes."""
    marker = "FUSESOC_PYTHON_INFO_JSON="
    probe = r"""
import importlib.metadata
import json
import sys

import fusesoc

if sys.argv[1] == "1":
    import hjson

payload = {
    "executable": sys.executable,
    "python_version": sys.version.split()[0],
    "fusesoc_version": importlib.metadata.version("fusesoc"),
}
if sys.argv[1] == "1":
    payload["hjson_version"] = importlib.metadata.version("hjson")
print("FUSESOC_PYTHON_INFO_JSON=" + json.dumps(payload, sort_keys=True))
"""
    result = command_result(
        [*command, "-c", probe, "1" if require_hjson else "0"],
        cwd=cwd,
        env=env,
        timeout=timeout,
    )
    if result.returncode != 0:
        raise RuntimeError(
            "FuseSoC Python validation failed; use --fusesoc-python to select "
            "the OpenTitan tool environment:\n" + result.output.rstrip()
        )
    for line in reversed(result.output.splitlines()):
        if line.startswith(marker):
            payload = json.loads(line[len(marker) :])
            executable = Path(payload["executable"]).expanduser().absolute()
            payload.update(
                {
                    "command": short_command(command),
                    "executable": str(executable),
                    "real_executable": str(executable.resolve()),
                    "sha256": file_sha256(executable),
                }
            )
            return payload
    raise RuntimeError(
        "FuseSoC Python validation produced no machine-readable result:\n"
        + result.output.rstrip()
    )


def discover_cores(
    fusesoc: Path, opentitan_root: Path, env: dict[str, str], timeout: int
) -> list[Core]:
    result = command_result(
        [str(fusesoc), f"--cores-root={opentitan_root}", "core", "list"],
        cwd=opentitan_root,
        env=env,
        timeout=timeout,
    )
    if result.returncode != 0:
        raise RuntimeError(
            "FuseSoC core discovery failed:\n" + result.output.rstrip()
        )

    cores: list[Core] = []
    for line in result.output.splitlines():
        match = CORE_LINE_RE.match(line)
        if not match:
            continue
        fields = [field.strip() for field in line.split(" : ")]
        description = fields[-1] if len(fields) >= 4 else ""
        cores.append(Core(match.group("core"), description))
    if not cores:
        raise RuntimeError("FuseSoC returned no parseable OpenTitan cores")
    return cores


def discover_formal_targets(
    fusesoc_python: Sequence[str],
    opentitan_root: Path,
    env: dict[str, str],
    timeout: int,
) -> set[str]:
    """Ask the loaded FuseSoC core database which cores expose `formal`.

    Core-name suffixes are not authoritative: this OpenTitan revision has 19
    formal targets whose names do not end in `_fpv`/`_sva`, and one `_fpv`
    core whose usable target is `default`. Loading the database once is both
    exact and much faster than hundreds of `fusesoc core show` subprocesses.
    """
    marker = "FUSESOC_FORMAL_TARGETS_JSON="
    probe = r"""
import json
import sys
from fusesoc.config import Config
from fusesoc.coremanager import CoreManager
from fusesoc.librarymanager import Library

root = sys.argv[1]
manager = CoreManager(Config())
# Earlgrey-PROD-M6's pinned fusesoc fork (ot-0.5.dev0) predates the second
# add_library() argument later fusesoc versions added; try the modern
# 2-arg form first so this probe still works against a newer revision.
try:
    manager.add_library(Library("opentitan-matrix", root), [])
except TypeError:
    manager.add_library(Library("opentitan-matrix", root))
formal = []
for name, core in manager.get_cores().items():
    # Earlgrey-PROD-M6's fusesoc fork does not raise for a target name
    # that doesn't exist on this core -- get_flags("formal") silently
    # returns {} instead, so the target dict itself is the only reliable
    # signal here. (Guard both ways: a `formal` key is unambiguous, and
    # falling back to a non-empty get_flags() result preserves the
    # newer-fusesoc RuntimeError-based behavior this probe was
    # originally written against, in case a future revision restores it.)
    if "formal" in core.targets:
        formal.append(str(name))
        continue
    try:
        if core.get_flags("formal"):
            formal.append(str(name))
    except RuntimeError:
        continue
print("FUSESOC_FORMAL_TARGETS_JSON=" + json.dumps(sorted(formal)))
"""
    result = command_result(
        [*fusesoc_python, "-c", probe, str(opentitan_root)],
        cwd=opentitan_root,
        env=env,
        timeout=timeout,
    )
    if result.returncode != 0:
        raise RuntimeError(
            "FuseSoC formal-target discovery failed:\n" + result.output.rstrip()
        )
    for line in reversed(result.output.splitlines()):
        if line.startswith(marker):
            return set(json.loads(line[len(marker) :]))
    raise RuntimeError(
        "FuseSoC formal-target discovery produced no machine-readable result:\n"
        + result.output.rstrip()
    )


def discover_simulation_targets(
    fusesoc_python: Sequence[str],
    opentitan_root: Path,
    env: dict[str, str],
    timeout: int,
) -> dict[str, SimulationTarget]:
    """Inventory every literal FuseSoC `sim` target and its execution model.

    The public FuseSoC API resolves a named target into flags but does not expose
    the literal target table. The probe therefore reads FuseSoC's already parsed
    CAPI data, walks dependency closures, and classifies the actual source graph.
    It also reads local dvsim HJSON with the same Python environment OpenTitan
    uses, so a UVM runtime is never launched without a known test and sequence.
    """
    marker = "FUSESOC_SIM_TARGETS_JSON="
    probe = r"""
import json
from pathlib import Path
import re
import sys

import hjson
from fusesoc.config import Config
from fusesoc.coremanager import CoreManager
from fusesoc.librarymanager import Library

root = Path(sys.argv[1]).resolve()
manager = CoreManager(Config())
try:
    manager.add_library(Library("opentitan-matrix", str(root)), [])
except TypeError:
    manager.add_library(Library("opentitan-matrix", str(root)))
cores = {str(name): core for name, core in manager.get_cores().items()}
by_triple = {":".join(name.split(":")[:3]): name for name in cores}


def normalize_reference(value):
    value = str(value)
    if "?" in value:
        value = value.rsplit("?", 1)[1]
    return value.strip().strip("()").strip()


def resolve_dependency(value):
    value = normalize_reference(value)
    if value in cores:
        return value
    return by_triple.get(":".join(value.split(":")[:3]))


def relative(path):
    path = Path(path).resolve()
    try:
        return path.relative_to(root).as_posix()
    except ValueError:
        return str(path)


core_metadata = {}
for name, core in cores.items():
    fileset_metadata = {}
    # Earlgrey-PROD-M6's fusesoc fork exposes each fileset/file as a typed
    # Fileset/File object (attribute access) rather than the raw parsed-YAML
    # dict a newer fusesoc's `_capi_data` holds -- read straight from the
    # attributes instead of dict .get() calls.
    for fileset_name, fileset in core.filesets.items():
        dependencies = set()
        hdl_text = []
        has_native = False
        has_dpi = False
        for dependency in fileset.depend or []:
            resolved = resolve_dependency(dependency)
            if resolved:
                dependencies.add(resolved)
        default_type = str(fileset.file_type or "")
        native_sources = []
        include_dirs = set()
        for entry in fileset.files or []:
            source_name = normalize_reference(entry.name)
            source = Path(core.core_root) / source_name
            if not source.is_file():
                continue
            file_type = str(entry.file_type or default_type).casefold()
            suffix = source.suffix.casefold()
            native = (
                "csource" in file_type
                or "cppsource" in file_type
                or suffix in {".c", ".cc", ".cpp", ".cxx"}
            )
            has_native = has_native or native
            if native and suffix in {".c", ".cc", ".cpp", ".cxx"}:
                native_sources.append(str(source))
            if suffix in {".h", ".hh", ".hpp", ".hxx", ".inc"} or native:
                include_dirs.add(str(source.parent))
            if suffix in {".v", ".vh", ".sv", ".svh"}:
                text = source.read_text(errors="replace")
                hdl_text.append(text)
                has_dpi = has_dpi or "DPI-C" in text
        fileset_metadata[fileset_name] = {
            "dependencies": sorted(dependencies),
            "text": "\n".join(hdl_text),
            "native": has_native,
            "dpi": has_dpi,
            "native_sources": native_sources,
            "include_dirs": sorted(include_dirs),
        }
    core_metadata[name] = {"filesets": fileset_metadata}


def selected_filesets(name, target_name):
    core = cores[name]
    targets = core.targets
    target = targets.get(target_name)
    if target is None:
        target = targets.get("default")
    available = core_metadata[name]["filesets"]
    if target is None:
        return list(available)
    selected = [
        normalize_reference(fileset)
        for fileset in target.filesets or []
    ]
    selected = [fileset for fileset in selected if fileset in available]
    return selected or list(available)


def source_closure(root_name):
    seen_nodes = set()
    seen_cores = set()
    pending = [(root_name, "sim")]
    hdl_text = []
    native_cores = set()
    dpi_cores = set()
    native_sources = []
    include_dirs = set()
    while pending:
        name, target_name = pending.pop()
        node = (name, target_name)
        if node in seen_nodes:
            continue
        seen_nodes.add(node)
        seen_cores.add(name)
        for fileset_name in selected_filesets(name, target_name):
            metadata = core_metadata[name]["filesets"][fileset_name]
            hdl_text.append(metadata["text"])
            if metadata["native"]:
                native_cores.add(name)
            native_sources.extend(metadata["native_sources"])
            include_dirs.update(metadata["include_dirs"])
            if metadata["dpi"]:
                dpi_cores.add(name)
            pending.extend(
                (dependency, "default")
                for dependency in metadata["dependencies"]
            )
    return (seen_cores, "\n".join(hdl_text), native_cores, dpi_cores,
            list(dict.fromkeys(native_sources)), sorted(include_dirs))


def substitute(value, context):
    value = str(value)
    for _ in range(8):
        replaced = re.sub(
            r"\{([A-Za-z_][A-Za-z0-9_]*)\}",
            lambda match: str(context.get(match.group(1), match.group(0))),
            value,
        )
        if replaced == value:
            break
        value = replaced
    return value


def merge_configs(base, addition):
    merged = dict(base)
    for key, value in addition.items():
        if key == "import_cfgs":
            continue
        if isinstance(value, list) and isinstance(merged.get(key), list):
            merged[key] = [*merged[key], *value]
        elif isinstance(value, dict) and isinstance(merged.get(key), dict):
            merged[key] = {**merged[key], **value}
        else:
            merged[key] = value
    return merged


# Every cfg some other cfg imports: a base (kmac_base_sim_cfg) that dvsim
# never runs by itself, only through the variants that import it.
imported_configs = set()


def load_config(config_path, inherited=None, stack=()):
    config_path = Path(config_path).resolve()
    if config_path in stack or not config_path.is_file():
        return {}
    try:
        local = hjson.loads(config_path.read_text())
    except Exception:
        return {}
    inherited = dict(inherited or {})
    local_context = {
        **inherited,
        **{
            key: value
            for key, value in local.items()
            if isinstance(value, (str, int, float, bool))
        },
        "proj_root": str(root),
        "self_dir": str(config_path.parent),
    }
    merged = {}
    for imported in local.get("import_cfgs", []) or []:
        # Simulator backends describe VCS/Xcelium command syntax, not portable
        # test metadata. The matrix consumes the common and test configs only.
        if "{tool}" in str(imported):
            continue
        imported_path = substitute(imported, local_context)
        if "{" in imported_path or "}" in imported_path:
            continue
        imported_path = Path(imported_path)
        if not imported_path.is_absolute():
            imported_path = config_path.parent / imported_path
        # Ibex vendors lowrisc_ip as `<ibex>/vendor/lowrisc_ip`, a link that
        # does not exist inside OpenTitan; the same files live at hw/ there.
        if not imported_path.is_file() and "/vendor/lowrisc_ip/" in str(imported_path):
            relocated = root / "hw" / str(imported_path).split("/vendor/lowrisc_ip/", 1)[1]
            if relocated.is_file():
                imported_path = relocated
        imported_configs.add(imported_path.resolve())
        merged = merge_configs(
            merged,
            load_config(
                imported_path,
                local_context,
                (*stack, config_path),
            ),
        )
    return merge_configs(merged, local)


def unique(values):
    return list(dict.fromkeys(values))


configs = {}
loaded_configs = [
    (config_path, load_config(config_path))
    for config_path in sorted(root.rglob("*sim_cfg.hjson"))
]
for config_path, config in loaded_configs:
    context = {
        **{
            key: value
            for key, value in config.items()
            if isinstance(value, (str, int, float, bool))
        },
        "proj_root": str(root),
        "self_dir": str(config_path.parent),
    }
    # dvsim applies `overrides` over the merged configuration. lc_ctrl and
    # rv_dm override tl_dw/tl_dbw to 64/8, which common_sim_cfg turns into
    # the UVM_REG_DATA_WIDTH/UVM_REG_BYTENABLE_WIDTH defines.
    override_core = None
    for override in config.get("overrides", []) or []:
        if not isinstance(override, dict):
            continue
        if override.get("name") == "fusesoc_core":
            override_core = override.get("value")
        elif isinstance(override.get("name"), str) and isinstance(
            override.get("value"), (str, int, float, bool)
        ):
            context[override["name"]] = override["value"]
    core_value = override_core or config.get("fi_core") or config.get("fusesoc_core")
    if not isinstance(core_value, str):
        continue
    core_name = substitute(core_value, context)
    if "{" in core_name or core_name not in cores:
        continue
    tests = [test for test in config.get("tests", []) or [] if isinstance(test, dict)]
    smoke_regressions = [
        regression
        for regression in config.get("regressions", []) or []
        if isinstance(regression, dict) and regression.get("name") == "smoke"
    ]
    tests_by_name = {
        substitute(test["name"], context): test
        for test in tests
        if isinstance(test.get("name"), str)
        and (
            test.get("uvm_test_seq")
            or any(
                re.fullmatch(r"\+TESTNAME=[^{}%\s]+", str(option))
                for option in test.get("run_opts", []) or []
            )
        )
    }
    regression_smoke = next(
        (
            tests_by_name[substitute(name, context)]
            for regression in reversed(smoke_regressions)
            for name in regression.get("tests", []) or []
            if isinstance(name, str)
            and substitute(name, context) in tests_by_name
        ),
        None,
    )
    smoke_tests = [
        test for test in tests if "smoke" in str(test.get("name", "")).casefold()
    ]
    expected_smoke = str(config.get("name", "")) + "_smoke"
    selected = regression_smoke or next(
        (test for test in smoke_tests if test.get("name") == expected_smoke),
        smoke_tests[0] if smoke_tests else (tests[0] if len(tests) == 1 else {}),
    )
    uvm_test = substitute(
        selected.get("uvm_test", config.get("uvm_test", "")), context
    ) or None
    uvm_test_seq = substitute(
        selected.get("uvm_test_seq", config.get("uvm_test_seq", "")), context
    ) or None
    run_options = [
        *(config.get("run_opts", []) or []),
        *(selected.get("run_opts", []) or []),
        *(
            option
            for regression in smoke_regressions
            for option in regression.get("run_opts", []) or []
        ),
    ]
    runtime_options = []
    unresolved_runtime_options = []
    for option in run_options:
        option = substitute(option, context)
        if "{" in option or "}" in option or not option.startswith("+"):
            unresolved_runtime_options.append(option)
        else:
            runtime_options.append(option)

    build_mode = selected.get("build_mode", config.get("primary_build_mode"))
    build_options = [
        substitute(option, context) for option in config.get("build_opts", []) or []
    ]
    # dvsim applies the test's build mode plus every mode named in
    # en_build_modes (of the cfg, the test, or an applied mode). kmac's
    # masked cfg only gets EN_MASKING=1 this way. `{tool}_...` modes hold
    # VCS/Xcelium flags and stay unresolved.
    modes = {
        mode.get("name"): mode
        for mode in config.get("build_modes", []) or []
        if isinstance(mode, dict)
    }
    pending = [build_mode] if build_mode else []
    for source in (config, selected):
        pending.extend(source.get("en_build_modes", []) or [])
    applied_modes = []
    unresolved_build_modes = []
    while pending:
        mode_name = substitute(pending.pop(0), context)
        if mode_name in applied_modes or mode_name in unresolved_build_modes:
            continue
        mode = modes.get(mode_name)
        if mode is None:
            unresolved_build_modes.append(mode_name)
            continue
        applied_modes.append(mode_name)
        build_options.extend(
            substitute(option, context)
            for option in mode.get("build_opts", []) or []
        )
        runtime_options.extend(
            substitute(option, context)
            for option in mode.get("run_opts", []) or []
            if str(option).startswith("+") and "{" not in str(option)
        )
        pending.extend(mode.get("en_build_modes", []) or [])
    build_options.extend(
        substitute(option, context) for option in selected.get("build_opts", []) or []
    )

    # dvsim also applies every run mode named in en_run_modes (of the cfg or
    # the test, transitively) and passes its run_opts to the simulation. The
    # chip xbar smoke test only works with xbar_run_mode's +xbar_mode=1.
    # Options holding a {placeholder} or a tool flag stay unresolved, and a
    # mode's own pre/post commands remain orchestration requirements below.
    run_modes = {
        mode.get("name"): mode
        for mode in config.get("run_modes", []) or []
        if isinstance(mode, dict)
    }
    pending_run_modes = []
    for source in (config, selected):
        pending_run_modes.extend(source.get("en_run_modes", []) or [])
    applied_run_modes = []
    while pending_run_modes:
        mode_name = substitute(pending_run_modes.pop(0), context)
        mode = run_modes.get(mode_name)
        if mode is None or mode_name in applied_run_modes:
            continue
        applied_run_modes.append(mode_name)
        runtime_options.extend(
            substitute(option, context)
            for option in mode.get("run_opts", []) or []
            if str(option).startswith("+") and "{" not in str(option)
        )
        pending_run_modes.extend(mode.get("en_run_modes", []) or [])

    orchestration_requirements = []
    for key in (
        "pre_build_cmds",
        "post_build_cmds",
        "pre_run_cmds",
        "post_run_cmds",
        "sw_images",
        "en_run_modes",
    ):
        if (
            config.get(key)
            or selected.get(key)
            or any(regression.get(key) for regression in smoke_regressions)
        ):
            orchestration_requirements.append(key)
    if unresolved_build_modes:
        orchestration_requirements.append("en_build_modes")
    candidate = {
        "dvsim_config": relative(config_path),
        "dvsim_test": selected.get("name"),
        "uvm_test": uvm_test,
        "uvm_test_seq": uvm_test_seq,
        "dvsim_regression": "smoke" if smoke_regressions else None,
        "runtime_options": unique(runtime_options),
        "unresolved_runtime_options": unique(unresolved_runtime_options),
        "build_mode": build_mode,
        "build_options": unique(build_options),
        "timescale": substitute(config.get("timescale", ""), context) or None,
        "orchestration_requirements": orchestration_requirements,
    }
    previous = configs.get(core_name)
    candidate["runnable_config"] = config_path.resolve() not in imported_configs
    candidate_score = (
        bool(uvm_test and uvm_test_seq),
        bool(selected),
        -len(candidate["unresolved_runtime_options"]),
        candidate["runnable_config"],
    )
    previous_score = (
        bool(previous and previous.get("uvm_test") and previous.get("uvm_test_seq")),
        bool(previous and previous.get("dvsim_test")),
        -len(previous.get("unresolved_runtime_options", [])) if previous else 0,
        bool(previous and previous.get("runnable_config")),
    )
    if previous is None or candidate_score > previous_score:
        configs[core_name] = candidate


simulation_targets = []
for name, core in cores.items():
    target = core.targets.get("sim")
    if target is None:
        continue
    (closure, closure_text, native_cores, dpi_cores, native_sources,
     native_include_dirs) = source_closure(name)
    requires_uvm_library = bool(
        re.search(r"\bimport\s+uvm_pkg\s*::", closure_text)
        or re.search(r"[`\"]uvm_macros\.svh", closure_text)
    )
    default_tool = str(target.default_tool or "")
    if default_tool == "verilator":
        category = "verilator"
    elif re.search(r"\brun_test\s*\(", closure_text):
        category = "uvm"
    elif "$finish" in closure_text:
        category = "directed"
    else:
        category = "elaboration"

    toplevels = target.toplevel or []
    if isinstance(toplevels, str):
        toplevels = [toplevels]
    config = configs.get(name, {})
    synthesized_uvm_keys = {
        "+UVM_NO_RELNOTES",
        "+UVM_VERBOSITY",
        "+UVM_TESTNAME",
        "+UVM_TEST_SEQ",
    }
    runtime_args = [
        option
        for option in config.get("runtime_options", [])
        if option.split("=", 1)[0] not in synthesized_uvm_keys
    ]
    if category == "uvm":
        runtime_args[:0] = ["+UVM_NO_RELNOTES", "+UVM_VERBOSITY=UVM_LOW"]
        if config.get("uvm_test"):
            runtime_args.append("+UVM_TESTNAME=" + str(config["uvm_test"]))
        if config.get("uvm_test_seq"):
            runtime_args.append("+UVM_TEST_SEQ=" + str(config["uvm_test_seq"]))

    metadata_warnings = []
    if category != "uvm" and (config.get("uvm_test") or config.get("uvm_test_seq")):
        metadata_warnings.append(
            "dvsim declares UVM test metadata but the FuseSoC source closure "
            "contains no run_test()"
        )
    if category == "uvm" and not (
        config.get("uvm_test") and config.get("uvm_test_seq")
    ):
        metadata_warnings.append(
            "UVM source closure has no authoritative dvsim test/sequence pair"
        )
    native_dependencies = sorted(native_cores)

    simulation_targets.append({
        "vlnv": name,
        "category": category,
        "default_tool": default_tool,
        "toplevels": list(toplevels or []),
        "core_file": relative(core.core_file),
        "runtime_args": runtime_args,
        "dvsim_config": config.get("dvsim_config"),
        "dvsim_test": config.get("dvsim_test"),
        "uvm_test": config.get("uvm_test"),
        "uvm_test_seq": config.get("uvm_test_seq"),
        "dvsim_regression": config.get("dvsim_regression"),
        "build_mode": config.get("build_mode"),
        "build_options": config.get("build_options", []),
        "timescale": config.get("timescale"),
        "native_dependencies": native_dependencies,
        "dpi_dependencies": sorted(
            native_cores | dpi_cores
        ),
        "orchestration_requirements": config.get("orchestration_requirements", []),
        "unresolved_runtime_options": config.get("unresolved_runtime_options", []),
        "metadata_warnings": metadata_warnings,
        "requires_uvm_library": requires_uvm_library,
        "native_sources": native_sources,
        "native_include_dirs": native_include_dirs,
    })

print("FUSESOC_SIM_TARGETS_JSON=" + json.dumps(sorted(
    simulation_targets, key=lambda item: item["vlnv"]
)))
"""
    result = command_result(
        [*fusesoc_python, "-c", probe, str(opentitan_root)],
        cwd=opentitan_root,
        env=env,
        timeout=timeout,
    )
    if result.returncode != 0:
        raise RuntimeError(
            "FuseSoC simulation-target discovery failed:\n" + result.output.rstrip()
        )
    payload: list[dict[str, object]] | None = None
    for line in reversed(result.output.splitlines()):
        if line.startswith(marker):
            payload = json.loads(line[len(marker) :])
            break
    if payload is None:
        raise RuntimeError(
            "FuseSoC simulation-target discovery produced no machine-readable "
            "result:\n" + result.output.rstrip()
        )

    targets: dict[str, SimulationTarget] = {}
    tuple_fields = {
        "toplevels",
        "runtime_args",
        "build_options",
        "native_dependencies",
        "dpi_dependencies",
        "orchestration_requirements",
        "unresolved_runtime_options",
        "metadata_warnings",
        "native_sources",
        "native_include_dirs",
    }
    for item in payload:
        normalized = dict(item)
        for field in tuple_fields:
            normalized[field] = tuple(normalized.get(field, []))
        target = SimulationTarget(**normalized)
        if target.category not in SIMULATION_CATEGORIES:
            raise RuntimeError(
                f"unknown simulation category {target.category!r} for {target.vlnv}"
            )
        if target.vlnv in targets:
            raise RuntimeError(f"duplicate FuseSoC sim target: {target.vlnv}")
        targets[target.vlnv] = target
    if not targets:
        raise RuntimeError("FuseSoC returned no literal simulation targets")
    return targets


def core_supports_lane(
    core: Core,
    lane: str,
    formal_targets: set[str] | None = None,
    simulation_targets: dict[str, SimulationTarget] | None = None,
) -> bool:
    dv_library = core.library == "dv" or core.library.endswith("_dv")
    fpv_core = core.name.endswith("_fpv")
    simulation_core = core.name.endswith("_sim") or core.name.endswith("_tracing")
    if simulation_targets is not None and lane in ("uvm", "runtime"):
        simulation = simulation_targets.get(core.vlnv)
        if simulation is None:
            return False
        if lane == "uvm":
            return simulation.category == "uvm"
        return simulation.category in {"uvm", "directed"}
    if lane in ("uvm", "runtime"):
        return dv_library and core.name.endswith("_sim")
    if lane == "sva":
        if formal_targets is not None:
            return core.vlnv in formal_targets or core.vlnv in SVA_DEFAULT_TARGETS
        return (dv_library and core.name.endswith("_sva")) or fpv_core
    if lane == "rtl":
        return (
            not fpv_core
            and not simulation_core
            and (
                core.library in {"ip", "prim", "tlul", "ibex", "systems"}
                or core.library.endswith("_ip")
            )
        )
    raise ValueError(f"unknown lane: {lane}")


def requested_lanes(values: Sequence[str]) -> list[str]:
    if not values or "all" in values:
        return list(LANES)
    return [lane for lane in LANES if lane in values]


def select_jobs(
    cores: Iterable[Core],
    args: argparse.Namespace,
    formal_targets: set[str] | None = None,
    simulation_targets: dict[str, SimulationTarget] | None = None,
) -> list[Job]:
    lanes = requested_lanes(args.lane)
    exact_cores = set(args.core)
    filters = [value.casefold() for value in args.ip]
    jobs: list[Job] = []
    for lane in lanes:
        for core in cores:
            if exact_cores and core.vlnv not in exact_cores:
                continue
            haystack = f"{core.vlnv} {core.description}".casefold()
            if filters and not any(value in haystack for value in filters):
                continue
            if core_supports_lane(core, lane, formal_targets, simulation_targets):
                jobs.append(
                    Job(
                        lane,
                        core,
                        simulation_targets.get(core.vlnv)
                        if simulation_targets is not None
                        else None,
                    )
                )
    jobs.sort(key=lambda job: (LANES.index(job.lane), job.core.vlnv))
    if args.max_cores:
        jobs = jobs[: args.max_cores]
    return jobs


def safe_name(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", value).strip("_")


def top_for_job(job: Job, requested: str) -> str:
    if requested != "auto":
        return requested
    for top in ("darjeeling", "englishbreakfast", "earlgrey"):
        if top in job.core.vlnv:
            return top
    return "earlgrey"


def provider_mappings(job: Job, requested_top: str) -> list[str]:
    top = top_for_job(job, requested_top)
    if top == "englishbreakfast":
        return [PRIM_MAPPING, ENGLISHBREAKFAST_MAPPING]
    return [PRIM_MAPPING, DEFAULT_TOPS[top]]


def spi_host_sva_core_source_text(text: str) -> str:
    before = "    filesets:\n      - files_formal\n      - files_dv\n    toplevel: spi_host"
    after = "    filesets:\n      - files_dv\n    toplevel: spi_host"
    if text.count(before) != 1:
        raise ValueError("SPI host formal fileset reference is not unique")
    return text.replace(before, after)


def stage_spi_host_sva_core_override(
    opentitan_root: Path, source_override_root: Path
) -> None:
    source_core = opentitan_root / SPI_HOST_SVA_CORE
    overlay_core = source_override_root / SPI_HOST_SVA_CORE
    if not source_core.is_file():
        overlay_core.unlink(missing_ok=True)
        return
    if file_sha256(source_core) != SPI_HOST_SVA_CORE_SOURCE_SHA256:
        overlay_core.unlink(missing_ok=True)
        return

    overlay_text = spi_host_sva_core_source_text(source_core.read_text())
    overlay_hash = hashlib.sha256(overlay_text.encode()).hexdigest()
    if overlay_hash != SPI_HOST_SVA_CORE_OVERLAY_SHA256:
        raise RuntimeError(f"SPI host SVA core overlay hash mismatch: {overlay_hash}")
    if overlay_core.is_symlink():
        raise RuntimeError("SPI host SVA core overlay is a symlink")
    overlay_core.parent.mkdir(parents=True, exist_ok=True)
    if not overlay_core.is_file() or overlay_core.read_text() != overlay_text:
        overlay_core.write_text(overlay_text)

    source_dir = source_core.parent
    overlay_dir = overlay_core.parent
    for name in ("spi_host_data_stable_sva.sv", "spi_host_bind.sv"):
        link = overlay_dir / name
        target = source_dir / name
        if link.is_symlink():
            if link.resolve() == target.resolve():
                continue
            link.unlink()
        elif link.exists():
            raise RuntimeError(f"SPI host SVA overlay path already exists: {link}")
        link.symlink_to(target)

    data_link = overlay_dir.parent.parent / "data"
    data_target = source_dir.parent.parent / "data"
    if data_link.is_symlink():
        if data_link.resolve() != data_target.resolve():
            data_link.unlink()
    elif data_link.exists():
        raise RuntimeError(f"SPI host SVA overlay data path already exists: {data_link}")
    if not data_link.exists():
        data_link.symlink_to(data_target, target_is_directory=True)


def prepare_matrix_core_root(build_root: Path, opentitan_root: Path) -> Path:
    """Prepare FuseSoC mappings and pinned-source core metadata overlays."""
    core_root = build_root / "matrix-provider-cores"
    core_root.mkdir(parents=True, exist_ok=True)
    mapping_core = core_root / "top_englishbreakfast_mapping.core"
    if (
        not mapping_core.is_file()
        or mapping_core.read_text() != ENGLISHBREAKFAST_MAPPING_CORE
    ):
        mapping_core.write_text(ENGLISHBREAKFAST_MAPPING_CORE)
    prim_mapping_core = core_root / "prim_generic_all_mapping.core"
    if (
        not prim_mapping_core.is_file()
        or prim_mapping_core.read_text() != PRIM_MAPPING_CORE
    ):
        prim_mapping_core.write_text(PRIM_MAPPING_CORE)

    # Some pinned OpenTitan core files omit direct dependencies for modules
    # that their RTL instantiates. Keep these corrections in a build-local
    # overlay so FuseSoC sees the complete dependency closure without editing
    # the input source checkout.
    source_override_root = core_root / "source-overrides"
    for relative_core, anchor_dependency, added_dependencies in (
        MATRIX_SOURCE_CORE_DEPENDENCIES
    ):
        source_core = opentitan_root / relative_core
        overlay_core = source_override_root / relative_core
        if not source_core.is_file():
            if overlay_core.is_file():
                overlay_core.unlink()
            continue

        source_text = source_core.read_text()
        source_lines = source_text.splitlines(keepends=True)
        present_dependencies = {
            line.strip()[2:].strip()
            for line in source_lines
            if line.strip().startswith("- ")
        }
        missing_dependencies = [
            dependency
            for dependency in added_dependencies
            if dependency not in present_dependencies
        ]
        if not missing_dependencies:
            if overlay_core.is_file():
                overlay_core.unlink()
            continue

        anchors = [
            index
            for index, line in enumerate(source_lines)
            if line.strip() == f"- {anchor_dependency}"
        ]
        if len(anchors) != 1:
            raise RuntimeError(
                f"cannot prepare FuseSoC overlay for {relative_core}: expected "
                f"one {anchor_dependency} dependency, found {len(anchors)}"
            )

        anchor_index = anchors[0]
        anchor_line = source_lines[anchor_index]
        indent = anchor_line[: len(anchor_line) - len(anchor_line.lstrip())]
        newline = "\r\n" if anchor_line.endswith("\r\n") else "\n"
        inserted_lines = [
            f"{indent}- {dependency}{newline}"
            for dependency in missing_dependencies
        ]
        overlay_text = "".join(
            source_lines[: anchor_index + 1]
            + inserted_lines
            + source_lines[anchor_index + 1 :]
        )
        overlay_core_dir = overlay_core.parent
        overlay_core_dir.mkdir(parents=True, exist_ok=True)
        if not overlay_core.is_file() or overlay_core.read_text() != overlay_text:
            overlay_core.write_text(overlay_text)
        for dirname in ("rtl", "lint"):
            source_dir = source_core.parent / dirname
            if not source_dir.is_dir():
                continue
            overlay_dir = overlay_core_dir / dirname
            if overlay_dir.is_symlink():
                if overlay_dir.resolve() != source_dir.resolve():
                    overlay_dir.unlink()
                    overlay_dir.symlink_to(source_dir, target_is_directory=True)
            elif not overlay_dir.exists():
                overlay_dir.symlink_to(source_dir, target_is_directory=True)
    stage_spi_host_sva_core_override(opentitan_root, source_override_root)
    return core_root


def actionable_setup_lines(output: str) -> list[str]:
    findings: list[str] = []
    for line in output.splitlines():
        if not line.lstrip().casefold().startswith("warning:"):
            continue
        if any(pattern.search(line) for pattern in SETUP_ALLOWLIST):
            continue
        findings.append(line.strip())
    return findings


def classify_compile_setup_warnings(
    lane: str, findings: Sequence[str], source_list: Path
) -> tuple[list[str], list[str]]:
    """Classify non-HDL setup warnings only when Icarus omits those files."""
    if lane not in {"rtl", "sva", "uvm"}:
        return list(findings), []
    compiler_sources: set[Path] = set()
    pending = [source_list]
    seen: set[Path] = set()
    try:
        while pending:
            current = pending.pop().resolve()
            if current in seen:
                continue
            seen.add(current)
            for line in current.read_text(errors="replace").splitlines():
                tokens = shlex.split(line, comments=True)
                for index, token in enumerate(tokens):
                    if token in ("-c", "-f") and index + 1 < len(tokens):
                        nested = Path(tokens[index + 1])
                        pending.append(
                            nested if nested.is_absolute() else current.parent / nested
                        )
                    elif len(tokens) == 1 and not token.startswith(("-", "+", "@")):
                        source = Path(token)
                        if source.suffix.casefold() in {
                            ".c", ".cc", ".cpp", ".cxx", ".py"
                        }:
                            compiler_sources.add(
                                source.resolve() if source.is_absolute()
                                else (current.parent / source).resolve()
                            )
    except (OSError, ValueError):
        return list(findings), []

    actionable: list[str] = []
    benign: list[str] = []
    for line in findings:
        match = (
            NATIVE_SOURCE_SETUP_WARNING_RE.fullmatch(line)
            or PYTHON_SOURCE_SETUP_WARNING_RE.fullmatch(line)
        )
        if match:
            path = Path(match.group("path"))
            staged = (
                path.resolve()
                if path.is_absolute()
                else (source_list.parent / path).resolve()
            )
            if staged.is_file() and staged not in compiler_sources:
                benign.append(line)
                continue
        actionable.append(line)
    return actionable, benign


def verified_native_setup_warnings(
    findings: Sequence[str],
    source_list: Path,
    native_sources: Sequence[str],
    skipped_sources: Sequence[str],
    native_library: Path | None,
    loaded_libraries: Sequence[Path],
    *,
    runtime_passed: bool,
) -> tuple[list[str], list[str]]:
    """Classify FuseSoC native-source notices after independent DPI proof."""
    if (
        not runtime_passed or not native_sources or skipped_sources
        or native_library is None or not native_library.is_file()
        or native_library not in loaded_libraries
    ):
        return list(findings), []
    try:
        native_hashes = {file_sha256(Path(path)) for path in native_sources}
    except OSError:
        return list(findings), []
    actionable = []
    benign = []
    for line in findings:
        match = NATIVE_SOURCE_SETUP_WARNING_RE.fullmatch(line)
        if match:
            staged = source_list.parent / match.group("path")
            try:
                if staged.is_file() and file_sha256(staged) in native_hashes:
                    benign.append(line)
                    continue
            except OSError:
                pass
        actionable.append(line)
    return actionable, benign


def matching_lines(
    output: str,
    patterns: Sequence[re.Pattern[str]],
    allowlist: Sequence[re.Pattern[str]] = (),
) -> list[str]:
    findings: list[str] = []
    seen: set[str] = set()
    for line in output.splitlines():
        if any(pattern.search(line) for pattern in patterns):
            normalized = line.strip()
            if any(pattern.search(normalized) for pattern in allowlist):
                continue
            if normalized and normalized not in seen:
                findings.append(normalized)
                seen.add(normalized)
    return findings


def merge_runtime_arguments(
    configured: Sequence[str], requested: Sequence[str]
) -> list[str]:
    """Let explicit CLI plusargs replace dvsim defaults without duplicates."""

    def key(argument: str) -> str:
        return argument.split("=", 1)[0] if argument.startswith("+") else argument

    requested_keys = {key(argument) for argument in requested}
    return [
        *requested,
        *(argument for argument in configured if key(argument) not in requested_keys),
    ]


def parse_makefile(work_root: Path) -> tuple[Path, list[str]]:
    makefiles = sorted(work_root.rglob("Makefile"), key=lambda path: len(path.parts))
    for makefile in makefiles:
        assignments: dict[str, str] = {}
        for line in makefile.read_text(errors="replace").splitlines():
            match = MAKE_ASSIGN_RE.match(line)
            if match:
                assignments[match.group("name")] = match.group("value").strip()
        target = assignments.get("TARGET")
        if not target:
            continue
        source_list = makefile.parent / f"{target}.scr"
        if source_list.is_file():
            # Pinned OpenTitan edalize (v0.4.0) writes `TOPLEVEL := tb' and
            # adds `-s' in its recipe; newer releases put `-stb' in TOPLEVEL.
            tops = shlex.split(assignments.get("TOPLEVEL", ""))
            return source_list, [top if top.startswith("-") else "-s" + top
                                 for top in tops]
    raise FileNotFoundError(f"no generated Icarus Makefile/source list below {work_root}")


def declared_modules(source_list: Path) -> dict[str, str]:
    """Map module names declared by a generated source list to their entry."""
    modules: dict[str, str] = {}
    base = source_list.parent
    for raw in source_list.read_text(errors="replace").splitlines():
        entry = raw.strip()
        if not entry or entry.startswith("+") or entry.startswith("-"):
            continue
        try:
            text = (base / entry).read_text(errors="replace")
        except OSError:
            continue
        for name in MODULE_DECL_RE.findall(text):
            modules.setdefault(name, entry)
    return modules


def validated_top_options(
    job: Job,
    source_list: Path,
    top_options: Sequence[str],
    work_root: Path,
) -> tuple[list[str], list[str], Path | None]:
    """Drop ``-s`` roots that name modules absent from the source list.

    Several upstream cores declare a stale ``toplevel`` (for example
    lc_ctrl_pkg.core names ``lc_ctrl``, which is not in its fileset).
    Substitute the core's own module when one matches, otherwise let the
    compiler select the roots. A package-only list gets a synthetic empty
    root module so its packages are still compiled and checked.

    Returns (top options, notes, replacement source list or None).
    """
    missing = [
        option[2:]
        for option in top_options
        if option.startswith("-s") and option[2:]
    ]
    if not missing:
        return list(top_options), [], None
    modules = declared_modules(source_list)
    kept: list[str] = []
    notes: list[str] = []
    for option in top_options:
        if not option.startswith("-s") or option[2:] in modules:
            kept.append(option)
            continue
        fallback = job.core.name
        own_prefix = f"src/{job.core.vlnv.replace(':', '_')}/"
        own_modules = sorted(
            name for name, entry in modules.items()
            if entry.startswith(own_prefix)
        )
        if fallback in modules:
            kept.append(f"-s{fallback}")
            notes.append(
                f"declared toplevel {option[2:]!r} is not in the source "
                f"list; substituted the core's own module {fallback!r}"
            )
        elif own_modules:
            kept.extend(f"-s{name}" for name in own_modules)
            notes.append(
                f"declared toplevel {option[2:]!r} is not in the source "
                f"list; rooting the core's own modules {own_modules!r}"
            )
        elif "tb" in modules:
            # OpenTitan DV cores universally name their testbench module `tb`,
            # and dvsim roots it explicitly. Several sim cores contribute only
            # INCLUDE files of their own (so own_modules is empty) while
            # declaring a toplevel that no longer exists -- xbar_dbg_sim
            # declares `xbar_tb_top', whose module is nowhere in the fileset.
            # Falling through to "let the compiler choose" makes EVERY
            # uninstantiated module a root, including prim_clock_gating_sync,
            # which lowrisc:prim:all ships without depending on
            # lowrisc:prim:clock_gating. That reports a missing module the
            # design never instantiates. Root `tb' the way the real flow does.
            kept.append("-stb")
            notes.append(
                f"declared toplevel {option[2:]!r} is not in the source "
                "list; rooted the conventional OpenTitan DV testbench "
                "module 'tb'"
            )
        else:
            notes.append(
                f"declared toplevel {option[2:]!r} is not in the source "
                "list; letting the compiler select the root modules"
            )
    # A module that exists only to carry `bind' directives -- OpenTitan's
    # <ip>_bind convention -- is never instantiated by anything. An explicit
    # root therefore excludes it, its bind directives never elaborate, and
    # tb.sv cannot resolve the interface they were supposed to insert:
    #
    #     module rstmgr_bind;
    #       bind rstmgr rstmgr_cascading_sva_if rstmgr_cascading_sva_if (...);
    #     endmodule
    #     ...
    #     uvm_config_db#(virtual ...)::set(..., dut.rstmgr_cascading_sva_if);
    #     -> error: Unable to bind variable `dut.rstmgr_cascading_sva_if'
    #
    # This is root selection, not a compiler defect: slang reports the same
    # unresolved hierarchical name under an explicit --top, and both tools
    # accept the design once the bind module is also a top. IEEE 1800-2023
    # 23.11 inserts an instance-list-free bind "designwide", but the directive
    # must still be elaborated. A simulator handed the whole filelist roots
    # every top-level module, so root these the same way.
    # NOT in the sva lane. sva_testbench_wrapper() below wraps the declared
    # top in a generated tb/dut pair, and it bails out when `len(tops) != 1'.
    # Adding a second root here therefore SILENTLY disables that wrapping, and
    # the SVA collateral's `tb.dut...' hierarchical references stop resolving
    # (i2c_sva went PASS -> FAIL that way, plus five more rows). The sva lane
    # builds its own topology; leave it alone.
    if kept and job.lane != "sva":
        bind_modules = sorted(
            name
            for name in modules
            if name.endswith("_bind") and f"-s{name}" not in kept
        )
        if bind_modules:
            kept.extend(f"-s{name}" for name in bind_modules)
            notes.append(
                f"also rooted bind-carrying module(s) {bind_modules!r}: "
                "nothing instantiates them, so an explicit root would drop "
                "their bind directives"
            )

    wrapper: Path | None = None
    if not kept and not modules:
        stub = work_root / "matrix-package-root.sv"
        stub.write_text("module matrix_package_root;\nendmodule\n")
        wrapper = work_root / "matrix-package.scr"
        wrapper.write_text(f"-c {source_list}\n{stub}\n")
        kept = ["-smatrix_package_root"]
        notes.append(
            "source list declares no modules; added a synthetic empty "
            "root so the packages are still compiled"
        )
    return kept, notes, wrapper


def sva_testbench_wrapper(
    job: Job,
    source_list: Path,
    top_options: Sequence[str],
    work_root: Path,
    compiler_source_list: Path,
) -> tuple[list[str], list[str], Path | None]:
    """Reproduce the dvsim testbench topology for standalone SVA jobs.

    OpenTitan SVA collateral is written for the DV simulation topology
    (a ``tb`` module containing the IP instance ``dut``); assertion
    interfaces reference ``tb.dut...`` hierarchically, so elaborating
    the bare IP as the root cannot bind them. Wrap the declared top in
    a generated ``tb``/``dut`` pair unless the sources already provide
    a ``tb`` module.
    """
    if job.lane != "sva":
        return list(top_options), [], None
    tops = [opt[2:] for opt in top_options if opt.startswith("-s") and opt[2:]]
    if len(tops) != 1 or tops[0] == "tb":
        return list(top_options), [], None
    if "tb" in declared_modules(source_list):
        return list(top_options), [], None
    stub = work_root / "matrix-sva-tb.sv"
    stub.write_text(f"module tb;\n  {tops[0]} dut();\nendmodule\n")
    wrapper = work_root / "matrix-sva-tb.scr"
    wrapper.write_text(f"-c {compiler_source_list}\n{stub}\n")
    notes = [
        f"wrapped declared top {tops[0]!r} in a generated tb/dut pair "
        "to reproduce the dvsim testbench topology"
    ]
    return ["-stb"], notes, wrapper


def setup_command(
    job: Job,
    fusesoc: Path,
    opentitan_root: Path,
    matrix_core_root: Path,
    work_root: Path,
    requested_top: str,
) -> list[str]:
    # Earlgrey-PROD-M6 (the pinned OpenTitan release) requires lowRISC's own
    # fusesoc fork (python-requirements.txt pins "ot-0.5.dev0"), whose `run`
    # subcommand predates both `--work-root` (it's `--build-root`, and nests
    # output one level deeper as `<build-root>/<target>-<tool>/...` -- still
    # found fine by parse_makefile()'s recursive rglob below) and the
    # `--mapping` virtual-provider mechanism entirely (unrecognized argument,
    # hard CLI error). Provider selection for prim_generic instead happens
    # through each `lowrisc:prim:X` core's own `generate: {generator:
    # primgen, ...}` block (hw/ip/prim/util/primgen.py), which queries
    # fusesoc's own core database and defaults to the "generic"
    # implementation automatically when no other --flag selects a specific
    # technology -- so no explicit mapping is needed for the rtl/uvm/runtime/
    # sva lanes this driver exercises. provider_mappings()/PRIM_MAPPING/
    # ENGLISHBREAKFAST_MAPPING are kept (and still self-tested) as the
    # mechanism a newer OpenTitan revision with the real fusesoc --mapping
    # feature would need again, but are not applied to this command. The
    # mapping-core root is not scanned because this FuseSoC ignores `mapping`
    # and warns "Unknown item mapping in section Root". A separate source
    # overlay root contains only corrected source cores and is safe to scan.
    command = [
        str(fusesoc),
        f"--cores-root={opentitan_root}",
    ]
    source_override_root = matrix_core_root / "source-overrides"
    if job.lane in {"rtl", "sva"} and any(source_override_root.rglob("*.core")):
        command.append(f"--cores-root={source_override_root}")
    command.extend(
        [
            "run",
            f"--target={job.target}",
            "--tool=icarus",
            "--setup",
            f"--build-root={work_root}",
        ]
    )
    # OpenTitan's register cores deliberately gate their RTL filesets behind
    # these flags.  A direct IP simulation needs the IP-generated register
    # package, while system-level cores use the selected top's autogen copy.
    # Without the flag, FuseSoC resolves the dependency but silently emits no
    # pinmux_reg_pkg.sv (and similarly omits other generated register RTL).
    fileset_flag = None
    if job.core.vlnv.startswith("lowrisc:ip:"):
        fileset_flag = "fileset_ip"
    elif job.core.vlnv.startswith("lowrisc:systems:"):
        fileset_flag = "fileset_top"
    elif job.core.vlnv.startswith("lowrisc:fpv:"):
        fileset_flag = "fileset_ip"
    elif job.core.library == "dv" and job.core.name.startswith(("top_", "chip_")):
        fileset_flag = "fileset_top"
    elif job.simulation is not None:
        # DV wrapper cores are in the lowrisc:dv namespace; their source
        # manifest distinguishes an IP simulation from a chip/top simulation.
        source_parts = Path(job.simulation.core_file).parts
        if "ip" in source_parts and "hw" in source_parts:
            fileset_flag = "fileset_ip"
        elif any(part.startswith("top_") for part in source_parts):
            fileset_flag = "fileset_top"
    if fileset_flag:
        command.append(f"--flag={fileset_flag}")
    command.append(job.core.vlnv)
    return command


def compile_command(
    job: Job,
    iverilog: Path,
    source_list: Path,
    top_options: Sequence[str],
    output: Path,
    uvm_home: Path | None = None,
    commercial_unsafe: bool = False,
    additional_include_dirs: Sequence[Path] = (),
) -> list[str]:
    command = [str(iverilog), "-g2012", *top_options]
    if commercial_unsafe and job.lane in {"uvm", "runtime"}:
        command.append("-gcommercial-unsafe")
    if job.lane == "rtl":
        # Match OpenTitan's GTECH synthesis flow for generic RAM models.
        command.extend([
            "-S",
            "-DSYNTHESIS",
            "-DSYNTHESIS_MEMORY_BLACK_BOXING",
        ])
    elif job.lane == "sva":
        # OpenTitan's formal flows define FPV_ON. This controls assumption and
        # cover semantics in prim_assert.sv as well as FPV-specific RTL; the
        # tree has no ASSERT_ON consumer.
        command.extend(["-gassertions", "-DFPV_ON"])
        command.extend(SVA_EXTRA_DEFINES.get(job.core.vlnv, ()))
        # Only these two formal source graphs import UVM. Injecting the package
        # into every *_sva job attributes unrelated UVM fallback diagnostics to
        # otherwise-clean assertion cores and also changes ASSERT_ERROR macros.
        if job.core.vlnv in SVA_UVM_CORES:
            command.extend(["-uvm", "--uvm-no-dpi", "-DUVM"])
    else:
        if job.simulation is not None and (
            job.simulation.category == "uvm"
            or job.simulation.requires_uvm_library
        ):
            command.extend(["-uvm", "-DUVM", "-DUVM_NO_DEPRECATED"])
            # The register-model widths come from dvsim's tl_aw/tl_dw/tl_dbw
            # (common_sim_cfg.hjson); a core's overrides may widen them.
            for name, default in (
                ("ADDR", 32),
                ("DATA", 32),
                ("BYTENABLE", 4),
            ):
                prefix = f"+define+UVM_REG_{name}_WIDTH="
                value = next(
                    (
                        option[len(prefix):]
                        for option in job.simulation.build_options
                        if option.startswith(prefix) and option[len(prefix):].isdigit()
                    ),
                    str(default),
                )
                command.append(f"-DUVM_REG_{name}_WIDTH={value}")
            # Earlgrey-PROD-M6's common dvsim configuration selects UVM 1.2's
            # documented SV glob matcher with this define. Forward only this
            # known option when discovery retained it; other tool-specific
            # dvsim build options are not Icarus command-line arguments.
            if UVM_REGEX_NO_DPI_BUILD_OPTION in job.simulation.build_options:
                command.append("-DUVM_REGEX_NO_DPI")
        command.extend(["-DSIMULATION", "-DDUT_HIER=tb.dut"])
        if job.simulation is not None:
            command.extend(dvsim_define_arguments(job.simulation.build_options))
        defined = {arg[2:].split("=", 1)[0] for arg in command if arg.startswith("-D")}
        command.extend(
            define
            for define in UVM_EXTRA_DEFINES.get(job.core.vlnv, ())
            if define[2:].split("=", 1)[0] not in defined
        )
    command.extend(f"-I{directory}" for directory in additional_include_dirs)
    if uvm_home is not None and "-uvm" in command:
        command.append(f"--uvm-home={uvm_home}")
    command.extend(["-o", str(output), "-c", str(source_list)])
    return command


NATIVE_CXX_SUFFIXES = {".cc", ".cpp", ".cxx"}


def native_pkg_config_flags(
    packages: Sequence[str], env: dict[str, str], cwd: Path, timeout: int
) -> tuple[list[str], list[str], dict[str, object]]:
    """Resolve explicit native build dependencies before any matrix job runs."""
    pkg_config = shutil.which("pkg-config", path=env.get("PATH"))
    if not pkg_config:
        raise RuntimeError("--native-pkg-config requires pkg-config on PATH")
    if any(not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.+-]*", name) for name in packages):
        raise RuntimeError("--native-pkg-config needs plain package names")
    commands = {}
    flags = {}
    for option, label in (("--cflags", "cflags"), ("--libs", "libs")):
        command = [pkg_config, option, *packages]
        try:
            result = subprocess.run(command, cwd=cwd, env=env, capture_output=True,
                                    text=True, timeout=timeout)
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise RuntimeError(f"pkg-config {option} failed: {exc}") from exc
        if result.returncode:
            raise RuntimeError(f"pkg-config {option} failed: {result.stderr.strip()}")
        commands[label] = command
        flags[label] = shlex.split(result.stdout)
    resolved = Path(pkg_config).resolve()
    provenance = {
        "packages": list(packages), "executable": str(resolved),
        "executable_sha256": file_sha256(resolved),
        "commands": commands, "cflags": flags["cflags"], "libs": flags["libs"],
        "environment": {name: env[name] for name in (
            "PKG_CONFIG_PATH", "PKG_CONFIG_LIBDIR", "PKG_CONFIG_SYSROOT_DIR") if name in env},
    }
    return flags["cflags"], flags["libs"], provenance


def native_dpi_commands(
    sources: Sequence[str],
    include_dirs: Sequence[str],
    iverilog: Path,
    output: Path,
    export_stubs: Path | None,
    platform: str = sys.platform,
    cflags: Sequence[str] = (),
    libs: Sequence[str] = (),
) -> list[list[str]]:
    """Commands that build a job's native DPI sources into one library.

    `svdpi.h` comes from the Icarus install beside `iverilog`. The vvp
    symbols it declares resolve when `vvp -d` loads the library.
    """
    includes = [f"-I{iverilog.resolve().parent.parent / 'include' / 'iverilog'}"]
    includes += [f"-I{directory}" for directory in include_dirs]
    objects: list[str] = []
    commands: list[list[str]] = []
    all_sources = list(sources) + ([str(export_stubs)] if export_stubs else [])
    for index, source in enumerate(all_sources):
        obj = output.parent / f"matrix-dpi-{index}.o"
        objects.append(str(obj))
        if Path(source).suffix.casefold() in NATIVE_CXX_SUFFIXES:
            compiler = ["c++", "-std=c++17"]
        else:
            compiler = ["cc"]
        commands.append(
            [*compiler, "-O1", "-fPIC", *includes, *cflags, "-c", source, "-o", str(obj)]
        )
    link = ["c++", "-shared", "-o", str(output), *objects, *libs]
    if platform == "darwin":
        link[2:2] = ["-undefined", "dynamic_lookup"]
    commands.append(link)
    return commands


OTBN_MODEL_SOURCE_SHA256 = "751102f30ec5f8c28cd05aff653f4ff4baf641bc6fba286faae99697424bfb4e"

MEMLOAD_SOURCE_SHA256 = (
    "0ae62592964c0648c08f28fdd235ed7e7668f6071dc001aa6c1b6f652eea1956"
)
ROM_CTRL_SOURCE_SHA256 = (
    "72cdd7822b2b5df3de40dc933b85f31384841337c79f59dfe88f961d8e9f4c47"
)
TOP_EARLGREY_SOURCE_SHA256 = (
    "392bb28af6e913941f422b7745de4f3dd06514cdfbe66e3753d82dadd21867a3"
)
CHIP_EARLGREY_ASIC_SOURCE_SHA256 = (
    "d6d07633a708e6186df522777fe7d394e83ee4022e846b73216bf74022228bb2"
)
CHIP_EARLGREY_VERILATOR_SOURCE_SHA256 = (
    "34e397a18d3027ca6f27d0173acd490e5744836ac652e84c8e4df5e9ef1c35b4"
)
IBEX_TRACER_SOURCE_SHA256 = (
    "74326975d4fc618c97d95cf5451dd830ed5c79798c87d141858fcaf479120e29"
)
I2C_PROTOCOL_COV_SOURCE_SHA256 = (
    "d517b297226819233253bfe7ff9982c27bba2a97ff4759362bce5732b28d1611"
)
I2C_IF_SOURCE_SHA256 = (
    "9d27370ef1612a09cdc9e75e4b2c7d9eca22c5b310573a42a8c64b713d8579f8"
)
I2C_HOST_PERF_VSEQ_SOURCE_SHA256 = (
    "29802640c4558ce3eea87e6818a1b2e1b2ad36839b500d39c5de39089c09c3a8"
)
I2C_VSEQ_LIST_SOURCE_SHA256 = (
    "b778f251338cee17f82eda70ec5364233fce221fbb3a3a886e0bfdecca49d0cc"
)
KECCAK_2SHARE_FPV_SOURCE_SHA256 = (
    "d5bb74f7ee9fa85829c7c13690ec7b0f0805c8bfee3291da67fe14b83655f75c"
)
KECCAK_2SHARE_FPV_OVERLAY_SHA256 = (
    "7b696448599d541922404388981149166e981bba921225ffee2014737cd77791"
)
KECCAK_ROUND_FPV_SOURCE_SHA256 = (
    "c0395c0288979defdaa931394c668ab54646f45e3831b9b43340d03d12809ec7"
)
KECCAK_ROUND_FPV_OVERLAY_SHA256 = (
    "bef9dc1f9012924600d32766521371a0da390501ae44c8de785f3f496ef0a6c1"
)
MEMLOAD_DEBUG_BLOCK = '''  logic show_mem_paths;

  // Print the hierarchical path to the memory to help make formal connectivity checks easy.
  void'($value$plusargs("show_mem_paths=%0b", show_mem_paths));
  if (show_mem_paths) $display("%m");'''


MEMLOAD_SYNTHESIS_PROFILES = {
    "lowrisc:ip:rom_ctrl:0.1": ("rom_ctrl", "-srom_ctrl"),
    "lowrisc:systems:top_earlgrey:0.1": ("top_earlgrey", "-stop_earlgrey"),
    "lowrisc:systems:chip_earlgrey_asic:0.1": (
        "chip_earlgrey_asic",
        "-schip_earlgrey_asic",
    ),
    "lowrisc:systems:chip_earlgrey_verilator:0.1": (
        "chip_earlgrey_verilator",
        "-schip_earlgrey_verilator",
    ),
}

MEMLOAD_PROFILE_WRAPPERS = {
    "chip_earlgrey_asic": (
        "hw/top_earlgrey/rtl/autogen/chip_earlgrey_asic.sv",
        CHIP_EARLGREY_ASIC_SOURCE_SHA256,
    ),
    "chip_earlgrey_verilator": (
        "hw/top_earlgrey/rtl/chip_earlgrey_verilator.sv",
        CHIP_EARLGREY_VERILATOR_SOURCE_SHA256,
    ),
}


def memload_synthesis_profile(
    core_vlnv: str, top_options: Sequence[str]
) -> str | None:
    profile = MEMLOAD_SYNTHESIS_PROFILES.get(core_vlnv)
    if profile is None or any(option.startswith("-P") for option in top_options):
        return None
    profile_name, top_option = profile
    return profile_name if top_option in top_options else None


def empty_string_parameter(text: str, name: str) -> bool:
    return re.search(
        rf'\bparameter\s+(?:[A-Za-z_]\w*\s+)?{re.escape(name)}\s*=\s*""',
        text,
    ) is not None


def top_earlgrey_uses_default_mem_images(text: str) -> bool:
    match = re.search(
        r"\btop_earlgrey\s*#\s*\((.*?)\)\s*top_earlgrey\s*\(",
        text,
        re.S,
    )
    return match is not None and not re.search(
        r"\b(?:OtpCtrlMemInitFile|RomCtrlBootRomInitFile)\b",
        match.group(1),
    )


def guard_memload_debug(text: str) -> str:
    """Exclude only plusarg/display tracing from synthesis; retain readmemh."""
    if text.count(MEMLOAD_DEBUG_BLOCK) != 1:
        raise ValueError("prim_util_memload debug block anchor is not unique")
    guarded = "`ifndef SYNTHESIS\n" + MEMLOAD_DEBUG_BLOCK + "\n`endif"
    return text.replace(MEMLOAD_DEBUG_BLOCK, guarded)


def memload_synthesis_overlay(
    opentitan_root: Path,
    work_root: Path,
    core_vlnv: str,
    top_options: Sequence[str],
) -> tuple[Path, dict[str, str]]:
    """Stage the trace guard only when all selected memory images default empty."""
    profile = memload_synthesis_profile(core_vlnv, top_options)
    if profile is None:
        raise ValueError("memory-loader overlay requires a known empty-image top")

    source = opentitan_root / "hw/ip/prim/rtl/prim_util_memload.svh"
    source_hash = file_sha256(source)
    if source_hash != MEMLOAD_SOURCE_SHA256:
        raise ValueError(
            "ROM memory-loader overlay source hash mismatch: "
            f"expected {MEMLOAD_SOURCE_SHA256}, got {source_hash}"
        )

    if profile == "rom_ctrl":
        parameter_source = opentitan_root / "hw/ip/rom_ctrl/rtl/rom_ctrl.sv"
        expected_hash = ROM_CTRL_SOURCE_SHA256
    else:
        parameter_source = opentitan_root / "hw/top_earlgrey/rtl/autogen/top_earlgrey.sv"
        expected_hash = TOP_EARLGREY_SOURCE_SHA256

    parameter_hash = file_sha256(parameter_source)
    if parameter_hash != expected_hash:
        raise ValueError(
            f"{profile} memory parameter source hash mismatch: "
            f"expected {expected_hash}, got {parameter_hash}"
        )

    parameter_text = parameter_source.read_text()
    if profile == "rom_ctrl":
        if not empty_string_parameter(parameter_text, "BootRomInitFile"):
            raise ValueError("ROM controller default image parameter is not empty")
    elif not empty_string_parameter(
        parameter_text, "OtpCtrlMemInitFile"
    ) or not empty_string_parameter(parameter_text, "RomCtrlBootRomInitFile"):
        raise ValueError("Earl Grey ROM/OTP image defaults are not empty")

    validated_sources = [
        {"path": str(source), "sha256": source_hash},
        {"path": str(parameter_source), "sha256": parameter_hash},
    ]
    wrapper = MEMLOAD_PROFILE_WRAPPERS.get(profile)
    if wrapper is not None:
        wrapper_source = opentitan_root / wrapper[0]
        wrapper_hash = file_sha256(wrapper_source)
        if wrapper_hash != wrapper[1]:
            raise ValueError(f"{profile} wrapper source hash mismatch")
        if not top_earlgrey_uses_default_mem_images(wrapper_source.read_text()):
            raise ValueError(f"{profile} wrapper overrides a memory image")
        validated_sources.append(
            {"path": str(wrapper_source), "sha256": wrapper_hash}
        )

    overlay_dir = work_root / "source-overlays" / "memload_synthesis"
    overlay = overlay_dir / "prim_util_memload.svh"
    if overlay.is_symlink() or work_root.resolve() not in overlay.resolve().parents:
        raise ValueError("ROM memory-loader overlay staging path is unsafe")
    overlay_dir.mkdir(parents=True, exist_ok=True)
    overlay_text = guard_memload_debug(source.read_text())
    if "$readmemh(MemInitFile, mem);" not in overlay_text:
        raise ValueError("ROM memory-loader overlay removed the readmemh path")
    overlay.write_text(overlay_text)
    return overlay_dir, {
        "profile": profile,
        "source": str(source),
        "source_sha256": source_hash,
        "validated_sources": validated_sources,
        "parameter_defaults": "ROM and OTP images empty for selected top",
        "overlay": str(overlay),
        "overlay_sha256": file_sha256(overlay),
    }


def chip_earlgrey_verilator_source_text(text: str) -> str:
    """Correct missing multibit clock-control links in the Verilator wrapper."""
    replacements = (
        ("  logic hi_speed_sel;", "  prim_mubi_pkg::mubi4_t hi_speed_sel;"),
        ("  logic jen;", "  prim_mubi_pkg::mubi4_t jen;"),
        (
            "  logic scan_en;",
            "  logic scan_en;\n  prim_mubi_pkg::mubi4_t scanmode;",
        ),
        (
            ".all_clk_byp_req_i     ( ast_clk_byp_req ),",
            ".all_clk_byp_req_i     ( all_clk_byp_req ),",
        ),
        (
            ".all_clk_byp_ack_o     ( ast_clk_byp_ack ),",
            ".all_clk_byp_ack_o     ( all_clk_byp_ack ),",
        ),
    )
    for original, replacement in replacements:
        if text.count(original) != 1:
            raise ValueError("Earl Grey Verilator wrapper anchor is not unique")
        text = text.replace(original, replacement)
    return text


def ibex_tracer_automatic_locals(text: str) -> str:
    """Give per-activation trace locals automatic lifetime in procedural blocks."""
    file_handle_declaration = "      int fh = file_handle;"
    if text.count(file_handle_declaration) != 2:
        raise ValueError("Ibex tracer file-handle anchors are not unique")
    text = text.replace(
        file_handle_declaration,
        "      automatic int fh = file_handle;",
    )
    filename_declaration = '        string file_name_base = "trace_core";'
    if text.count(filename_declaration) != 1:
        raise ValueError("Ibex tracer filename anchor is not unique")
    return text.replace(
        filename_declaration,
        '        automatic string file_name_base = "trace_core";',
    )


def chip_earlgrey_verilator_source_overlay(
    opentitan_root: Path,
    work_root: Path,
    compiler_source_list: Path,
) -> tuple[Path, dict[str, object]]:
    """Stage hash-checked RTL fixes and redirect only this target's source list."""
    wrapper_source = opentitan_root / "hw/top_earlgrey/rtl/chip_earlgrey_verilator.sv"
    tracer_source = opentitan_root / "hw/vendor/lowrisc_ibex/rtl/ibex_tracer.sv"
    for source, expected_hash in (
        (wrapper_source, CHIP_EARLGREY_VERILATOR_SOURCE_SHA256),
        (tracer_source, IBEX_TRACER_SOURCE_SHA256),
    ):
        actual_hash = file_sha256(source)
        if actual_hash != expected_hash:
            raise ValueError(
                f"{source.name} source hash mismatch: "
                f"expected {expected_hash}, got {actual_hash}"
            )

    overlay_dir = work_root / "source-overlays" / "chip_earlgrey_verilator"
    if work_root.resolve() not in overlay_dir.resolve().parents:
        raise ValueError("Earl Grey Verilator overlay staging path is unsafe")
    overlay_dir.mkdir(parents=True, exist_ok=True)
    wrapper_overlay = overlay_dir / "chip_earlgrey_verilator.sv"
    tracer_overlay = overlay_dir / "ibex_tracer.sv"
    wrapper_overlay.write_text(
        chip_earlgrey_verilator_source_text(wrapper_source.read_text())
    )
    tracer_overlay.write_text(
        ibex_tracer_automatic_locals(tracer_source.read_text())
    )

    if (
        compiler_source_list.is_symlink()
        or work_root.resolve() not in compiler_source_list.resolve().parents
    ):
        raise ValueError("Earl Grey Verilator source list is outside its build root")
    source_list_text = compiler_source_list.read_text()
    source_replacements = (
        (
            "../src/lowrisc_systems_chip_earlgrey_verilator_0.1/rtl/"
            "chip_earlgrey_verilator.sv",
            str(wrapper_overlay),
        ),
        (
            "../src/lowrisc_ibex_ibex_tracer_0.1/rtl/ibex_tracer.sv",
            str(tracer_overlay),
        ),
    )
    for original, replacement in source_replacements:
        if source_list_text.splitlines().count(original) != 1:
            raise ValueError("Earl Grey Verilator source-list anchor is not unique")
        source_list_text = source_list_text.replace(original, replacement)
    patched_source_list = compiler_source_list.with_name(
        f"{compiler_source_list.stem}-source-overlays{compiler_source_list.suffix}"
    )
    if patched_source_list.is_symlink():
        raise ValueError("Earl Grey Verilator source-list overlay is a symlink")
    patched_source_list.write_text(source_list_text)
    overlays = [
        {
            "source": str(source),
            "source_sha256": file_sha256(source),
            "overlay": str(overlay),
            "overlay_sha256": file_sha256(overlay),
        }
        for source, overlay in (
            (wrapper_source, wrapper_overlay),
            (tracer_source, tracer_overlay),
        )
    ]
    return patched_source_list, {
        "profile": "chip_earlgrey_verilator",
        "source_list": str(compiler_source_list),
        "source_list_overlay": str(patched_source_list),
        "overlays": overlays,
    }


def i2c_protocol_cov_source_text(text: str) -> str:
    """Move I2C coverage object construction into the existing enable branch."""
    before = '''    if (en_cov) begin
      i2c_protocol_cov_cg   i2c_protocol_cov = new();
      i2c_rd_wr_cg          i2c_rd_wr_cov = new();
      i2c_cmd_complete_cg   cmd_complete_cg = new();'''
    after = '''    i2c_protocol_cov_cg   i2c_protocol_cov;
    i2c_rd_wr_cg          i2c_rd_wr_cov;
    i2c_cmd_complete_cg   cmd_complete_cg;
    if (en_cov) begin
      i2c_protocol_cov = new();
      i2c_rd_wr_cov = new();
      cmd_complete_cg = new();'''
    if text.count(before) != 1:
        raise ValueError("I2C coverage constructor block is not unique")
    return text.replace(before, after)


def i2c_if_source_text(text: str) -> str:
    before = "if (sample.size() > tc.tSetupBit) sample.pop_back();"
    after = "if (sample.size() > tc.tSetupBit) void'(sample.pop_back());"
    if text.count(before) != 1:
        raise ValueError("I2C interface pop_back call is not unique")
    return text.replace(before, after)


def i2c_host_perf_vseq_source_text(text: str) -> str:
    before = "    solve cfg.clk_freq_mhz before speed_mode;\n"
    if text.count(before) != 1:
        raise ValueError("I2C host performance solve constraint is not unique")
    return text.replace(before, "")


def i2c_source_overlay(
    opentitan_root: Path,
    work_root: Path,
    source_list: Path,
    *,
    sim_sources: bool,
) -> tuple[Path, dict[str, object]]:
    """Stage the qualified I2C warning cleanup without modifying OpenTitan."""
    overlay_dir = work_root / "source-overlays" / "i2c_runtime_warning_cleanup"
    if work_root.resolve() not in overlay_dir.resolve().parents:
        raise ValueError("I2C overlay staging path is unsafe")
    overlay_dir.mkdir(parents=True, exist_ok=True)

    files: list[dict[str, str]] = []

    def stage_source(
        relative_source: str,
        output_name: str,
        expected_source_hash: str,
        expected_overlay_hash: str,
        transform: Callable[[str], str],
    ) -> Path:
        source = opentitan_root / relative_source
        source_hash = file_sha256(source)
        if source_hash != expected_source_hash:
            raise ValueError(
                f"I2C overlay source hash mismatch for {relative_source}: "
                f"expected {expected_source_hash}, got {source_hash}"
            )
        overlay = overlay_dir / output_name
        if overlay.is_symlink():
            raise ValueError(f"I2C overlay destination is a symlink: {overlay}")
        overlay.parent.mkdir(parents=True, exist_ok=True)
        overlay.write_text(transform(source.read_text()))
        overlay_hash = file_sha256(overlay)
        if overlay_hash != expected_overlay_hash:
            raise ValueError(
                f"I2C overlay result hash mismatch for {relative_source}: "
                f"expected {expected_overlay_hash}, got {overlay_hash}"
            )
        files.append(
            {
                "source": str(source),
                "source_sha256": source_hash,
                "overlay": str(overlay),
                "overlay_sha256": overlay_hash,
            }
        )
        return overlay

    coverage_overlay = stage_source(
        "hw/ip/i2c/dv/sva/i2c_protocol_cov.sv",
        "i2c_protocol_cov.sv",
        I2C_PROTOCOL_COV_SOURCE_SHA256,
        "7acaf1466513f2fd8f28b31261b0d78f9d5e388bdb0ee73f5ce883e2030ef2fa",
        i2c_protocol_cov_source_text,
    )
    if sim_sources:
        interface_overlay = stage_source(
            "hw/dv/sv/i2c_agent/i2c_if.sv",
            "i2c_if.sv",
            I2C_IF_SOURCE_SHA256,
            "c9a24cfa67030cb6defb6fed64528f019ca5885d34adb324681762b04a40b34e",
            i2c_if_source_text,
        )
        sequence_overlay = stage_source(
            "hw/ip/i2c/dv/env/seq_lib/i2c_host_perf_vseq.sv",
            "seq_lib/i2c_host_perf_vseq.sv",
            I2C_HOST_PERF_VSEQ_SOURCE_SHA256,
            "c22bd8423b64065942b43f39a924389b9f665dc30ce7a1cff3d8c7999bea3f9f",
            i2c_host_perf_vseq_source_text,
        )
        sequence_list = opentitan_root / "hw/ip/i2c/dv/env/seq_lib/i2c_vseq_list.sv"
        sequence_list_hash = file_sha256(sequence_list)
        if sequence_list_hash != I2C_VSEQ_LIST_SOURCE_SHA256:
            raise ValueError(
                "I2C sequence-list source hash mismatch: "
                f"expected {I2C_VSEQ_LIST_SOURCE_SHA256}, got {sequence_list_hash}"
            )
        sequence_list_overlay = overlay_dir / "seq_lib/i2c_vseq_list.sv"
        if sequence_list_overlay.is_symlink():
            raise ValueError("I2C sequence-list overlay is a symlink")
        sequence_list_overlay.parent.mkdir(parents=True, exist_ok=True)
        sequence_list_overlay.write_bytes(sequence_list.read_bytes())
        files.append(
            {
                "source": str(sequence_list),
                "source_sha256": sequence_list_hash,
                "overlay": str(sequence_list_overlay),
                "overlay_sha256": file_sha256(sequence_list_overlay),
            }
        )

    if source_list.is_symlink() or work_root.resolve() not in source_list.resolve().parents:
        raise ValueError("I2C source list is outside its build root")
    source_list_text = source_list.read_text()
    replacements = {
        "../src/lowrisc_dv_i2c_sva_0.1/i2c_protocol_cov.sv": str(coverage_overlay),
    }
    if sim_sources:
        replacements["../src/lowrisc_dv_i2c_agent_0.1/i2c_if.sv"] = str(
            interface_overlay
        )
        sequence_include = "+incdir+../src/lowrisc_dv_i2c_env_0.1/seq_lib"
        if source_list_text.splitlines().count(sequence_include) != 1:
            raise ValueError("I2C sequence include-directory anchor is not unique")
        source_list_text = source_list_text.replace(
            sequence_include,
            f"+incdir+{sequence_overlay.parent}\n{sequence_include}",
        )
    for anchor, replacement in replacements.items():
        if source_list_text.splitlines().count(anchor) != 1:
            raise ValueError(f"I2C source-list anchor is not unique: {anchor}")
        source_list_text = source_list_text.replace(anchor, replacement)

    source_list_overlay = source_list.with_name(
        f"{source_list.stem}-source-overlays{source_list.suffix}"
    )
    if source_list_overlay.is_symlink():
        raise ValueError("I2C source-list overlay is a symlink")
    source_list_overlay.write_text(source_list_text)
    return source_list_overlay, {
        "profile": "i2c_runtime_warning_cleanup",
        "sources": files,
        "source_list": str(source_list),
        "source_list_overlay": str(source_list_overlay),
    }


def keccak_2share_fpv_syntax_source_text(text: str) -> str:
    import_anchor = ");\n\n  localparam int W"
    if text.count(import_anchor) != 1:
        raise ValueError("Keccak 2-share SVA module header is not unique")
    text = text.replace(
        import_anchor,
        ");\n  import prim_mubi_pkg::*;\n\n  localparam int W",
    )
    before = '''          keccak_st_d = StPhase1;
      end
      StPhase2Cycle1: begin'''
    after = '''          keccak_st_d = StPhase1;
        end
      end
      StPhase2Cycle1: begin'''
    if text.count(before) != 1:
        raise ValueError("Keccak 2-share SVA case block is not unique")
    return text.replace(before, after)


def keccak_2share_fpv_source_text(text: str) -> str:
    text = keccak_2share_fpv_syntax_source_text(text)
    replacements = (
        (
            "  logic [1:0] cycle;",
            """  logic low_then_high_d, low_then_high_q;
  logic dom_out_low_d, dom_out_low_q;
  logic dom_in_low_d, dom_in_low_q;
  logic dom_in_rand_ext_d, dom_in_rand_ext_q;
  logic dom_update;""",
            "DOM control declarations",
        ),
        (
            "    cycle = 2'h0;\n    unique case (keccak_st)",
            """    low_then_high_d = low_then_high_q;
    dom_in_low_d = dom_in_low_q;
    dom_in_rand_ext_d = dom_in_rand_ext_q;
    dom_update = 1'b0;
    unique case (keccak_st)""",
            "DOM control defaults",
        ),
        (
            """      StIdle: begin
        sel_mux = MuBi4False;
        if (valid_i) begin
          keccak_st_d = StPhase1;""",
            """      StIdle: begin
        sel_mux = MuBi4False;
        if (valid_i) begin
          keccak_st_d = StPhase1;
          dom_in_low_d = low_then_high_q;
          dom_in_rand_ext_d = 1'b0;""",
            "idle transition controls",
        ),
        (
            """      StPhase1: begin
        sel_mux = MuBi4False;
        cycle = 2'h0;

        if (rand_early_i || rand_valid_i) begin
          keccak_st_d = StPhase2Cycle1;
          update_state = 1'b1;""",
            """      StPhase1: begin
        sel_mux = MuBi4False;

        if (rand_early_i || rand_valid_i) begin
          keccak_st_d = StPhase2Cycle1;
          update_state = 1'b1;
          low_then_high_d = rand_aux_i;
          dom_in_low_d = low_then_high_d;
          dom_in_rand_ext_d = 1'b1;""",
            "phase-one transition controls",
        ),
        (
            """      StPhase2Cycle1: begin
        sel_mux = MuBi4True;
        cycle = 2'h1;
        keccak_st_d = StPhase2Cycle2;""",
            """      StPhase2Cycle1: begin
        sel_mux = MuBi4True;
        dom_update = 1'b1;
        dom_in_low_d = ~low_then_high_q;
        dom_in_rand_ext_d = 1'b1;
        keccak_st_d = StPhase2Cycle2;""",
            "phase-two cycle-one controls",
        ),
        (
            """      StPhase2Cycle2: begin
        sel_mux = MuBi4True;
        cycle = 2'h2;
        update_state = 1'b1;
        keccak_st_d = StPhase2Cycle3;""",
            """      StPhase2Cycle2: begin
        sel_mux = MuBi4True;
        dom_update = 1'b1;
        dom_in_low_d = low_then_high_q;
        dom_in_rand_ext_d = 1'b0;
        update_state = 1'b1;
        keccak_st_d = StPhase2Cycle3;""",
            "phase-two cycle-two controls",
        ),
        (
            """      StPhase2Cycle3: begin
        sel_mux = MuBi4True;
        cycle = 2'h3;
        update_state = 1'b1;
        if (round == NumRound-1) begin
          keccak_st_d = StIdle;
          inc_round = 1'b1;
        end else begin
          keccak_st_d = StPhase1;

          inc_round = 1'b1;
        end""",
            """      StPhase2Cycle3: begin
        sel_mux = MuBi4True;
        update_state = 1'b1;
        if (round == NumRound-1) begin
          keccak_st_d = StIdle;
          inc_round = 1'b1;
        end else begin
          keccak_st_d = StPhase1;
          inc_round = 1'b1;
          dom_in_low_d = low_then_high_q;
          dom_in_rand_ext_d = 1'b0;
        end""",
            "phase-two cycle-three controls",
        ),
        (
            """    endcase
  end


  always_ff @(posedge clk_i or negedge rst_ni) begin""",
            """    endcase
    dom_out_low_d = ~dom_in_low_d;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      low_then_high_q <= 1'b0;
      dom_out_low_q <= 1'b0;
      dom_in_low_q <= 1'b0;
      dom_in_rand_ext_q <= 1'b0;
    end else begin
      low_then_high_q <= low_then_high_d;
      dom_out_low_q <= dom_out_low_d;
      dom_in_low_q <= dom_in_low_d;
      dom_in_rand_ext_q <= dom_in_rand_ext_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin""",
            "DOM control registers",
        ),
        (
            """    .clk_i,
    .rst_ni,

    .rnd_i        (round),
    .phase_sel_i  (sel_mux),
    .cycle_i      (cycle),
    .rand_aux_i   (rand_aux_i),""",
            """    .clk_i,
    .rst_ni,
    .lc_escalate_en_i(lc_ctrl_pkg::LC_TX_DEFAULT),

    .rnd_i            (round),
    .phase_sel_i      (sel_mux),
    .dom_out_low_i    (dom_out_low_q),
    .dom_in_low_i     (dom_in_low_q),
    .dom_in_rand_ext_i(dom_in_rand_ext_q),
    .dom_update_i     (dom_update),""",
            "masked DUT control ports",
        ),
        (
            """    .clk_i,
    .rst_ni,

    .rnd_i      (round),
    .phase_sel_i('0),
    .cycle_i    ('0),
    .rand_aux_i ('0),""",
            """    .clk_i,
    .rst_ni,
    .lc_escalate_en_i(lc_ctrl_pkg::LC_TX_DEFAULT),

    .rnd_i            (round),
    .phase_sel_i      ('0),
    .dom_out_low_i    (1'b0),
    .dom_in_low_i     (1'b0),
    .dom_in_rand_ext_i(1'b0),
    .dom_update_i     (1'b0),""",
            "unmasked DUT control ports",
        ),
    )
    for before, after, label in replacements:
        if text.count(before) != 1:
            raise ValueError(f"Keccak 2-share SVA {label} anchor is not unique")
        text = text.replace(before, after)
    return text


def keccak_round_fpv_source_text(text: str) -> str:
    replacements = (
        (
            "  logic run, clear, masked_complete, unmasked_complete;",
            "  logic run, masked_complete, unmasked_complete;\n"
            "  prim_mubi_pkg::mubi4_t clear;",
            "clear signal type",
        ),
        (
            "    clear = 1'b 0;",
            "    clear = prim_mubi_pkg::MuBi4False;",
            "clear deassertion",
        ),
        (
            "        clear = 1'b1;",
            "        clear = prim_mubi_pkg::MuBi4True;",
            "clear assertion",
        ),
    )
    for before, after, label in replacements:
        if text.count(before) != 1:
            raise ValueError(f"Keccak round FPV {label} anchor is not unique")
        text = text.replace(before, after)
    return text


def keccak_2share_fpv_source_overlay(
    opentitan_root: Path,
    work_root: Path,
    source_list: Path,
) -> tuple[Path, dict[str, object]]:
    """Adapt the pinned FPV controller to the DOM-based Keccak interface."""
    source = opentitan_root / "hw/ip/kmac/fpv/tb/keccak_2share_fpv.sv"
    source_hash = file_sha256(source)
    if source_hash != KECCAK_2SHARE_FPV_SOURCE_SHA256:
        raise ValueError(
            "Keccak 2-share SVA source hash mismatch: "
            f"expected {KECCAK_2SHARE_FPV_SOURCE_SHA256}, got {source_hash}"
        )
    overlay_dir = work_root / "source-overlays" / "keccak_2share_fpv"
    if work_root.resolve() not in overlay_dir.resolve().parents:
        raise ValueError("Keccak 2-share SVA overlay staging path is unsafe")
    overlay_dir.mkdir(parents=True, exist_ok=True)
    overlay = overlay_dir / "keccak_2share_fpv.sv"
    if overlay.is_symlink():
        raise ValueError("Keccak 2-share SVA overlay is a symlink")
    overlay.write_text(keccak_2share_fpv_source_text(source.read_text()))
    overlay_hash = file_sha256(overlay)
    if overlay_hash != KECCAK_2SHARE_FPV_OVERLAY_SHA256:
        raise ValueError(f"Keccak 2-share SVA overlay hash mismatch: {overlay_hash}")

    if (
        source_list.is_symlink()
        or work_root.resolve() not in source_list.resolve().parents
    ):
        raise ValueError("Keccak 2-share SVA source list is outside its build root")
    source_list_text = source_list.read_text()
    source_anchor = (
        "../src/lowrisc_fpv_keccak_2share_fpv_0.1/tb/keccak_2share_fpv.sv"
    )
    if source_list_text.splitlines().count(source_anchor) != 1:
        raise ValueError("Keccak 2-share SVA source-list anchor is not unique")
    source_list_overlay = source_list.with_name(
        f"{source_list.stem}-source-overlays{source_list.suffix}"
    )
    if source_list_overlay.is_symlink():
        raise ValueError("Keccak 2-share SVA source-list overlay is a symlink")
    source_list_overlay.write_text(
        source_list_text.replace(source_anchor, str(overlay))
    )
    return source_list_overlay, {
        "profile": "keccak_2share_fpv_dom_controller",
        "source": str(source),
        "source_sha256": source_hash,
        "overlay": str(overlay),
        "overlay_sha256": overlay_hash,
        "source_list": str(source_list),
        "source_list_overlay": str(source_list_overlay),
    }


def keccak_round_fpv_source_overlay(
    opentitan_root: Path,
    work_root: Path,
    source_list: Path,
) -> tuple[Path, dict[str, object]]:
    """Use the full MuBi encoding on the Keccak round clear signal."""
    source = opentitan_root / "hw/ip/kmac/fpv/tb/keccak_round_fpv.sv"
    source_hash = file_sha256(source)
    if source_hash != KECCAK_ROUND_FPV_SOURCE_SHA256:
        raise ValueError(
            "Keccak round FPV source hash mismatch: "
            f"expected {KECCAK_ROUND_FPV_SOURCE_SHA256}, got {source_hash}"
        )
    overlay_dir = work_root / "source-overlays" / "keccak_round_fpv"
    if work_root.resolve() not in overlay_dir.resolve().parents:
        raise ValueError("Keccak round FPV overlay staging path is unsafe")
    overlay_dir.mkdir(parents=True, exist_ok=True)
    overlay = overlay_dir / "keccak_round_fpv.sv"
    if overlay.is_symlink():
        raise ValueError("Keccak round FPV overlay is a symlink")
    overlay.write_text(keccak_round_fpv_source_text(source.read_text()))
    overlay_hash = file_sha256(overlay)
    if overlay_hash != KECCAK_ROUND_FPV_OVERLAY_SHA256:
        raise ValueError(f"Keccak round FPV overlay hash mismatch: {overlay_hash}")

    if (
        source_list.is_symlink()
        or work_root.resolve() not in source_list.resolve().parents
    ):
        raise ValueError("Keccak round FPV source list is outside its build root")
    source_list_text = source_list.read_text()
    source_anchor = (
        "../src/lowrisc_fpv_keccak_round_fpv_0.1/"
        "tb/keccak_round_fpv.sv"
    )
    if source_list_text.splitlines().count(source_anchor) != 1:
        raise ValueError("Keccak round FPV source-list anchor is not unique")
    source_list_overlay = source_list.with_name(
        f"{source_list.stem}-source-overlays{source_list.suffix}"
    )
    if source_list_overlay.is_symlink():
        raise ValueError("Keccak round FPV source-list overlay is a symlink")
    source_list_overlay.write_text(
        source_list_text.replace(source_anchor, str(overlay))
    )
    return source_list_overlay, {
        "profile": "keccak_round_fpv_mubi4_clear",
        "source": str(source),
        "source_sha256": source_hash,
        "overlay": str(overlay),
        "overlay_sha256": overlay_hash,
        "source_list": str(source_list),
        "source_list_overlay": str(source_list_overlay),
    }


def otbn_trace_finish_overlay(
    native_sources: Sequence[str],
    opentitan_root: Path,
    source_list: Path,
    work_root: Path,
) -> tuple[tuple[str, ...], dict[str, str]]:
    """Run the OTBN trace check at final model destruction on the pinned source."""
    source = opentitan_root / "hw/ip/otbn/dv/model/otbn_model.cc"
    source_hash = file_sha256(source)
    if source_hash != OTBN_MODEL_SOURCE_SHA256:
        raise ValueError(
            "OTBN trace-finish overlay source hash mismatch: "
            f"expected {OTBN_MODEL_SOURCE_SHA256}, got {source_hash}"
        )
    text = source.read_text()
    original = "void otbn_model_destroy(OtbnModel *model) { delete model; }"
    replacement = """void otbn_model_destroy(OtbnModel *model) {
  if (model && model->has_rtl()) {
    OtbnTraceChecker::get().Finish();
  }
  delete model;
}"""
    if text.count(original) != 1:
        raise ValueError("OTBN trace-finish overlay anchor is not unique")
    if not any(Path(item).resolve() == source.resolve() for item in native_sources):
        raise ValueError("OTBN model source is missing from the native source list")

    overlay = (
        source_list.parent.parent
        / "src/lowrisc_dv_otbn_model_0.1/otbn_model.cc"
    )
    if overlay.is_symlink() or work_root.resolve() not in overlay.resolve().parents:
        raise ValueError("OTBN trace-finish overlay staging path is unsafe")
    overlay.write_text(text.replace(original, replacement))
    sources = tuple(
        str(overlay) if Path(item).resolve() == source.resolve() else item
        for item in native_sources
    )
    return sources, {
        "source": str(source),
        "source_sha256": source_hash,
        "overlay": str(overlay),
        "overlay_sha256": file_sha256(overlay),
    }


# Defines the command builder sets itself, from the job's lane and category.
HARNESS_MANAGED_DEFINES = {
    "UVM",
    "UVM_NO_DEPRECATED",
    "UVM_REGEX_NO_DPI",
    "UVM_REG_ADDR_WIDTH",
    "UVM_REG_DATA_WIDTH",
    "UVM_REG_BYTENABLE_WIDTH",
    "SIMULATION",
    "DUT_HIER",
}


def dvsim_define_arguments(build_options: Sequence[str]) -> list[str]:
    """Translate dvsim `+define+A=1+B` build options to iverilog -D flags.

    `+define+` is simulator-independent; everything else in build_opts is a
    VCS/Xcelium flag. An option still holding a `{...}` placeholder is skipped.
    """
    result = []
    seen = set()
    for option in build_options:
        if not option.startswith("+define+") or "{" in option:
            continue
        for item in option[len("+define+"):].split("+"):
            name = item.split("=", 1)[0]
            if not name or name in HARNESS_MANAGED_DEFINES or name in seen:
                continue
            seen.add(name)
            result.append("-D" + item)
    return result


TIMESCALE_RE = re.compile(
    r"^(?:1|10|100)(?:s|ms|us|ns|ps|fs)/(?:1|10|100)(?:s|ms|us|ns|ps|fs)$"
)


def simulation_source_list(job: Job, source_list: Path, work_root: Path) -> Path:
    """Apply the project-declared default timescale to Icarus simulations.

    Icarus accepts ``+timescale+`` in command files, while Edalize's Icarus
    backend does not translate dvsim's simulator-independent ``timescale``
    setting.  Use a nested command file so the generated FuseSoC list remains
    an unmodified, auditable input.
    """
    timescale = job.simulation.timescale if job.simulation is not None else None
    if job.lane not in {"uvm", "runtime"} or not timescale:
        return source_list
    if not TIMESCALE_RE.fullmatch(timescale):
        raise ValueError(
            f"invalid dvsim timescale {timescale!r} for {job.core.vlnv}"
        )
    wrapper = work_root / "matrix-iverilog.scr"
    wrapper.write_text(f"+timescale+{timescale}\n-c {source_list}\n")
    return wrapper


def result_base(job: Job, work_root: Path, mappings: list[str]) -> dict[str, object]:
    result: dict[str, object] = {
        "lane": job.lane,
        "core": job.core.vlnv,
        "description": job.core.description,
        "target": job.target,
        "work_root": str(work_root),
        "provider_mappings": mappings,
        "status": "NOT_RUN",
    }
    if job.simulation is not None:
        result.update(
            {
                "simulation_category": job.simulation.category,
                "simulation_default_tool": job.simulation.default_tool,
                "simulation_toplevels": job.simulation.toplevels,
                "simulation_core_file": job.simulation.core_file,
                "dvsim_config": job.simulation.dvsim_config,
                "dvsim_test": job.simulation.dvsim_test,
                "uvm_test": job.simulation.uvm_test,
                "uvm_test_seq": job.simulation.uvm_test_seq,
                "dvsim_regression": job.simulation.dvsim_regression,
                "dvsim_runtime_args": job.simulation.runtime_args,
                "dvsim_build_mode": job.simulation.build_mode,
                "dvsim_build_options": job.simulation.build_options,
                "dvsim_timescale": job.simulation.timescale,
                "native_dependencies": job.simulation.native_dependencies,
                "dpi_dependencies": job.simulation.dpi_dependencies,
                "orchestration_requirements": (
                    job.simulation.orchestration_requirements
                ),
                "unresolved_runtime_options": (
                    job.simulation.unresolved_runtime_options
                ),
                "simulation_metadata_warnings": job.simulation.metadata_warnings,
            }
        )
    return result


def write_log(path: Path, heading: str, result: CommandResult) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        f"{heading}\ncommand: {short_command(result.command)}\n"
        f"returncode: {result.returncode}\n"
        f"duration_seconds: {result.duration_seconds:.3f}\n\n{result.output}"
    )


def run_job(
    job: Job,
    *,
    args: argparse.Namespace,
    opentitan_root: Path,
    build_root: Path,
    matrix_core_root: Path,
    fusesoc: Path,
    iverilog: Path,
    vvp: Path,
    env: dict[str, str],
    native_cflags: Sequence[str] = (),
    native_libs: Sequence[str] = (),
) -> dict[str, object]:
    work_root = build_root / job.lane / safe_name(job.core.vlnv)
    work_root.mkdir(parents=True, exist_ok=True)
    mappings = provider_mappings(job, args.top)
    record = result_base(job, work_root, mappings)

    setup = command_result(
        setup_command(
            job,
            fusesoc,
            opentitan_root,
            matrix_core_root,
            work_root,
            args.top,
        ),
        cwd=opentitan_root,
        env=env,
        timeout=args.setup_timeout,
    )
    setup_log = work_root / "matrix-setup.log"
    write_log(setup_log, "OpenTitan FuseSoC setup", setup)
    setup_findings = actionable_setup_lines(setup.output)
    setup_actionable_findings = setup_findings
    setup_benign_diagnostics: list[str] = []
    record.update(
        {
            "setup_command": short_command(setup.command),
            "setup_returncode": setup.returncode,
            "setup_duration_seconds": round(setup.duration_seconds, 3),
            "setup_timed_out": setup.timed_out,
            "setup_log": str(setup_log),
            "setup_warnings": setup_findings,
        }
    )
    if setup.timed_out:
        record["status"] = "SETUP_TIMEOUT"
        return record
    if setup.returncode != 0:
        if NO_TOPLEVEL_RE.search(setup.output):
            # CAPI package/fileset cores are dependencies, not standalone
            # elaboration units.  They are compiled through every runnable
            # parent that depends on them and must not become false failures.
            record.update(
                {
                    "status": "DEPENDENCY_ONLY",
                    "coverage_mode": "compiled_through_parent_toplevel",
                }
            )
            return record
        defect = upstream_defect_for(job.core.vlnv, "setup", [setup.output])
        if defect is not None:
            record["status"] = "UPSTREAM_INVALID"
            record["upstream_defect"] = defect.note
        else:
            record["status"] = "SETUP_FAIL"
        return record
    if args.setup_only:
        record["status"] = "SETUP_DEBT" if setup_findings else "SETUP_ONLY"
        return record

    source_overlays: list[dict[str, object]] = []
    try:
        source_list, top_options = parse_makefile(work_root)
        source_list_for_compile = source_list
        i2c_sva_job = (
            job.lane == "sva" and job.core.vlnv == "lowrisc:dv:i2c_sva:0.1"
        )
        i2c_sim_job = (
            job.lane in {"uvm", "runtime"}
            and job.core.vlnv == "lowrisc:dv:i2c_sim:0.1"
        )
        if i2c_sva_job or i2c_sim_job:
            try:
                source_list_for_compile, source_overlay = i2c_source_overlay(
                    opentitan_root,
                    work_root,
                    source_list,
                    sim_sources=i2c_sim_job,
                )
            except (OSError, ValueError) as exc:
                record.update(
                    {"status": "SOURCE_OVERLAY_FAIL", "matrix_error": str(exc)}
                )
                return record
            source_overlays.append(source_overlay)
        if (
            job.lane == "sva"
            and job.core.vlnv == "lowrisc:fpv:keccak_2share_fpv:0.1"
        ):
            try:
                source_list_for_compile, source_overlay = (
                    keccak_2share_fpv_source_overlay(
                        opentitan_root, work_root, source_list
                    )
                )
            except (OSError, ValueError) as exc:
                record.update(
                    {"status": "SOURCE_OVERLAY_FAIL", "matrix_error": str(exc)}
                )
                return record
            source_overlays.append(source_overlay)
        if (
            job.lane == "sva"
            and job.core.vlnv == "lowrisc:fpv:keccak_round_fpv:0.1"
        ):
            try:
                source_list_for_compile, source_overlay = (
                    keccak_round_fpv_source_overlay(
                        opentitan_root, work_root, source_list
                    )
                )
            except (OSError, ValueError) as exc:
                record.update(
                    {"status": "SOURCE_OVERLAY_FAIL", "matrix_error": str(exc)}
                )
                return record
            source_overlays.append(source_overlay)
        top_options, top_notes, package_wrapper = validated_top_options(
            job, source_list_for_compile, top_options, work_root
        )
        compiler_source_list = simulation_source_list(
            job, source_list_for_compile, work_root
        )
        if package_wrapper is not None:
            compiler_source_list = package_wrapper
        top_options, sva_notes, sva_wrapper = sva_testbench_wrapper(
            job,
            source_list_for_compile,
            top_options,
            work_root,
            compiler_source_list,
        )
        if sva_wrapper is not None:
            compiler_source_list = sva_wrapper
    except (FileNotFoundError, OSError, ValueError) as exc:
        record.update({"status": "SETUP_FAIL", "matrix_error": str(exc)})
        return record
    if job.lane in {"rtl", "sva", "uvm"}:
        setup_actionable_findings, setup_benign_diagnostics = (
            classify_compile_setup_warnings(job.lane, setup_findings, source_list)
        )
        record.update(
            {
                "setup_actionable_warnings": setup_actionable_findings,
                "setup_benign_diagnostics": setup_benign_diagnostics,
            }
        )
    if top_notes:
        record["top_selection_notes"] = top_notes
    if sva_notes:
        record["sva_topology_notes"] = sva_notes

    executable = work_root / f"matrix-{job.lane}.vvp"
    additional_include_dirs: tuple[Path, ...] = ()
    if job.lane == "rtl" and memload_synthesis_profile(
        job.core.vlnv, top_options
    ) is not None:
        try:
            overlay_dir, source_overlay = memload_synthesis_overlay(
                opentitan_root, work_root, job.core.vlnv, top_options
            )
        except (OSError, ValueError) as exc:
            record.update(
                {"status": "SOURCE_OVERLAY_FAIL", "matrix_error": str(exc)}
            )
            return record
        additional_include_dirs = (overlay_dir,)
        source_overlays.append(source_overlay)
    if (
        job.lane == "rtl"
        and job.core.vlnv == "lowrisc:systems:chip_earlgrey_verilator:0.1"
    ):
        try:
            compiler_source_list, source_overlay = (
                chip_earlgrey_verilator_source_overlay(
                    opentitan_root, work_root, compiler_source_list
                )
            )
        except (OSError, ValueError) as exc:
            record.update(
                {"status": "SOURCE_OVERLAY_FAIL", "matrix_error": str(exc)}
            )
            return record
        source_overlays.append(source_overlay)
    if source_overlays:
        record["source_overlays"] = source_overlays
    compile_result = command_result(
        compile_command(
            job, iverilog, compiler_source_list, top_options, executable,
            args.uvm_home, args.commercial_unsafe, additional_include_dirs,
        ),
        cwd=source_list.parent,
        env=env,
        timeout=args.compile_timeout,
    )
    compile_log = work_root / "matrix-compile.log"
    write_log(compile_log, "OpenTitan Icarus compile", compile_result)
    hard_errors = matching_lines(compile_result.output, HARD_ERROR_PATTERNS)
    if compile_result.returncode != 0 and not hard_errors:
        hard_errors = [
            "compiler exited with status "
            f"{compile_result.returncode} without a recognized hard diagnostic; "
            "see the complete compile log"
        ]
    compile_allowlist = compile_debt_allowlist(
        job.simulation.timescale if job.simulation else None
    )
    semantic_debt = matching_lines(
        compile_result.output, DEBT_PATTERNS, compile_allowlist
    )
    compile_benign_diagnostics = matching_lines(
        compile_result.output, compile_allowlist
    )
    record.update(
        {
            "source_list": str(source_list),
            "compiler_source_list": str(compiler_source_list),
            "top_options": top_options,
            "compile_command": short_command(compile_result.command),
            "compile_returncode": compile_result.returncode,
            "compile_duration_seconds": round(compile_result.duration_seconds, 3),
            "compile_timed_out": compile_result.timed_out,
            "compile_log": str(compile_log),
            "hard_error_count": len(hard_errors),
            "hard_errors": hard_errors[: args.diagnostic_limit],
            "compile_benign_diagnostic_count": len(compile_benign_diagnostics),
            "compile_benign_diagnostics": compile_benign_diagnostics[
                : args.diagnostic_limit
            ],
            "semantic_debt_count": len(semantic_debt),
            "semantic_debt": semantic_debt[: args.diagnostic_limit],
            "output_sha256": hashlib.sha256(
                compile_result.output.encode(errors="replace")
            ).hexdigest(),
        }
    )
    if compile_result.timed_out:
        record["status"] = "COMPILE_TIMEOUT"
        return record
    if compile_result.returncode != 0 or hard_errors:
        defect = upstream_defect_for(job.core.vlnv, "compile", hard_errors)
        if defect is not None:
            record["status"] = "UPSTREAM_INVALID"
            record["upstream_defect"] = defect.note
        else:
            record["status"] = "FAIL"
        return record
    if setup_actionable_findings or semantic_debt:
        defect = (
            upstream_defect_for(job.core.vlnv, "compile", semantic_debt)
            if semantic_debt and not setup_actionable_findings
            else None
        )
        if defect is not None:
            record["status"] = "UPSTREAM_INVALID"
            record["upstream_defect"] = defect.note
        else:
            record["status"] = "DEBT"
    else:
        record["status"] = "PASS"

    if job.lane != "runtime":
        return record

    if (
        job.simulation is not None
        and job.simulation.category == "uvm"
        and not job.simulation.uvm_runtime_configured
    ):
        record.update(
            {
                "status": "RUNTIME_CONFIG_MISSING",
                "runtime_blockers": [
                    "No authoritative dvsim uvm_test/uvm_test_seq pair is "
                    "available for this UVM target"
                ],
            }
        )
        return record

    configured_arguments = (
        job.simulation.runtime_args if job.simulation is not None else ()
    )
    runtime_arguments = merge_runtime_arguments(
        configured_arguments, args.runtime_arg
    )
    otbn_smoke = (
        job.core.vlnv == "lowrisc:dv:otbn_sim:0.1"
        and job.simulation is not None
        and job.simulation.dvsim_test == "otbn_smoke"
    )
    otbn_elf_dir = work_root / "otbn-binaries"
    if otbn_smoke and not any(
        argument.startswith("+otbn_elf_dir=") for argument in runtime_arguments
    ):
        runtime_arguments.append(f"+otbn_elf_dir={otbn_elf_dir}")
    dpi_libraries = list(args.dpi_library)
    native_sources = job.simulation.native_sources if job.simulation else ()
    if otbn_smoke:
        try:
            native_sources, source_overlay = otbn_trace_finish_overlay(
                native_sources, opentitan_root, source_list, work_root
            )
        except (OSError, ValueError) as exc:
            record.update(
                {
                    "status": "SOURCE_OVERLAY_FAIL",
                    "runtime_blockers": [str(exc)],
                }
            )
            return record
        record["source_overlays"] = [source_overlay]
    native_library = work_root / "matrix-dpi.so" if native_sources else None
    skipped_sources = []
    if native_sources:
        library = native_library
        stubs = executable.with_suffix(".dpiexport.c")
        build_log = work_root / "matrix-dpi-build.log"
        build_output = []
        build_failed = False
        commands = native_dpi_commands(
            native_sources,
            job.simulation.native_include_dirs,
            iverilog,
            library,
            stubs if stubs.is_file() else None,
            cflags=native_cflags,
            libs=native_libs,
        )
        # A closure can carry native sources for other tools (Verilator's
        # ELF loader needs libelf). Build what compiles; if the testbench
        # imports a symbol from a skipped file, vvp reports "DPI error:",
        # which fails the run.
        link = commands[-1]
        for build_command in commands[:-1]:
            build_result = command_result(
                build_command, cwd=work_root, env=env, timeout=args.compile_timeout
            )
            build_output.append(
                "$ " + " ".join(build_command) + "\n" + build_result.output
            )
            if build_result.timed_out or build_result.returncode != 0:
                obj = build_command[build_command.index("-o") + 1]
                skipped_sources.append(build_command[build_command.index("-c") + 1])
                link = [part for part in link if part != obj]
        if not any(part.endswith(".o") for part in link):
            build_failed = True
        else:
            build_result = command_result(
                link, cwd=work_root, env=env, timeout=args.compile_timeout
            )
            build_output.append("$ " + " ".join(link) + "\n" + build_result.output)
            build_failed = build_result.timed_out or build_result.returncode != 0
        build_log.write_text("\n".join(build_output))
        record["dpi_build_log"] = str(build_log)
        record["dpi_skipped_sources"] = skipped_sources
        if build_failed:
            record["status"] = "DPI_BUILD_FAIL"
            record["runtime_blockers"] = [
                "native DPI sources did not build; see matrix-dpi-build.log"
            ]
            return record
        dpi_libraries.append(library)
    dpi_options = [
        option
        for library in dpi_libraries
        for option in ("-d", str(library))
    ]
    runtime_env = {**env, "IVL_SVA_NFA": "1"}
    if otbn_smoke:
        otbn_dir = opentitan_root / "hw/ip/otbn"
        binary_generator = otbn_dir / "dv/uvm/gen-binaries.py"
        smoke_dir = otbn_dir / "dv/smoke"
        generator_args = [
            str(binary_generator), "--src-dir", str(smoke_dir), str(otbn_elf_dir)
        ]
        if env.get("RV32_TOOL_AS") and env.get("RV32_TOOL_LD"):
            pre_run_command = [sys.executable, *generator_args]
        else:
            toolchain_setup = otbn_dir / "dv/uvm/get-toolchain-paths.sh"
            pre_run_command = [
                "/bin/bash", "-c",
                f"source {shlex.quote(str(toolchain_setup))} && "
                f"exec {shlex.join([sys.executable, *generator_args])}",
            ]
        pre_run = command_result(
            pre_run_command,
            cwd=opentitan_root,
            env=env,
            timeout=args.setup_timeout,
        )
        pre_run_log = work_root / "matrix-pre-run.log"
        write_log(pre_run_log, "OpenTitan DV pre-run mode", pre_run)
        record.update(
            {
                "pre_run_command": short_command(pre_run.command),
                "pre_run_returncode": pre_run.returncode,
                "pre_run_duration_seconds": round(pre_run.duration_seconds, 3),
                "pre_run_timed_out": pre_run.timed_out,
                "pre_run_log": str(pre_run_log),
            }
        )
        smoke_elf = otbn_elf_dir / "smoke_test.elf"
        if pre_run.timed_out or pre_run.returncode != 0 or not smoke_elf.is_file():
            record["status"] = (
                "PRE_RUN_TIMEOUT" if pre_run.timed_out else "PRE_RUN_FAIL"
            )
            record["runtime_blockers"] = [
                "OpenTitan's OTBN smoke pre-run mode did not produce smoke_test.elf"
            ]
            return record
        record["otbn_smoke_elf"] = str(smoke_elf)
        record["otbn_smoke_elf_sha256"] = file_sha256(smoke_elf)
        runtime_env["REPO_TOP"] = str(opentitan_root)
    runtime_command = [
        str(vvp), "-n", *dpi_options, str(executable), *runtime_arguments
    ]
    runtime_result = command_result(
        runtime_command,
        cwd=source_list.parent,
        env=runtime_env,
        timeout=args.runtime_timeout,
        memory_limit_bytes=(
            args.runtime_memory_mib * 1024 * 1024
            if args.runtime_memory_mib else None
        ),
    )
    runtime_log = work_root / "matrix-runtime.log"
    write_log(runtime_log, "OpenTitan UVM runtime", runtime_result)
    runtime_errors = matching_lines(
        runtime_result.output,
        (*HARD_ERROR_PATTERNS, *OPENTITAN_RUNTIME_FAIL_PATTERNS),
        RUNTIME_ERROR_ALLOWLIST,
    )
    runtime_pass_banner = opentitan_runtime_pass_marker(
        job.core.vlnv, runtime_result.output
    )
    if not runtime_pass_banner:
        runtime_errors.append(
            "OpenTitan runtime produced no recognized checked pass marker"
        )
    runtime_debt = matching_lines(
        runtime_result.output, DEBT_PATTERNS, RUNTIME_DEBT_ALLOWLIST
    )
    runtime_benign_diagnostics = matching_lines(
        runtime_result.output, RUNTIME_DEBT_ALLOWLIST
    )
    actionable_setup_findings, native_setup_benign = verified_native_setup_warnings(
        setup_findings,
        source_list,
        native_sources,
        skipped_sources,
        native_library,
        dpi_libraries,
        runtime_passed=(
            not runtime_result.timed_out and runtime_result.returncode == 0
            and runtime_pass_banner and not runtime_errors
        ),
    )
    record.update(
        {
            "runtime_command": short_command(runtime_command),
            "runtime_dpi_libraries": [str(path) for path in dpi_libraries],
            "runtime_returncode": runtime_result.returncode,
            "runtime_duration_seconds": round(runtime_result.duration_seconds, 3),
            "runtime_timed_out": runtime_result.timed_out,
            "runtime_memory_limit_bytes": (
                args.runtime_memory_mib * 1024 * 1024
                if args.runtime_memory_mib else None
            ),
            "runtime_memory_limit_hit": runtime_result.memory_limit_hit,
            "runtime_peak_physical_footprint_bytes": (
                runtime_result.peak_physical_footprint_bytes
            ),
            "runtime_memory_monitor_error": runtime_result.memory_monitor_error,
            "runtime_log": str(runtime_log),
            "runtime_error_count": len(runtime_errors),
            "runtime_errors": runtime_errors[: args.diagnostic_limit],
            "runtime_pass_banner": runtime_pass_banner,
            "runtime_debt_count": len(runtime_debt),
            "runtime_debt": runtime_debt[: args.diagnostic_limit],
            "setup_actionable_warnings": actionable_setup_findings,
            "setup_benign_diagnostics": native_setup_benign,
            "runtime_benign_diagnostic_count": len(runtime_benign_diagnostics),
            "runtime_benign_diagnostics": runtime_benign_diagnostics[
                : args.diagnostic_limit
            ],
        }
    )
    if runtime_result.memory_monitor_error:
        record["status"] = "RUNTIME_MEMORY_MONITOR_FAIL"
    elif runtime_result.memory_limit_hit:
        record["status"] = "RUNTIME_MEMORY_LIMIT"
    elif runtime_result.timed_out:
        record["status"] = "RUNTIME_TIMEOUT"
    elif runtime_result.returncode != 0 or runtime_errors:
        record["status"] = "RUNTIME_FAIL"
    elif actionable_setup_findings or semantic_debt or runtime_debt:
        record["status"] = "DEBT"
    else:
        record["status"] = "PASS"
    return record


def markdown_report(report: dict[str, object]) -> str:
    metadata = report["metadata"]
    results = report["results"]
    counts: dict[str, int] = {}
    for result in results:
        status = str(result["status"])
        counts[status] = counts.get(status, 0) + 1

    compiler_components = metadata.get("compiler_fingerprint", {}).get(
        "components", {}
    )
    engine = compiler_components.get("compiler_engine", {})
    lines = [
        "# OpenTitan Icarus matrix",
        "",
        f"- Generated: `{metadata['generated_at']}`",
        f"- OpenTitan revision: `{metadata['opentitan_revision']}`"
        + (" (dirty)" if metadata["opentitan_dirty"] else ""),
        f"- Icarus: `{metadata['iverilog_version']}`",
        f"- Compiler engine SHA-256: `{engine.get('sha256', 'unavailable')}`",
        f"- UVM/runtime compile profile: `{metadata['uvm_runtime_compile_profile']}`",
        f"- Jobs: `{len(results)}`",
        "- Status counts: "
        + ", ".join(f"`{key}={value}`" for key, value in sorted(counts.items())),
        "",
        "A `DEBT` result exited successfully but emitted a warning or explicit semantic "
        "degradation. It is not a conformance pass.",
        "",
        "| Lane | Core | Status | Hard errors | Semantic debt | Log |",
        "|---|---|---:|---:|---:|---|",
    ]
    for result in results:
        log_path = result.get("runtime_log") or result.get("compile_log") or result.get("setup_log")
        lines.append(
            "| {lane} | `{core}` | **{status}** | {hard} | {debt} | `{log}` |".format(
                lane=result["lane"],
                core=result["core"],
                status=result["status"],
                hard=result.get("hard_error_count", result.get("runtime_error_count", 0)),
                debt=result.get("semantic_debt_count", 0)
                + result.get("runtime_debt_count", 0),
                log=log_path,
            )
        )
    lines.append("")
    return "\n".join(lines)


def save_report(
    metadata: dict[str, object],
    results: Sequence[dict[str, object]],
    json_path: Path,
    md_path: Path,
) -> None:
    """Atomically checkpoint a report so a long census survives interruption."""
    report: dict[str, object] = {"metadata": metadata, "results": list(results)}
    json_path.parent.mkdir(parents=True, exist_ok=True)
    md_path.parent.mkdir(parents=True, exist_ok=True)
    json_temporary = json_path.with_name(json_path.name + ".tmp")
    md_temporary = md_path.with_name(md_path.name + ".tmp")
    json_temporary.write_text(json.dumps(report, indent=2) + "\n")
    md_temporary.write_text(markdown_report(report))
    json_temporary.replace(json_path)
    md_temporary.replace(md_path)


def print_inventory(
    jobs: Sequence[Job],
    simulation_targets: dict[str, SimulationTarget] | None = None,
) -> None:
    counts = {lane: 0 for lane in LANES}
    for job in jobs:
        counts[job.lane] += 1
    print("OpenTitan matrix candidate inventory")
    print(" ".join(f"{lane}={counts[lane]}" for lane in LANES))
    if simulation_targets is not None:
        category_counts = {category: 0 for category in SIMULATION_CATEGORIES}
        for target in simulation_targets.values():
            category_counts[target.category] += 1
        configured_uvm = sum(
            target.category == "uvm" and target.uvm_runtime_configured
            for target in simulation_targets.values()
        )
        print(
            "FuseSoC literal sim targets: "
            + " ".join(
                f"{category}={category_counts[category]}"
                for category in SIMULATION_CATEGORIES
            )
            + f" uvm_runtime_configured={configured_uvm}"
        )
    for job in jobs:
        category = job.simulation.category if job.simulation is not None else "-"
        print(
            f"{job.lane:7} {job.target:7} {category:11} "
            f"{job.core.vlnv}  {job.core.description}"
        )


def self_test() -> None:
    _require_python313("3.13.15")
    for version in ("3.12.11", "3.14.7"):
        try:
            _require_python313(version)
        except RuntimeError:
            pass
        else:
            raise AssertionError(
                "unsupported OpenTitan Python version was accepted"
            )
    sample = """Available cores:
lowrisc:dv:adc_ctrl_sim:0.1 : local : - : ADC UVM simulation
lowrisc:dv:adc_ctrl_sva:0.1 : local : - : ADC assertions
lowrisc:ip:adc_ctrl:1.0     : local : - : ADC RTL
"""
    parsed = []
    for line in sample.splitlines():
        match = CORE_LINE_RE.match(line)
        if match:
            parsed.append(match.group("core"))
    assert parsed == [
        "lowrisc:dv:adc_ctrl_sim:0.1",
        "lowrisc:dv:adc_ctrl_sva:0.1",
        "lowrisc:ip:adc_ctrl:1.0",
    ]
    assert core_supports_lane(Core(parsed[0], ""), "uvm")
    assert core_supports_lane(Core(parsed[1], ""), "sva")
    assert core_supports_lane(Core(parsed[2], ""), "rtl")
    uvm_target = SimulationTarget(
        parsed[0],
        "uvm",
        "vcs",
        ("tb",),
        "hw/ip/adc_ctrl/dv/adc_ctrl_sim.core",
        (
            "+UVM_NO_RELNOTES",
            "+UVM_VERBOSITY=UVM_LOW",
            "+UVM_TESTNAME=adc_ctrl_base_test",
            "+UVM_TEST_SEQ=adc_ctrl_smoke_vseq",
        ),
        "hw/ip/adc_ctrl/dv/adc_ctrl_sim_cfg.hjson",
        "adc_ctrl_smoke",
        "adc_ctrl_base_test",
        "adc_ctrl_smoke_vseq",
        timescale="1ns/1ps",
    )
    def setup_flags(job: Job) -> list[str]:
        return [
            argument
            for argument in setup_command(
                job,
                Path("fusesoc"),
                Path("opentitan"),
                Path("matrix-cores"),
                Path("build"),
                "earlgrey",
            )
            if argument.startswith("--flag=")
        ]

    assert setup_flags(Job("rtl", Core("lowrisc:ip:pinmux:0.1", ""))) == [
        "--flag=fileset_ip"
    ]
    assert setup_flags(
        Job("rtl", Core("lowrisc:systems:top_earlgrey:0.1", ""))
    ) == ["--flag=fileset_top"]
    assert setup_flags(Job("uvm", Core(uvm_target.vlnv, ""), uvm_target)) == [
        "--flag=fileset_ip"
    ]
    assert setup_flags(Job("sva", Core("lowrisc:fpv:pinmux_fpv:0.1", ""))) == [
        "--flag=fileset_ip"
    ]
    assert setup_flags(
        Job("sva", Core("lowrisc:dv:top_earlgrey_sva:0.1", ""))
    ) == ["--flag=fileset_top"]
    chip_target = dataclasses.replace(
        uvm_target, core_file="hw/top_earlgrey/dv/chip_sim.core"
    )
    assert setup_flags(Job("uvm", Core("lowrisc:dv:chip_sim:0.1", ""), chip_target)) == [
        "--flag=fileset_top"
    ]
    assert setup_flags(Job("rtl", Core("lowrisc:prim:arbiter:0", ""))) == []
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_root = Path(temp_dir)
        source_root = temp_root / "opentitan"
        source_cores = []
        for relative_core, anchor, additions in MATRIX_SOURCE_CORE_DEPENDENCIES:
            source_core = source_root / relative_core
            source_core.parent.mkdir(parents=True, exist_ok=True)
            (source_core.parent / "rtl").mkdir(exist_ok=True)
            (source_core.parent / "lint").mkdir(exist_ok=True)
            source_core.write_text(
                "CAPI=2:\nname: local:matrix:test:0.1\nfilesets:\n"
                "  files_rtl:\n    depend:\n"
                f"      - {anchor}\n"
            )
            source_cores.append((source_core, relative_core, additions))
        matrix_root = prepare_matrix_core_root(temp_root / "build", source_root)
        for source_core, relative_core, additions in source_cores:
            overlay_core = matrix_root / "source-overrides" / relative_core
            overlay_text = overlay_core.read_text()
            for dependency in additions:
                assert f"      - {dependency}\n" in overlay_text
            assert all(
                dependency not in source_core.read_text()
                for dependency in additions
            )
            assert (overlay_core.parent / "rtl").resolve() == (
                source_core.parent / "rtl"
            ).resolve()
        assert (
            "hw/ip/prim/prim_ram_1p_adv.core",
            "lowrisc:prim:ram_1p",
            ("lowrisc:prim:mubi",),
        ) in MATRIX_SOURCE_CORE_DEPENDENCIES
        overlay_command = setup_command(
            Job("rtl", Core("lowrisc:ip:lc_ctrl_pkg:0.1", "")),
            Path("fusesoc"),
            source_root,
            matrix_root,
            temp_root / "build/lc_ctrl_pkg",
            "earlgrey",
        )
        source_root_arg = f"--cores-root={source_root}"
        overlay_root_arg = f"--cores-root={matrix_root / 'source-overrides'}"
        assert overlay_command.index(overlay_root_arg) > overlay_command.index(
            source_root_arg
        )
        for lane, uses_source_overrides in (
            ("sva", True),
            ("uvm", False),
            ("runtime", False),
        ):
            lane_command = setup_command(
                Job(lane, Core("lowrisc:ip:lc_ctrl_pkg:0.1", "")),
                Path("fusesoc"),
                source_root,
                matrix_root,
                temp_root / f"build/{lane}",
                "earlgrey",
            )
            assert (overlay_root_arg in lane_command) == uses_source_overrides
        for source_core, _relative_core, additions in source_cores:
            source_core.write_text(
                source_core.read_text()
                + "".join(f"      - {dependency}\n" for dependency in additions)
            )
        prepare_matrix_core_root(temp_root / "build", source_root)
        assert all(
            not (matrix_root / "source-overrides" / relative_core).is_file()
            for _source_core, relative_core, _additions in source_cores
        )
    directed_core = Core("lowrisc:dv:prim_flop_2sync_sim:0.1", "")
    directed_target = SimulationTarget(
        directed_core.vlnv,
        "directed",
        "vcs",
        ("tb",),
        "hw/ip/prim/pre_dv/prim_flop_2sync/prim_flop_2sync_sim.core",
    )
    verilator_core = Core("lowrisc:prim:crc32_sim:0", "")
    elaboration_core = Core("lowrisc:systems:top_earlgrey_ast:0.1", "")
    simulation_targets = {
        uvm_target.vlnv: uvm_target,
        directed_target.vlnv: directed_target,
        verilator_core.vlnv: SimulationTarget(
            verilator_core.vlnv,
            "verilator",
            "verilator",
            ("sim_main",),
            "hw/ip/prim/dv/prim_crc32/crc32_sim.core",
        ),
        elaboration_core.vlnv: SimulationTarget(
            elaboration_core.vlnv,
            "elaboration",
            "vcs",
            ("top_earlgrey",),
            "hw/top_earlgrey/top_earlgrey_ast.core",
        ),
    }
    assert core_supports_lane(
        Core(parsed[0], ""), "uvm", simulation_targets=simulation_targets
    )
    assert not core_supports_lane(
        directed_core, "uvm", simulation_targets=simulation_targets
    )
    assert core_supports_lane(
        directed_core, "runtime", simulation_targets=simulation_targets
    )
    assert not core_supports_lane(
        verilator_core, "runtime", simulation_targets=simulation_targets
    )
    selection_args = argparse.Namespace(
        lane=["uvm", "runtime"], core=[], ip=[], max_cores=0
    )
    selected = select_jobs(
        [Core(parsed[0], ""), directed_core, verilator_core, elaboration_core],
        selection_args,
        simulation_targets=simulation_targets,
    )
    assert [(job.lane, job.core.vlnv) for job in selected] == [
        ("uvm", parsed[0]),
        ("runtime", parsed[0]),
        ("runtime", directed_core.vlnv),
    ]
    assert merge_runtime_arguments(
        uvm_target.runtime_args,
        ["+UVM_VERBOSITY=UVM_HIGH", "+seed=9"],
    ) == [
        "+UVM_VERBOSITY=UVM_HIGH",
        "+seed=9",
        "+UVM_NO_RELNOTES",
        "+UVM_TESTNAME=adc_ctrl_base_test",
        "+UVM_TEST_SEQ=adc_ctrl_smoke_vseq",
    ]
    with tempfile.TemporaryDirectory() as directory:
        test_root = Path(directory)
        generated = test_root / "generated.scr"
        generated.write_text("test.sv\n")
        wrapper = simulation_source_list(
            Job("uvm", Core(parsed[0], ""), uvm_target), generated, test_root
        )
        assert wrapper != generated
        assert wrapper.read_text() == f"+timescale+1ns/1ps\n-c {generated}\n"
    uvm_runtime_compile = compile_command(
        Job("runtime", Core(parsed[0], ""), uvm_target),
        Path("iverilog"),
        Path("uvm.scr"),
        [],
        Path("uvm.vvp"),
    )
    assert "-uvm" in uvm_runtime_compile
    assert "-DUVM" in uvm_runtime_compile
    assert "-DUVM_REGEX_NO_DPI" not in uvm_runtime_compile
    assert "--uvm-no-dpi" not in uvm_runtime_compile
    assert "-DSRAM_TYPE=spi_device_pkg::SramType1r1w" not in uvm_runtime_compile
    assert "-gcommercial-unsafe" not in uvm_runtime_compile
    assert parser().parse_args(["--commercial-unsafe"]).commercial_unsafe
    for lane in ("uvm", "runtime"):
        assert "-gcommercial-unsafe" in compile_command(
            Job(lane, Core(parsed[0], ""), uvm_target),
            Path("iverilog"), Path("uvm.scr"), [], Path("uvm.vvp"),
            commercial_unsafe=True,
        )
    for lane in ("rtl", "sva"):
        assert "-gcommercial-unsafe" not in compile_command(
            Job(lane, Core(parsed[0], ""), uvm_target),
            Path("iverilog"), Path("uvm.scr"), [], Path("uvm.vvp"),
            commercial_unsafe=True,
        )
    assert memload_synthesis_profile(
        "lowrisc:systems:top_earlgrey:0.1", ["-stop_earlgrey"]
    ) == "top_earlgrey"
    assert memload_synthesis_profile(
        "lowrisc:systems:chip_earlgrey_asic:0.1", ["-schip_earlgrey_asic"]
    ) == "chip_earlgrey_asic"
    assert memload_synthesis_profile(
        "lowrisc:systems:chip_earlgrey_verilator:0.1",
        ["-schip_earlgrey_verilator"],
    ) == "chip_earlgrey_verilator"
    assert memload_synthesis_profile(
        "lowrisc:systems:chip_earlgrey_cw310:0.1", ["-schip_earlgrey_cw310"]
    ) is None
    assert memload_synthesis_profile(
        "lowrisc:systems:top_earlgrey:0.1",
        ["-stop_earlgrey", "-Ptop_earlgrey.RomCtrlBootRomInitFile=rom.vmem"],
    ) is None
    memload_sample = (
        "initial begin\n"
        + MEMLOAD_DEBUG_BLOCK
        + '\n  if (MemInitFile != "") begin\n'
        + "    $readmemh(MemInitFile, mem);\n  end\nend\n"
    )
    assert memload_synthesis_profile(
        "lowrisc:ip:rom_ctrl:0.1", ["-srom_ctrl"]
    ) == "rom_ctrl"
    assert empty_string_parameter(
        'parameter BootRomInitFile = "";', "BootRomInitFile"
    )
    assert not empty_string_parameter(
        'parameter BootRomInitFile = "boot.vmem";', "BootRomInitFile"
    )
    assert top_earlgrey_uses_default_mem_images(
        "top_earlgrey #(.ResetDelay(1)) top_earlgrey ("
    )
    assert not top_earlgrey_uses_default_mem_images(
        'top_earlgrey #(.RomCtrlBootRomInitFile("boot.vmem")) top_earlgrey ('
    )
    verilator_wrapper_sample = "\n".join(
        (
            "  logic hi_speed_sel;",
            "  logic scan_en;",
            "  logic jen;",
            "    .all_clk_byp_req_i     ( ast_clk_byp_req ),",
            "    .all_clk_byp_ack_o     ( ast_clk_byp_ack ),",
        )
    )
    verilator_wrapper_overlay = chip_earlgrey_verilator_source_text(
        verilator_wrapper_sample
    )
    assert "prim_mubi_pkg::mubi4_t hi_speed_sel;" in verilator_wrapper_overlay
    assert "prim_mubi_pkg::mubi4_t scanmode;" in verilator_wrapper_overlay
    assert "prim_mubi_pkg::mubi4_t jen;" in verilator_wrapper_overlay
    assert ".all_clk_byp_req_i     ( all_clk_byp_req )," in verilator_wrapper_overlay
    assert ".all_clk_byp_ack_o     ( all_clk_byp_ack )," in verilator_wrapper_overlay
    ibex_tracer_sample = "\n".join(
        (
            "      int fh = file_handle;",
            "      int fh = file_handle;",
            '        string file_name_base = "trace_core";',
        )
    )
    ibex_tracer_overlay = ibex_tracer_automatic_locals(ibex_tracer_sample)
    assert ibex_tracer_overlay.count("automatic int fh = file_handle;") == 2
    assert 'automatic string file_name_base = "trace_core";' in ibex_tracer_overlay
    i2c_coverage_sample = (
        "    if (en_cov) begin\n"
        "      i2c_protocol_cov_cg   i2c_protocol_cov = new();\n"
        "      i2c_rd_wr_cg          i2c_rd_wr_cov = new();\n"
        "      i2c_cmd_complete_cg   cmd_complete_cg = new();"
    )
    i2c_coverage_overlay = i2c_protocol_cov_source_text(i2c_coverage_sample)
    assert i2c_coverage_overlay.startswith(
        "    i2c_protocol_cov_cg   i2c_protocol_cov;\n"
        "    i2c_rd_wr_cg          i2c_rd_wr_cov;\n"
        "    i2c_cmd_complete_cg   cmd_complete_cg;\n"
        "    if (en_cov) begin\n"
    )
    assert "      i2c_protocol_cov = new();" in i2c_coverage_overlay
    assert i2c_if_source_text(
        "if (sample.size() > tc.tSetupBit) sample.pop_back();"
    ) == "if (sample.size() > tc.tSetupBit) void'(sample.pop_back());"
    assert i2c_host_perf_vseq_source_text(
        "constraint c {\n    solve cfg.clk_freq_mhz before speed_mode;\n}"
    ) == "constraint c {\n}"
    keccak_2share_sample = (
        ");\n\n  localparam int W\n"
        "          keccak_st_d = StPhase1;\n"
        "      end\n"
        "      StPhase2Cycle1: begin"
    )
    assert keccak_2share_fpv_syntax_source_text(keccak_2share_sample) == (
        ");\n  import prim_mubi_pkg::*;\n\n  localparam int W\n"
        "          keccak_st_d = StPhase1;\n"
        "        end\n"
        "      end\n"
        "      StPhase2Cycle1: begin"
    )
    keccak_round_sample = (
        "  logic run, clear, masked_complete, unmasked_complete;\n"
        "    clear = 1'b 0;\n"
        "        clear = 1'b1;\n"
    )
    assert keccak_round_fpv_source_text(keccak_round_sample) == (
        "  logic run, masked_complete, unmasked_complete;\n"
        "  prim_mubi_pkg::mubi4_t clear;\n"
        "    clear = prim_mubi_pkg::MuBi4False;\n"
        "        clear = prim_mubi_pkg::MuBi4True;\n"
    )
    spi_host_core_sample = (
        "  formal:\n"
        "    <<: *default_target\n"
        "    filesets:\n"
        "      - files_formal\n"
        "      - files_dv\n"
        "    toplevel: spi_host\n"
    )
    assert spi_host_sva_core_source_text(spi_host_core_sample) == (
        "  formal:\n"
        "    <<: *default_target\n"
        "    filesets:\n"
        "      - files_dv\n"
        "    toplevel: spi_host\n"
    )
    guarded_memload = guard_memload_debug(memload_sample)
    assert "`ifndef SYNTHESIS" in guarded_memload
    assert guarded_memload.index("`endif") < guarded_memload.index(
        'if (MemInitFile != "")'
    )
    assert "$readmemh(MemInitFile, mem);" in guarded_memload
    rom_ctrl_compile = compile_command(
        Job("rtl", Core("lowrisc:ip:rom_ctrl:0.1", "")),
        Path("iverilog"), Path("rom_ctrl.scr"), ["-srom_ctrl"],
        Path("rom_ctrl.vvp"), additional_include_dirs=(Path("/work/rom-overlay"),),
    )
    assert "-I/work/rom-overlay" in rom_ctrl_compile
    assert rom_ctrl_compile.index("-I/work/rom-overlay") < rom_ctrl_compile.index("-c")
    assert dvsim_define_arguments(
        (
            "+define+EN_MASKING=1",
            "+define+A=1+B",
            "+define+UVM",
            "+define+BUILD_SEED={seed}",
            "-CFLAGS -O2",
            "+define+EN_MASKING=0",
        )
    ) == ["-DEN_MASKING=1", "-DA=1", "-DB"]
    nba_warning = ("x.sv:9: warning: A non-blocking assignment should not be "
                   "used in an always_comb process.")
    assert matching_lines(nba_warning, DEBT_PATTERNS, COMPILE_DEBT_ALLOWLIST) == []
    assert matching_lines("x.sv:3: warning: input port rst_n is coerced to inout.",
                          DEBT_PATTERNS, COMPILE_DEBT_ALLOWLIST) == []
    assert matching_lines("x.sv:5: warning: User function 'f' is being called as a task.",
                          DEBT_PATTERNS, COMPILE_DEBT_ALLOWLIST) == []
    assert matching_lines("x.sv:6: warning: A do/while statement cannot be "
                          "synthesized in an always_comb process.",
                          DEBT_PATTERNS, COMPILE_DEBT_ALLOWLIST) == []
    assert matching_lines("x.sv:7: warning: user task (t) must be automatic to "
                          "be synthesized in an always_comb process.",
                          DEBT_PATTERNS, COMPILE_DEBT_ALLOWLIST) == []
    assert matching_lines("x.sv:4: warning: something degraded.",
                          DEBT_PATTERNS, COMPILE_DEBT_ALLOWLIST) != []
    mixed_timescale_warning = (
        "warning: Found both default and explicit timescale based delays. Use\n"
        "       : -Wtimescale to find the design element(s) with no explicit\n"
        "       : timescale.\n"
    )
    assert matching_lines(
        mixed_timescale_warning, DEBT_PATTERNS,
        compile_debt_allowlist("1ns/1ps"),
    ) == []
    assert matching_lines(
        mixed_timescale_warning, DEBT_PATTERNS,
        compile_debt_allowlist(None),
    ) == ["warning: Found both default and explicit timescale based delays. Use"]
    dpi_build = native_dpi_commands(
        ("/src/a.cc", "/src/b.c"),
        ("/src",),
        Path("/opt/ivl/bin/iverilog"),
        Path("/work/matrix-dpi.so"),
        Path("/work/matrix-runtime.dpiexport.c"),
        platform="darwin",
    )
    assert dpi_build[0][:2] == ["c++", "-std=c++17"]
    assert dpi_build[1][0] == "cc" and dpi_build[2][0] == "cc"
    assert "-I/opt/ivl/include/iverilog" in dpi_build[0]
    assert dpi_build[-1][:4] == ["c++", "-shared", "-undefined", "dynamic_lookup"]
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        pkg_config = root / "pkg-config"
        pkg_config.write_text(
            "#!/bin/sh\ncase \"$1\" in\n"
            "  --cflags) printf '%s\\n' '-I/pkg/include -DOPENSSL_TEST=1';;\n"
            "  --libs) printf '%s\\n' '-L/pkg/lib -lssl -lcrypto';;\n"
            "esac\n"
        )
        pkg_config.chmod(0o755)
        cflags, libs, provenance = native_pkg_config_flags(
            ("openssl",), {"PATH": str(root)}, root, 5
        )
        assert cflags == ["-I/pkg/include", "-DOPENSSL_TEST=1"]
        assert libs == ["-L/pkg/lib", "-lssl", "-lcrypto"]
        assert provenance["executable_sha256"] == file_sha256(pkg_config)
        enabled_build = native_dpi_commands(
            ("/src/crypto.c",), (), Path("/opt/ivl/bin/iverilog"),
            Path("/work/matrix-dpi.so"), None, cflags=cflags, libs=libs,
        )
        assert enabled_build[0][4:6] == cflags
        assert enabled_build[-1][-3:] == libs
        assert all(flag not in dpi_build[0] for flag in cflags)
        assert all(flag not in dpi_build[-1] for flag in libs)
        try:
            native_pkg_config_flags(("openssl",), {"PATH": str(root / "missing")}, root, 5)
        except RuntimeError as exc:
            assert "requires pkg-config" in str(exc)
        else:
            raise AssertionError("missing pkg-config was accepted")
        pkg_config.write_text("#!/bin/sh\necho 'missing package' >&2\nexit 1\n")
        try:
            native_pkg_config_flags(("openssl",), {"PATH": str(root)}, root, 5)
        except RuntimeError as exc:
            assert "missing package" in str(exc)
        else:
            raise AssertionError("missing native package was accepted")
    regex_uvm_target = dataclasses.replace(
        uvm_target,
        build_options=(
            *uvm_target.build_options,
            UVM_REGEX_NO_DPI_BUILD_OPTION,
        ),
    )
    for lane in ("uvm", "runtime"):
        regex_uvm_compile = compile_command(
            Job(lane, Core(parsed[0], ""), regex_uvm_target),
            Path("iverilog"),
            Path("regex-uvm.scr"),
            [],
            Path("regex-uvm.vvp"),
        )
        assert "-uvm" in regex_uvm_compile
        assert "-DUVM_REGEX_NO_DPI" in regex_uvm_compile
        assert "--uvm-no-dpi" not in regex_uvm_compile
    regex_rtl_compile = compile_command(
        Job("rtl", Core(parsed[0], ""), regex_uvm_target),
        Path("iverilog"),
        Path("regex-rtl.scr"),
        [],
        Path("regex-rtl.vvp"),
    )
    assert "-DUVM_REGEX_NO_DPI" not in regex_rtl_compile
    regex_sva_compile = compile_command(
        Job("sva", Core(parsed[0], ""), regex_uvm_target),
        Path("iverilog"),
        Path("regex-sva.scr"),
        [],
        Path("regex-sva.vvp"),
    )
    assert "-DUVM_REGEX_NO_DPI" not in regex_sva_compile
    spi_device_core = Core("lowrisc:dv:spi_device_sim:0.1", "")
    for lane in ("uvm", "runtime"):
        spi_device_compile = compile_command(
            Job(lane, spi_device_core, uvm_target),
            Path("iverilog"),
            Path("spi-device.scr"),
            [],
            Path("spi-device.vvp"),
        )
        assert "-DSRAM_TYPE=spi_device_pkg::SramType1r1w" in spi_device_compile
    spi_device_rtl_compile = compile_command(
        Job("rtl", spi_device_core),
        Path("iverilog"),
        Path("spi-device-rtl.scr"),
        [],
        Path("spi-device-rtl.vvp"),
    )
    assert "-DSRAM_TYPE=spi_device_pkg::SramType1r1w" not in spi_device_rtl_compile
    assert "-DSYNTHESIS_MEMORY_BLACK_BOXING" in spi_device_rtl_compile
    assert "-DSYNTHESIS_MEMORY_BLACK_BOXING" not in spi_device_compile
    directed_runtime_compile = compile_command(
        Job("runtime", directed_core, directed_target),
        Path("iverilog"),
        Path("directed.scr"),
        [],
        Path("directed.vvp"),
    )
    assert "-uvm" not in directed_runtime_compile
    assert not any(option.startswith("-DUVM") for option in directed_runtime_compile)
    assert "-DSIMULATION" in directed_runtime_compile
    assert "-gcommercial-unsafe" in compile_command(
        Job("runtime", directed_core, directed_target),
        Path("iverilog"), Path("directed.scr"), [], Path("directed.vvp"),
        commercial_unsafe=True,
    )
    directed_with_uvm_import = dataclasses.replace(
        directed_target, requires_uvm_library=True
    )
    directed_uvm_library_compile = compile_command(
        Job("runtime", directed_core, directed_with_uvm_import),
        Path("iverilog"),
        Path("directed-uvm-import.scr"),
        [],
        Path("directed-uvm-import.vvp"),
    )
    assert "-uvm" in directed_uvm_library_compile
    assert "-DUVM" in directed_uvm_library_compile
    assert not core_supports_lane(
        Core("lowrisc:ip:otbn_top_sim:0.1", "Verilator simulation"), "rtl"
    )
    assert not core_supports_lane(
        Core("lowrisc:prim:crc32_sim:0", "Verilator simulation"), "rtl"
    )
    assert not core_supports_lane(
        Core("lowrisc:ibex:ibex_top_tracing:0.1", "Tracing simulation"), "rtl"
    )
    fpv = Core("lowrisc:darjeeling_ip:rv_plic_fpv:0.1", "")
    assert core_supports_lane(fpv, "sva")
    assert not core_supports_lane(fpv, "rtl")
    fpv_compile = compile_command(
        Job("sva", fpv), Path("iverilog"), Path("fpv.scr"), [], Path("fpv.vvp")
    )
    assert "-gassertions" in fpv_compile
    assert "-DFPV_ON" in fpv_compile
    assert "-DASSERT_ON" not in fpv_compile
    assert "-uvm" not in fpv_compile
    sva_compile = compile_command(
        Job("sva", Core(parsed[1], "")),
        Path("iverilog"),
        Path("sva.scr"),
        [],
        Path("sva.vvp"),
    )
    assert "-uvm" in sva_compile
    assert "--uvm-no-dpi" in sva_compile
    pure_sva = Core("lowrisc:dv:aes_sva:0.1", "")
    pure_sva_compile = compile_command(
        Job("sva", pure_sva),
        Path("iverilog"),
        Path("aes-sva.scr"),
        [],
        Path("aes-sva.vvp"),
    )
    assert "-uvm" not in pure_sva_compile

    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        selected = root / "legacy UVM" / "src"
        selected.mkdir(parents=True)
        (selected / "uvm_pkg.sv").write_text("package uvm_pkg; endpackage\n")
        driver = root / "bin" / "iverilog"
        bundled = root / "lib" / "ivl" / "uvm" / "src"
        bundled.mkdir(parents=True)
        (bundled / "uvm_pkg.sv").write_text("bundled sentinel\n")
        before = compiler_fingerprint(driver, root / "bin" / "vvp", selected)
        assert before["uvm_sources"]["path"] == str(selected)
        assert before["uvm_sources"]["sha256"] == directory_sha256(selected)
        (selected / "uvm_pkg.sv").write_text("changed legacy source\n")
        after = compiler_fingerprint(driver, root / "bin" / "vvp", selected)
        assert before["uvm_sources"]["sha256"] != after["uvm_sources"]["sha256"]
        assert compiler_fingerprint(driver, root / "bin" / "vvp")[
            "uvm_sources"
        ]["path"] == str(bundled)
        for job, uses_uvm in (
            (Job("runtime", Core(parsed[0], ""), uvm_target), True),
            (Job("uvm", Core(parsed[0], ""), uvm_target), True),
            (Job("runtime", directed_core, directed_target), False),
            (Job("runtime", directed_core, directed_with_uvm_import), True),
            (Job("sva", Core(parsed[1], "")), True),
            (Job("sva", pure_sva), False),
            (Job("rtl", directed_core), False),
        ):
            command = compile_command(
                job, driver, root / "in.scr", [], root / "out.vvp", selected
            )
            assert (f"--uvm-home={selected}" in command) == uses_uvm
            assert ("--uvm-no-dpi" in command) == (
                job.lane == "sva" and uses_uvm
            )
    formal_targets = {"lowrisc:ip:keymgr:0.1", fpv.vlnv}
    assert core_supports_lane(
        Core("lowrisc:ip:keymgr:0.1", ""), "sva", formal_targets
    )
    assert not core_supports_lane(pure_sva, "sva", formal_targets)
    prim_keccak = Job(
        "sva", Core("lowrisc:fpv:prim_keccak_fpv:0.1", "")
    )
    assert prim_keccak.target == "default"
    englishbreakfast = Job(
        "rtl", Core("lowrisc:englishbreakfast_ip:flash_ctrl:0.1", "")
    )
    assert top_for_job(englishbreakfast, "auto") == "englishbreakfast"
    assert provider_mappings(englishbreakfast, "auto") == [
        PRIM_MAPPING,
        ENGLISHBREAKFAST_MAPPING,
    ]
    assert matching_lines("x: warning: compile-progress fallback", DEBT_PATTERNS)
    zero_scoreboard_drops = (
        "UVM_INFO @ 0 ps: Seeds assumed dropped from entropy_data: 0\n"
        "UVM_INFO @ 0 ps: Words assumed dropped from observe fifo: 0\n"
    )
    positive_scoreboard_drops = (
        "UVM_INFO @ 0 ps: Seeds assumed dropped from entropy_data: 1\n"
    )
    assert matching_lines(
        zero_scoreboard_drops, DEBT_PATTERNS, RUNTIME_DEBT_ALLOWLIST
    ) == []
    assert matching_lines(
        positive_scoreboard_drops, DEBT_PATTERNS, RUNTIME_DEBT_ALLOWLIST
    ) == [positive_scoreboard_drops.splitlines()[0]]
    discarded_system_result = (
        "x.sv:3: Warning: Calling system function $system() as a task.\n"
        "x.sv:3:          The functions return value will be ignored.\n"
    )
    assert not matching_lines(
        discarded_system_result, DEBT_PATTERNS, RUNTIME_DEBT_ALLOWLIST
    )
    assert len(matching_lines(discarded_system_result, RUNTIME_DEBT_ALLOWLIST)) == 2
    assert matching_lines("foo.sv:4: syntax error", HARD_ERROR_PATTERNS)
    assert matching_lines("ivl: synth2.cc:1: failed assertion x", HARD_ERROR_PATTERNS)
    assert matching_lines("Abort trap: 6", HARD_ERROR_PATTERNS)
    runtime_failure_patterns = (*HARD_ERROR_PATTERNS, *OPENTITAN_RUNTIME_FAIL_PATTERNS)
    assert not matching_lines(
        "----| has Configuration error:  FALSE", runtime_failure_patterns,
        RUNTIME_ERROR_ALLOWLIST,
    )
    assert matching_lines(
        "----| has Configuration error:  TRUE", runtime_failure_patterns,
        RUNTIME_ERROR_ALLOWLIST,
    )
    assert matching_lines(
        "UVM_ERROR @ 0 ps: real failure", runtime_failure_patterns,
        RUNTIME_ERROR_ALLOWLIST,
    )
    assert OPENTITAN_RUNTIME_PASS_RE.search("TEST PASSED CHECKS\n")
    assert OPENTITAN_RUNTIME_PASS_RE.search("TEST PASSED UVM_CHECKS\n")
    assert not OPENTITAN_RUNTIME_PASS_RE.search("UVM_INFO test ended\n")
    jedec_core = "lowrisc:dv:spid_jedec_sim:0.1"
    jedec_pass = "SPI Flash Read JEDEC ID Tested!!:\n"
    assert opentitan_runtime_pass_marker(jedec_core, jedec_pass)
    assert not opentitan_runtime_pass_marker("lowrisc:dv:spid_upload_sim:0.1", jedec_pass)
    upload_core = "lowrisc:dv:spid_upload_sim:0.1"
    upload_pass = "All payloads are read out.\n"
    assert opentitan_runtime_pass_marker(upload_core, upload_pass)
    assert not opentitan_runtime_pass_marker("lowrisc:dv:spid_status_sim:0.1", upload_pass)
    assert not opentitan_runtime_pass_marker(upload_core, "All payloads are still being read out.\n")
    assert not opentitan_runtime_pass_marker(
        jedec_core, "Jedec ID Received: Manufacturer ID [be], JEDEC_ID [a55a]\n"
    )
    tpm_core = "lowrisc:dv:spi_tpm_sim:0.1"
    tpm_pass = "Host transactions has ended.\nTEST PASSED!\n"
    assert opentitan_runtime_pass_marker(tpm_core, tpm_pass)
    assert not opentitan_runtime_pass_marker(tpm_core, "TEST PASSED!\n")
    assert not opentitan_runtime_pass_marker(
        "lowrisc:dv:spi_device_sim:0.1", tpm_pass
    )
    assert not opentitan_runtime_pass_marker(
        tpm_core, tpm_pass + "TEST TIMED OUT!!\n"
    )
    assert matching_lines("TEST TIMED OUT!!", OPENTITAN_RUNTIME_FAIL_PATTERNS)
    assert matching_lines(
        "FATAL: spid_jedec_tb.sv:93: TEST TIMED OUT!!",
        OPENTITAN_RUNTIME_FAIL_PATTERNS,
    )
    assert matching_lines(
        "UVM_FATAL @ 0: reporter [NOCOMP] No components instantiated",
        OPENTITAN_RUNTIME_FAIL_PATTERNS,
    )
    assert not matching_lines(
        "UVM_FATAL :    0", OPENTITAN_RUNTIME_FAIL_PATTERNS
    )
    assert matching_lines(
        "TEST FAILED UVM_CHECKS", OPENTITAN_RUNTIME_FAIL_PATTERNS
    )
    assert NO_TOPLEVEL_RE.search("ERROR: x:y:z:0 : Target 'default' has no toplevel")
    with tempfile.TemporaryDirectory() as tmp:
        for toplevel in ("tb", "-stb"):
            work = Path(tmp) / toplevel.lstrip("-")
            work.mkdir()
            (work / "Makefile").write_text(
                f"TARGET := core\nTOPLEVEL := {toplevel}\n")
            (work / "core.scr").write_text("")
            assert parse_makefile(work)[1] == ["-stb"], toplevel
    assert MODULE_DECL_RE.findall("module foo;\nendmodule\n  module bar #(p) (x);\n") == [
        "foo",
        "bar",
    ]
    assert upstream_defect_for(
        "lowrisc:ip:ascon:0.1",
        "compile",
        ["x.sv:1: error: This assignment requires an explicit cast."],
    )
    assert (
        upstream_defect_for(
            "lowrisc:ip:ascon:0.1",
            "compile",
            [
                "x.sv:1: error: This assignment requires an explicit cast.",
                "x.sv:9: error: some new unrelated failure",
            ],
        )
        is None
    )
    assert upstream_defect_for("lowrisc:ip:ascon:0.1", "setup", ["anything"]) is None
    assert not actionable_setup_lines(
        "WARNING: No trustfile configured (ssh-trustfile in fusesoc.conf), "
        "signatures will not be checked."
    )
    assert not actionable_setup_lines(
        "INFO: Wrote dependency graph to /tmp/opentitan-warning-build/core.dot"
    )
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        source_list = root / "build" / "core.scr"
        source_list.parent.mkdir()
        unused = root / "src" / "unused.c"
        listed = root / "src" / "listed.cc"
        requirements = root / "src" / "tool_requirements.py"
        unused.parent.mkdir()
        unused.write_text("int unused;\n")
        listed.write_text("int listed;\n")
        requirements.write_text("pass\n")
        source_list.write_text("../src/listed.cc\n")
        warnings = [
            "WARNING: ../src/unused.c has unknown file type 'cSource'",
            "WARNING: ../src/listed.cc has unknown file type 'cppSource'",
            "WARNING: waiver has unknown file type ''",
            "WARNING: ../src/tool_requirements.py has unknown file type ''",
        ]
        assert classify_compile_setup_warnings("rtl", warnings, source_list) == (
            warnings[1:3], [warnings[0], warnings[3]]
        )
        source_list.write_text("../src/listed.cc\n../src/tool_requirements.py\n")
        assert classify_compile_setup_warnings("rtl", warnings, source_list) == (
            [warnings[1], warnings[2], warnings[3]], [warnings[0]]
        )
        assert classify_compile_setup_warnings(
            "uvm", warnings, source_list
        ) == (warnings[1:], warnings[:1])
        assert classify_compile_setup_warnings(
            "sva", warnings, source_list
        ) == (warnings[1:], warnings[:1])
        assert classify_compile_setup_warnings(
            "runtime", warnings, source_list
        ) == (warnings, [])
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        staged = root / "src" / "native_core" / "util.c"
        staged.parent.mkdir(parents=True)
        staged.write_text("int native_value(void) { return 1; }\n")
        native = root / "native" / "util.c"
        native.parent.mkdir()
        native.write_bytes(staged.read_bytes())
        library = root / "matrix-dpi.so"
        library.write_bytes(b"linked")
        source_list = root / "sim-icarus" / "core.scr"
        source_list.parent.mkdir()
        warning = "WARNING: ../src/native_core/util.c has unknown file type 'cSource'"
        findings = [warning]
        args = (findings, source_list, (str(native),), (), library, (library,))
        assert verified_native_setup_warnings(*args, runtime_passed=True) == (
            [], findings
        )
        assert findings == [warning]  # Keep the original setup record intact.
        assert verified_native_setup_warnings(
            findings, source_list, (str(native),), (str(native),),
            library, (library,), runtime_passed=True,
        ) == (findings, [])  # SRAM-like skipped source stays debt.
        assert verified_native_setup_warnings(
            *args, runtime_passed=False
        ) == (findings, [])
        staged.write_text("int native_value(void) { return 2; }\n")
        assert verified_native_setup_warnings(
            *args, runtime_passed=True
        ) == (findings, [])  # Same basename without same contents is insufficient.
    if os.name == "posix":
        with tempfile.TemporaryDirectory() as directory:
            test_root = Path(directory)
            fusesoc = test_root / "fusesoc"
            current_python = Path(sys.executable).absolute()
            fusesoc.write_text(f"#!{current_python}\n")
            fusesoc.chmod(0o755)
            assert resolve_fusesoc_python(
                fusesoc, None, os.environ.copy()
            ) == (str(current_python),)

            adjacent = test_root / "python"
            adjacent.symlink_to(current_python)
            assert resolve_fusesoc_python(
                fusesoc, None, os.environ.copy()
            ) == (str(adjacent),)
            adjacent.unlink()

            env_python = test_root / "python3.99"
            env_python.symlink_to(current_python)
            fusesoc.write_text("#!/usr/bin/env python3.99\n")
            probe_env = {**os.environ, "PATH": str(test_root)}
            assert resolve_fusesoc_python(
                fusesoc, None, probe_env
            ) == (str(env_python),)

            fusesoc.write_text("#!/bin/sh\nexit 0\n")
            try:
                resolve_fusesoc_python(fusesoc, None, probe_env)
            except RuntimeError as exc:
                assert "--fusesoc-python" in str(exc)
            else:
                raise AssertionError("non-Python FuseSoC shebang was accepted")

            fusesoc.write_text(f"#!{current_python} -c rejected_option_payload\n")
            try:
                resolve_fusesoc_python(fusesoc, None, probe_env)
            except RuntimeError as exc:
                assert "--fusesoc-python" in str(exc)
            else:
                raise AssertionError("executable Python shebang option was accepted")
    if os.name == "posix":
        timeout_probe = command_result(
            [
                sys.executable,
                "-c",
                (
                    "import subprocess,sys,time; "
                    "p=subprocess.Popen([sys.executable,'-c',"
                    "'import time; time.sleep(30)']); "
                    "print(p.pid,flush=True); time.sleep(30)"
                ),
            ],
            cwd=Path.cwd(),
            env=os.environ.copy(),
            timeout=1,
        )
        assert timeout_probe.timed_out
        descendant_pid = int(timeout_probe.output.strip().splitlines()[0])
        try:
            os.kill(descendant_pid, 0)
        except ProcessLookupError:
            pass
        else:
            raise AssertionError("timed-out command left a descendant running")
    if sys.platform == "darwin":
        from unittest import mock

        signal_probe = subprocess.Popen(
            [sys.executable, "-c", "import time; time.sleep(30)"],
            start_new_session=True,
        )
        try:
            with mock.patch.object(os, "killpg", side_effect=PermissionError("injected")):
                signal_command_tree(signal_probe, signal.SIGTERM)
            assert signal_probe.wait(timeout=5) != 0
        finally:
            if signal_probe.poll() is None:
                signal_probe.kill()
                signal_probe.wait()

        memory_probe = command_result(
            [
                sys.executable,
                "-c",
                (
                    "import subprocess,sys,time; "
                    "p=subprocess.Popen([sys.executable,'-c',"
                    "'import signal,time; signal.signal(signal.SIGTERM,signal.SIG_IGN); "
                    "print(1,flush=True); time.sleep(30)'],"
                    "stdout=subprocess.PIPE,text=True); p.stdout.readline(); "
                    "print(p.pid,flush=True); "
                    "data=bytearray(128*1024*1024); time.sleep(30)"
                ),
            ],
            cwd=Path.cwd(), env=os.environ.copy(), timeout=15,
            memory_limit_bytes=64 * 1024 * 1024,
        )
        assert memory_probe.memory_limit_hit, memory_probe
        assert not memory_probe.timed_out
        assert memory_probe.returncode == 125
        assert memory_probe.peak_physical_footprint_bytes > 64 * 1024 * 1024
        descendant_pid = int(memory_probe.output.strip().splitlines()[0])
        for _ in range(50):
            try:
                os.kill(descendant_pid, 0)
            except ProcessLookupError:
                break
            time.sleep(0.1)
        else:
            raise AssertionError("memory-limited command left a descendant running")
        sampled_pid = []

        def fail_footprint(command: Sequence[str], **_kwargs: object) -> None:
            sampled_pid.append(int(command[-1]))
            raise OSError("injected footprint launch error")

        with mock.patch.object(subprocess, "run", side_effect=fail_footprint):
            monitor_probe = command_result(
                [sys.executable, "-c", "import time; time.sleep(30)"],
                cwd=Path.cwd(), env=os.environ.copy(), timeout=15,
                memory_limit_bytes=64 * 1024 * 1024,
            )
        assert monitor_probe.returncode == 126
        assert "injected footprint launch error" in monitor_probe.memory_monitor_error
        try:
            os.kill(sampled_pid[0], 0)
        except ProcessLookupError:
            pass
        else:
            raise AssertionError("monitor failure left a runtime process running")
    print("opentitan_matrix self-test: PASS")


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--opentitan-root", type=Path)
    result.add_argument("--build-root", type=Path)
    result.add_argument("--iverilog", type=Path)
    result.add_argument(
        "--uvm-home", type=Path,
        help="Acquired UVM root or src directory; use pinned1.2 for OpenTitan. "
             "Defaults to IVERILOG_UVM_HOME or the compiler-bundled library.",
    )
    result.add_argument("--fusesoc", type=Path)
    result.add_argument(
        "--fusesoc-python",
        type=Path,
        help=(
            "Python interpreter that imports the same FuseSoC package and "
            "OpenTitan dependencies; defaults to an adjacent interpreter or "
            "a conventional Python shebang from --fusesoc"
        ),
    )
    result.add_argument(
        "--lane",
        action="append",
        choices=("all", *LANES),
        default=[],
        help="repeat to select lanes; the default 'all' includes runtime",
    )
    result.add_argument("--core", action="append", default=[], help="exact VLNV")
    result.add_argument("--ip", action="append", default=[], help="name/description substring")
    result.add_argument("--top", choices=("auto", *TOP_VARIANTS), default="auto")
    result.add_argument("--max-cores", type=int, default=0)
    result.add_argument(
        "--jobs",
        type=int,
        default=1,
        help="number of independent cores to process concurrently",
    )
    result.add_argument("--list", action="store_true")
    result.add_argument("--setup-only", action="store_true")
    result.add_argument("--setup-timeout", type=int, default=600)
    result.add_argument("--compile-timeout", type=int, default=600)
    result.add_argument("--runtime-timeout", type=int, default=300)
    result.add_argument(
        "--runtime-memory-mib", type=int, default=0,
        help="per-vvp macOS physical-footprint cap in MiB (0 disables)",
    )
    result.add_argument("--runtime-arg", action="append", default=[])
    result.add_argument(
        "--commercial-unsafe", action="store_true",
        help="use -gcommercial-unsafe for UVM and runtime compiles",
    )
    result.add_argument(
        "--dpi-library",
        action="append",
        type=Path,
        default=[],
        help="repeat to load a native DPI shared library with vvp -d",
    )
    result.add_argument(
        "--native-pkg-config", action="append", default=[], metavar="PACKAGE",
        help="repeat to apply pkg-config C flags and link libraries to native DPI builds",
    )
    result.add_argument("--diagnostic-limit", type=int, default=100)
    result.add_argument("--result-json", type=Path)
    result.add_argument("--result-md", type=Path)
    result.add_argument("--self-test", action="store_true")
    return result


def resolve_executable(
    value: Path | None, fallback: str, *, preserve_symlink: bool = False
) -> Path:
    candidate = str(value) if value else shutil.which(fallback)
    if not candidate:
        raise FileNotFoundError(f"could not find {fallback}; provide --{fallback}")
    expanded = Path(candidate).expanduser()
    resolved = expanded.absolute() if preserve_symlink else expanded.resolve()
    if not resolved.is_file():
        raise FileNotFoundError(f"executable does not exist: {resolved}")
    return resolved


def main(argv: Sequence[str] | None = None) -> int:
    args = parser().parse_args(argv)
    if args.self_test:
        self_test()
        return 0
    if not args.opentitan_root or not args.build_root or not args.iverilog:
        parser().error("--opentitan-root, --build-root, and --iverilog are required")
    if args.jobs < 1:
        parser().error("--jobs must be at least 1")
    if args.runtime_memory_mib < 0:
        parser().error("--runtime-memory-mib must be nonnegative")
    if args.runtime_memory_mib and sys.platform != "darwin":
        parser().error("--runtime-memory-mib requires macOS footprint")
    dpi_libraries = [path.expanduser().resolve() for path in args.dpi_library]
    missing_dpi_libraries = [path for path in dpi_libraries if not path.is_file()]
    if missing_dpi_libraries:
        parser().error(
            "DPI shared library does not exist: "
            + ", ".join(str(path) for path in missing_dpi_libraries)
        )
    args.dpi_library = dpi_libraries
    uvm_home = args.uvm_home or os.environ.get("IVERILOG_UVM_HOME")
    if uvm_home:
        source_root = Path(uvm_home).expanduser().resolve()
        if not (source_root / "uvm_pkg.sv").is_file():
            source_root = source_root / "src"
        if not (source_root / "uvm_pkg.sv").is_file():
            parser().error(f"UVM home does not contain uvm_pkg.sv: {uvm_home}")
        args.uvm_home = source_root

    opentitan_root = args.opentitan_root.expanduser().resolve()
    build_root = args.build_root.expanduser().resolve()
    iverilog = resolve_executable(args.iverilog, "iverilog")
    fusesoc = resolve_executable(
        args.fusesoc, "fusesoc", preserve_symlink=True
    )
    vvp_candidate = iverilog.with_name("vvp")
    vvp = vvp_candidate if vvp_candidate.is_file() else resolve_executable(None, "vvp")
    if not opentitan_root.is_dir():
        parser().error(f"OpenTitan root does not exist: {opentitan_root}")
    build_root.mkdir(parents=True, exist_ok=True)
    matrix_core_root = prepare_matrix_core_root(build_root, opentitan_root)

    env = os.environ.copy()
    env["PATH"] = os.pathsep.join(
        [str(iverilog.parent), str(fusesoc.parent), env.get("PATH", "")]
    )
    try:
        _require_python313(
            ".".join(str(part) for part in sys.version_info[:3]),
            role="matrix driver Python",
        )
        lanes = requested_lanes(args.lane)
        fusesoc_python = resolve_fusesoc_python(
            fusesoc, args.fusesoc_python, env
        )
        fusesoc_python_info = validate_fusesoc_python(
            fusesoc_python,
            require_hjson=bool({"uvm", "runtime"}.intersection(lanes)),
            cwd=opentitan_root,
            env=env,
            timeout=args.setup_timeout,
        )
        fusesoc_version = tool_version(
            [str(fusesoc), "--version"], opentitan_root, env
        )
        python_version = str(fusesoc_python_info.get("python_version", ""))
        _require_python313(python_version, role="FuseSoC Python")
        if fusesoc_python_info["fusesoc_version"] != fusesoc_version:
            raise RuntimeError(
                "FuseSoC executable/Python version mismatch: executable reports "
                f"{fusesoc_version}, but {fusesoc_python_info['command']} imports "
                f"{fusesoc_python_info['fusesoc_version']}. Select the matching "
                "environment with --fusesoc-python."
            )
        cores = discover_cores(fusesoc, opentitan_root, env, args.setup_timeout)
        formal_targets = None
        simulation_targets = None
        if "sva" in lanes:
            formal_targets = discover_formal_targets(
                fusesoc_python, opentitan_root, env, args.setup_timeout
            )
        if {"uvm", "runtime"}.intersection(lanes):
            simulation_targets = discover_simulation_targets(
                fusesoc_python, opentitan_root, env, args.setup_timeout
            )
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        return 2
    jobs = select_jobs(cores, args, formal_targets, simulation_targets)
    if args.list:
        print_inventory(jobs, simulation_targets)
        return 0
    if not jobs:
        print("No OpenTitan cores matched the requested lanes and filters", file=sys.stderr)
        return 2

    native_cflags: list[str] = []
    native_libs: list[str] = []
    native_pkg_config = None
    if args.native_pkg_config:
        try:
            native_cflags, native_libs, native_pkg_config = native_pkg_config_flags(
                args.native_pkg_config, env, opentitan_root, args.setup_timeout
            )
        except RuntimeError as exc:
            print(str(exc), file=sys.stderr)
            return 2

    metadata: dict[str, object] = {
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "opentitan_root": str(opentitan_root),
        "opentitan_revision": git_value(opentitan_root, "rev-parse", "HEAD"),
        "opentitan_dirty": bool(git_value(opentitan_root, "status", "--porcelain")),
        "iverilog": str(iverilog),
        "iverilog_sha256": file_sha256(iverilog),
        "iverilog_version": tool_version([str(iverilog), "-V"], opentitan_root, env),
        "compiler_fingerprint": compiler_fingerprint(iverilog, vvp, args.uvm_home),
        "fusesoc": str(fusesoc),
        "fusesoc_real_executable": str(fusesoc.resolve()),
        "fusesoc_sha256": file_sha256(fusesoc),
        "fusesoc_version": fusesoc_version,
        "fusesoc_python": fusesoc_python_info,
        "top_mapping": args.top,
        "uvm_runtime_compile_profile": (
            "commercial-unsafe" if args.commercial_unsafe else "default"
        ),
        "matrix_jobs": args.jobs,
        "runtime_timeout_seconds": args.runtime_timeout,
        "runtime_memory_mib": args.runtime_memory_mib,
        "matrix_provider_core_root": str(matrix_core_root),
        "englishbreakfast_mapping_sha256": hashlib.sha256(
            ENGLISHBREAKFAST_MAPPING_CORE.encode()
        ).hexdigest(),
        "prim_generic_mapping_sha256": hashlib.sha256(
            PRIM_MAPPING_CORE.encode()
        ).hexdigest(),
    }
    metadata["matrix_source_core_overrides"] = [
        {
            "source_core": relative_core,
            "added_dependencies": [
                dependency
                for dependency in added_dependencies
                if dependency
                not in {
                    line.strip()[2:].strip()
                    for line in (opentitan_root / relative_core)
                    .read_text()
                    .splitlines()
                    if line.strip().startswith("- ")
                }
            ],
            "source_sha256": file_sha256(opentitan_root / relative_core),
            "overlay_sha256": file_sha256(
                matrix_core_root / "source-overrides" / relative_core
            ),
        }
        for relative_core, _anchor, added_dependencies in (
            MATRIX_SOURCE_CORE_DEPENDENCIES
        )
        if (matrix_core_root / "source-overrides" / relative_core).is_file()
    ]
    spi_host_core_overlay = matrix_core_root / "source-overrides" / SPI_HOST_SVA_CORE
    if spi_host_core_overlay.is_file():
        metadata["matrix_source_core_text_overrides"] = [
            {
                "source_core": SPI_HOST_SVA_CORE,
                "source_sha256": file_sha256(opentitan_root / SPI_HOST_SVA_CORE),
                "overlay_sha256": file_sha256(spi_host_core_overlay),
                "change": "remove nonexistent files_formal target fileset",
            }
        ]
    if native_pkg_config is not None:
        metadata["native_pkg_config"] = native_pkg_config
    if formal_targets is not None:
        formal_listing = "\n".join(sorted(formal_targets)) + "\n"
        metadata["fusesoc_formal_target_count"] = len(formal_targets)
        metadata["fusesoc_formal_targets_sha256"] = hashlib.sha256(
            formal_listing.encode()
        ).hexdigest()
    if simulation_targets is not None:
        simulation_inventory = [
            dataclasses.asdict(simulation_targets[name])
            for name in sorted(simulation_targets)
        ]
        simulation_listing = json.dumps(
            simulation_inventory, sort_keys=True, separators=(",", ":")
        )
        category_counts = {category: 0 for category in SIMULATION_CATEGORIES}
        for target in simulation_targets.values():
            category_counts[target.category] += 1
        metadata.update(
            {
                "fusesoc_sim_target_count": len(simulation_targets),
                "fusesoc_sim_category_counts": category_counts,
                "fusesoc_sim_targets_sha256": hashlib.sha256(
                    simulation_listing.encode()
                ).hexdigest(),
                "fusesoc_sim_targets": simulation_inventory,
                "uvm_runtime_configured_target_count": sum(
                    target.category == "uvm" and target.uvm_runtime_configured
                    for target in simulation_targets.values()
                ),
            }
        )
    json_path = (args.result_json or (build_root / "opentitan-matrix.json")).resolve()
    md_path = (args.result_md or (build_root / "opentitan-matrix.md")).resolve()
    save_report(metadata, [], json_path, md_path)

    def execute(job: Job) -> dict[str, object]:
        return run_job(
            job,
            args=args,
            opentitan_root=opentitan_root,
            build_root=build_root,
            matrix_core_root=matrix_core_root,
            fusesoc=fusesoc,
            iverilog=iverilog,
            vvp=vvp,
            env=env,
            native_cflags=native_cflags,
            native_libs=native_libs,
        )

    indexed_results: list[tuple[int, dict[str, object]]] = []
    if args.jobs == 1:
        try:
            for index, job in enumerate(jobs, 1):
                print(f"[{index}/{len(jobs)}] {job.lane} {job.core.vlnv}", flush=True)
                record = execute(job)
                indexed_results.append((index - 1, record))
                save_report(
                    metadata,
                    [item for _, item in sorted(indexed_results)],
                    json_path,
                    md_path,
                )
                print(f"  -> {record['status']}", flush=True)
        except KeyboardInterrupt:
            terminate_active_commands()
            save_report(
                metadata,
                [item for _, item in sorted(indexed_results)],
                json_path,
                md_path,
            )
            print(
                f"Interrupted after {len(indexed_results)}/{len(jobs)} jobs; "
                f"partial report preserved at {json_path}",
                file=sys.stderr,
            )
            return 130
    else:
        executor = concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs)
        pending: dict[concurrent.futures.Future[dict[str, object]], tuple[int, Job]] = {}
        try:
            pending = {
                executor.submit(execute, job): (index, job)
                for index, job in enumerate(jobs)
            }
            for completed, future in enumerate(
                concurrent.futures.as_completed(pending), 1
            ):
                index, job = pending[future]
                try:
                    record = future.result()
                except Exception as exc:  # preserve the rest of a long census
                    work_root = build_root / job.lane / safe_name(job.core.vlnv)
                    record = result_base(
                        job, work_root, provider_mappings(job, args.top)
                    )
                    record.update({"status": "MATRIX_ERROR", "matrix_error": str(exc)})
                indexed_results.append((index, record))
                save_report(
                    metadata,
                    [item for _, item in sorted(indexed_results)],
                    json_path,
                    md_path,
                )
                print(
                    f"[{completed}/{len(jobs)}] {job.lane} {job.core.vlnv}"
                    f" -> {record['status']}",
                    flush=True,
                )
        except KeyboardInterrupt:
            for future in pending:
                future.cancel()
            terminate_active_commands()
            executor.shutdown(wait=True, cancel_futures=True)
            save_report(
                metadata,
                [item for _, item in sorted(indexed_results)],
                json_path,
                md_path,
            )
            print(
                f"Interrupted after {len(indexed_results)}/{len(jobs)} jobs; "
                f"partial report preserved at {json_path}",
                file=sys.stderr,
            )
            return 130
        else:
            executor.shutdown(wait=True)
    results = [record for _, record in sorted(indexed_results)]
    save_report(metadata, results, json_path, md_path)
    print(f"JSON: {json_path}")
    print(f"Markdown: {md_path}")

    failing = {
        "SETUP_TIMEOUT",
        "SETUP_FAIL",
        "COMPILE_TIMEOUT",
        "FAIL",
        "RUNTIME_TIMEOUT",
        "RUNTIME_MEMORY_LIMIT",
        "RUNTIME_MEMORY_MONITOR_FAIL",
        "RUNTIME_FAIL",
        "RUNTIME_CONFIG_MISSING",
        "MATRIX_ERROR",
        "DEBT",
        "SETUP_DEBT",
    }
    return 1 if any(result["status"] in failing for result in results) else 0


if __name__ == "__main__":
    raise SystemExit(main())
