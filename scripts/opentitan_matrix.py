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
from typing import Iterable, Sequence


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
}
DEFAULT_TOPS = {
    "earlgrey": "lowrisc:systems:top_earlgrey:0.1",
    "darjeeling": "lowrisc:systems:top_darjeeling:0.1",
}
TOP_VARIANTS = (*DEFAULT_TOPS, "englishbreakfast")
PRIM_MAPPING = "lowrisc:prim_generic:all:0.1"
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
OPENTITAN_RUNTIME_FAIL_PATTERNS = (
    re.compile(r"^UVM_ERROR\s[^:].*$", re.I),
    re.compile(r"^UVM_FATAL\s[^:].*$", re.I),
    re.compile(r"^UVM_WARNING\s[^:].*$", re.I),
    re.compile(r"^Assert failed: ", re.I),
    re.compile(r"^\s*Offending '.*'", re.I),
    re.compile(r"^TEST FAILED (?:UVM_)?CHECKS$", re.I),
    re.compile(r"^Error:.*$", re.I),
)
RUNTIME_DEBT_ALLOWLIST = (
    # IEEE 1800 permits a function call as a statement with its return value
    # discarded. Icarus deliberately emits this optional diagnostic from its
    # VPI runtime; Slang and Verilator accept the same call without warning.
    re.compile(r"Warning: Calling system function \$system\(\) as a task\.", re.I),
    re.compile(r"The functions return value will be ignored\.", re.I),
)
SETUP_ALLOWLIST = (
    re.compile(r"No trustfile configured .* signatures will not be checked", re.I),
    # This is an Edalize API-lifecycle notice.  It does not change the selected
    # sources, provider mapping, compiler invocation, or HDL semantics.
    re.compile(r"This backend is deprecated .* migrate to the flow API", re.I),
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
        "keccak_2share_fpv.sv's StPhase1 case item is missing an `end` "
        "(the else-begin block and the case-item begin share one), so "
        "the file cannot parse. slang 11.0 reports the same "
        "\"expected 'end'\"; the FPV testbench is syntactically broken "
        "at the pinned revision.",
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


ACTIVE_PROCESSES: set[subprocess.Popen[str]] = set()
ACTIVE_PROCESSES_LOCK = threading.Lock()


def signal_command_tree(process: subprocess.Popen[str], sig: int) -> None:
    """Signal a command and every child in the session created for it."""
    if process.poll() is not None:
        return
    try:
        if os.name == "posix":
            os.killpg(process.pid, sig)
        else:
            process.send_signal(sig)
    except ProcessLookupError:
        pass


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
) -> CommandResult:
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


def compiler_fingerprint(iverilog: Path, vvp: Path) -> dict[str, object]:
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
    uvm_sources = ivl_root / "uvm" / "src"
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
manager.add_library(Library("opentitan-matrix", root), [])
formal = []
for name, core in manager.get_cores().items():
    try:
        core.get_flags("formal")
    except RuntimeError:
        continue
    formal.append(str(name))
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
manager.add_library(Library("opentitan-matrix", str(root)), [])
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
    for fileset_name, fileset in core._capi_data.get("filesets", {}).items():
        dependencies = set()
        hdl_text = []
        has_native = False
        has_dpi = False
        for dependency in fileset.get("depend", []) or []:
            resolved = resolve_dependency(dependency)
            if resolved:
                dependencies.add(resolved)
        default_type = str(fileset.get("file_type", ""))
        for entry in fileset.get("files", []) or []:
            attributes = {}
            if isinstance(entry, dict):
                source_name = next(iter(entry))
                if isinstance(entry[source_name], dict):
                    attributes = entry[source_name]
            else:
                source_name = str(entry)
            source_name = normalize_reference(source_name)
            source = Path(core.core_root) / source_name
            if not source.is_file():
                continue
            file_type = str(attributes.get("file_type", default_type)).casefold()
            suffix = source.suffix.casefold()
            native = (
                "csource" in file_type
                or "cppsource" in file_type
                or suffix in {".c", ".cc", ".cpp", ".cxx"}
            )
            has_native = has_native or native
            if suffix in {".v", ".vh", ".sv", ".svh"}:
                text = source.read_text(errors="replace")
                hdl_text.append(text)
                has_dpi = has_dpi or "DPI-C" in text
        fileset_metadata[fileset_name] = {
            "dependencies": sorted(dependencies),
            "text": "\n".join(hdl_text),
            "native": has_native,
            "dpi": has_dpi,
        }
    core_metadata[name] = {"filesets": fileset_metadata}


def selected_filesets(name, target_name):
    core = cores[name]
    targets = core._capi_data.get("targets", {})
    target = targets.get(target_name)
    if not isinstance(target, dict):
        target = targets.get("default")
    available = core_metadata[name]["filesets"]
    if not isinstance(target, dict):
        return list(available)
    selected = [
        normalize_reference(fileset)
        for fileset in target.get("filesets", []) or []
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
            if metadata["dpi"]:
                dpi_cores.add(name)
            pending.extend(
                (dependency, "default")
                for dependency in metadata["dependencies"]
            )
    return seen_cores, "\n".join(hdl_text), native_cores, dpi_cores


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
for config_path in sorted(root.rglob("*sim_cfg.hjson")):
    config = load_config(config_path)
    context = {
        **{
            key: value
            for key, value in config.items()
            if isinstance(value, (str, int, float, bool))
        },
        "proj_root": str(root),
        "self_dir": str(config_path.parent),
    }
    override_core = None
    for override in config.get("overrides", []) or []:
        if isinstance(override, dict) and override.get("name") == "fusesoc_core":
            override_core = override.get("value")
    core_value = override_core or config.get("fi_core") or config.get("fusesoc_core")
    if not isinstance(core_value, str):
        continue
    core_name = substitute(core_value, context)
    if "{" in core_name or core_name not in cores:
        continue
    tests = [test for test in config.get("tests", []) or [] if isinstance(test, dict)]
    smoke_tests = [
        test for test in tests if "smoke" in str(test.get("name", "")).casefold()
    ]
    expected_smoke = str(config.get("name", "")) + "_smoke"
    selected = next(
        (test for test in smoke_tests if test.get("name") == expected_smoke),
        smoke_tests[0] if smoke_tests else (tests[0] if len(tests) == 1 else {}),
    )
    uvm_test = substitute(
        selected.get("uvm_test", config.get("uvm_test", "")), context
    ) or None
    uvm_test_seq = substitute(
        selected.get("uvm_test_seq", config.get("uvm_test_seq", "")), context
    ) or None
    smoke_regressions = [
        regression
        for regression in config.get("regressions", []) or []
        if isinstance(regression, dict) and regression.get("name") == "smoke"
    ]
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
    if build_mode:
        for mode in config.get("build_modes", []) or []:
            if isinstance(mode, dict) and mode.get("name") == build_mode:
                build_options.extend(
                    substitute(option, context)
                    for option in mode.get("build_opts", []) or []
                )
                runtime_options.extend(
                    substitute(option, context)
                    for option in mode.get("run_opts", []) or []
                    if str(option).startswith("+") and "{" not in str(option)
                )
                break
    build_options.extend(
        substitute(option, context) for option in selected.get("build_opts", []) or []
    )

    orchestration_requirements = []
    for key in (
        "pre_build_cmds",
        "post_build_cmds",
        "pre_run_cmds",
        "post_run_cmds",
        "sw_images",
        "en_build_modes",
        "en_run_modes",
    ):
        if (
            config.get(key)
            or selected.get(key)
            or any(regression.get(key) for regression in smoke_regressions)
        ):
            orchestration_requirements.append(key)
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
    candidate_score = (
        bool(uvm_test and uvm_test_seq),
        bool(selected),
        -len(candidate["unresolved_runtime_options"]),
    )
    previous_score = (
        bool(previous and previous.get("uvm_test") and previous.get("uvm_test_seq")),
        bool(previous and previous.get("dvsim_test")),
        -len(previous.get("unresolved_runtime_options", [])) if previous else 0,
    )
    if previous is None or candidate_score > previous_score:
        configs[core_name] = candidate


simulation_targets = []
for name, core in cores.items():
    target = core._capi_data.get("targets", {}).get("sim")
    if not isinstance(target, dict):
        continue
    closure, closure_text, native_cores, dpi_cores = source_closure(name)
    requires_uvm_library = bool(
        re.search(r"\bimport\s+uvm_pkg\s*::", closure_text)
        or re.search(r"[`\"]uvm_macros\.svh", closure_text)
    )
    default_tool = str(target.get("default_tool", ""))
    if default_tool == "verilator":
        category = "verilator"
    elif re.search(r"\brun_test\s*\(", closure_text):
        category = "uvm"
    elif "$finish" in closure_text:
        category = "directed"
    else:
        category = "elaboration"

    toplevels = target.get("toplevel", [])
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
    if native_dependencies:
        metadata_warnings.append(
            "native C/C++ dependencies require a DPI/VPI build outside the "
            "Edalize Icarus source-list backend"
        )

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


def prepare_matrix_core_root(build_root: Path) -> Path:
    """Create local mapping cores needed for deterministic dependency solves."""
    core_root = build_root / "matrix-provider-cores"
    core_root.mkdir(parents=True, exist_ok=True)
    mapping_core = core_root / "top_englishbreakfast_mapping.core"
    if (
        not mapping_core.is_file()
        or mapping_core.read_text() != ENGLISHBREAKFAST_MAPPING_CORE
    ):
        mapping_core.write_text(ENGLISHBREAKFAST_MAPPING_CORE)
    return core_root


def actionable_setup_lines(output: str) -> list[str]:
    findings: list[str] = []
    for line in output.splitlines():
        if "warning" not in line.casefold():
            continue
        if any(pattern.search(line) for pattern in SETUP_ALLOWLIST):
            continue
        findings.append(line.strip())
    return findings


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
            return source_list, shlex.split(assignments.get("TOPLEVEL", ""))
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
    command = [
        str(fusesoc),
        f"--cores-root={opentitan_root}",
        f"--cores-root={matrix_core_root}",
        "run",
        f"--target={job.target}",
        "--tool=icarus",
        "--setup",
        f"--work-root={work_root}",
    ]
    for mapping in provider_mappings(job, requested_top):
        command.append(f"--mapping={mapping}")
    command.append(job.core.vlnv)
    return command


def compile_command(
    job: Job,
    iverilog: Path,
    source_list: Path,
    top_options: Sequence[str],
    output: Path,
) -> list[str]:
    command = [str(iverilog), "-g2012", *top_options]
    if job.lane == "rtl":
        command.extend(["-S", "-DSYNTHESIS"])
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
            command.extend(
                [
                    "-uvm",
                    "-DUVM",
                    "-DUVM_NO_DEPRECATED",
                    "-DUVM_REG_ADDR_WIDTH=32",
                    "-DUVM_REG_DATA_WIDTH=32",
                    "-DUVM_REG_BYTENABLE_WIDTH=4",
                ]
            )
        command.extend(["-DSIMULATION", "-DDUT_HIER=tb.dut"])
        command.extend(UVM_EXTRA_DEFINES.get(job.core.vlnv, ()))
    command.extend(["-o", str(output), "-c", str(source_list)])
    return command


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

    try:
        source_list, top_options = parse_makefile(work_root)
        top_options, top_notes, package_wrapper = validated_top_options(
            job, source_list, top_options, work_root
        )
        compiler_source_list = simulation_source_list(job, source_list, work_root)
        if package_wrapper is not None:
            compiler_source_list = package_wrapper
        top_options, sva_notes, sva_wrapper = sva_testbench_wrapper(
            job, source_list, top_options, work_root, compiler_source_list
        )
        if sva_wrapper is not None:
            compiler_source_list = sva_wrapper
    except (FileNotFoundError, OSError, ValueError) as exc:
        record.update({"status": "SETUP_FAIL", "matrix_error": str(exc)})
        return record
    if top_notes:
        record["top_selection_notes"] = top_notes
    if sva_notes:
        record["sva_topology_notes"] = sva_notes

    executable = work_root / f"matrix-{job.lane}.vvp"
    compile_result = command_result(
        compile_command(
            job, iverilog, compiler_source_list, top_options, executable
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
    semantic_debt = matching_lines(compile_result.output, DEBT_PATTERNS)
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
    if setup_findings or semantic_debt:
        defect = (
            upstream_defect_for(job.core.vlnv, "compile", semantic_debt)
            if semantic_debt and not setup_findings
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
    dpi_options = [
        option
        for library in args.dpi_library
        for option in ("-d", str(library))
    ]
    runtime_command = [
        str(vvp), "-n", *dpi_options, str(executable), *runtime_arguments
    ]
    runtime_result = command_result(
        runtime_command,
        cwd=source_list.parent,
        env={**env, "IVL_SVA_NFA": "1"},
        timeout=args.runtime_timeout,
    )
    runtime_log = work_root / "matrix-runtime.log"
    write_log(runtime_log, "OpenTitan UVM runtime", runtime_result)
    runtime_errors = matching_lines(
        runtime_result.output,
        (*HARD_ERROR_PATTERNS, *OPENTITAN_RUNTIME_FAIL_PATTERNS),
    )
    runtime_pass_banner = bool(OPENTITAN_RUNTIME_PASS_RE.search(runtime_result.output))
    if not runtime_pass_banner:
        runtime_errors.append(
            "OpenTitan runtime produced no `TEST PASSED [UVM_]CHECKS` banner"
        )
    runtime_debt = matching_lines(
        runtime_result.output, DEBT_PATTERNS, RUNTIME_DEBT_ALLOWLIST
    )
    runtime_benign_diagnostics = matching_lines(
        runtime_result.output, RUNTIME_DEBT_ALLOWLIST
    )
    record.update(
        {
            "runtime_command": short_command(runtime_command),
            "runtime_dpi_libraries": [str(path) for path in args.dpi_library],
            "runtime_returncode": runtime_result.returncode,
            "runtime_duration_seconds": round(runtime_result.duration_seconds, 3),
            "runtime_timed_out": runtime_result.timed_out,
            "runtime_log": str(runtime_log),
            "runtime_error_count": len(runtime_errors),
            "runtime_errors": runtime_errors[: args.diagnostic_limit],
            "runtime_pass_banner": runtime_pass_banner,
            "runtime_debt_count": len(runtime_debt),
            "runtime_debt": runtime_debt[: args.diagnostic_limit],
            "runtime_benign_diagnostic_count": len(runtime_benign_diagnostics),
            "runtime_benign_diagnostics": runtime_benign_diagnostics[
                : args.diagnostic_limit
            ],
        }
    )
    if runtime_result.timed_out:
        record["status"] = "RUNTIME_TIMEOUT"
    elif runtime_result.returncode != 0 or runtime_errors:
        record["status"] = "RUNTIME_FAIL"
    elif setup_findings or semantic_debt or runtime_debt:
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
    assert OPENTITAN_RUNTIME_PASS_RE.search("TEST PASSED CHECKS\n")
    assert OPENTITAN_RUNTIME_PASS_RE.search("TEST PASSED UVM_CHECKS\n")
    assert not OPENTITAN_RUNTIME_PASS_RE.search("UVM_INFO test ended\n")
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
    print("opentitan_matrix self-test: PASS")


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--opentitan-root", type=Path)
    result.add_argument("--build-root", type=Path)
    result.add_argument("--iverilog", type=Path)
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
    result.add_argument("--runtime-arg", action="append", default=[])
    result.add_argument(
        "--dpi-library",
        action="append",
        type=Path,
        default=[],
        help="repeat to load a native DPI shared library with vvp -d",
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
    dpi_libraries = [path.expanduser().resolve() for path in args.dpi_library]
    missing_dpi_libraries = [path for path in dpi_libraries if not path.is_file()]
    if missing_dpi_libraries:
        parser().error(
            "DPI shared library does not exist: "
            + ", ".join(str(path) for path in missing_dpi_libraries)
        )
    args.dpi_library = dpi_libraries

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
    matrix_core_root = prepare_matrix_core_root(build_root)

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


    metadata: dict[str, object] = {
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "opentitan_root": str(opentitan_root),
        "opentitan_revision": git_value(opentitan_root, "rev-parse", "HEAD"),
        "opentitan_dirty": bool(git_value(opentitan_root, "status", "--porcelain")),
        "iverilog": str(iverilog),
        "iverilog_sha256": file_sha256(iverilog),
        "iverilog_version": tool_version([str(iverilog), "-V"], opentitan_root, env),
        "compiler_fingerprint": compiler_fingerprint(iverilog, vvp),
        "fusesoc": str(fusesoc),
        "fusesoc_real_executable": str(fusesoc.resolve()),
        "fusesoc_sha256": file_sha256(fusesoc),
        "fusesoc_version": fusesoc_version,
        "fusesoc_python": fusesoc_python_info,
        "top_mapping": args.top,
        "matrix_provider_core_root": str(matrix_core_root),
        "englishbreakfast_mapping_sha256": hashlib.sha256(
            ENGLISHBREAKFAST_MAPPING_CORE.encode()
        ).hexdigest(),
    }
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
        "RUNTIME_FAIL",
        "RUNTIME_CONFIG_MISSING",
        "MATRIX_ERROR",
        "DEBT",
        "SETUP_DEBT",
    }
    return 1 if any(result["status"] in failing for result in results) else 0


if __name__ == "__main__":
    raise SystemExit(main())
