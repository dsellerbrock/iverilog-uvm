# OpenTitan CSRNG AES whole-array Preponed sampling

This fix is published in [PR #367](https://github.com/dsellerbrock/iverilog-uvm/pull/367),
stacked on open [PR #366](https://github.com/dsellerbrock/iverilog-uvm/pull/366)
(`3bc99d9310ec383011f761f6878c123a80dc0cc2`). The pinned OpenTitan
checkout remains clean at `a78922f14a8cc20c7ee569f322a04626f2ac6127`.
The CSRNG BlkLen compatibility overlay is present only in a disposable
FuseSoC source copy. The released AES assertion and all CSRNG checks remain
active. The release compile uses `-g2017 -gcommercial-unsafe` and native AES
DPI; its result is nonstandard compatibility evidence, not IEEE conformance.

## Baseline and root cause

The pre-fix released replay reports `AesSecCmDataRegKeySca` at 16,454,635 ps,
one UVM_ERROR, and `TEST FAILED CHECKS`: **0/1 released DV**. It observes one
SW-app instantiate command but no completed generate/genbits check. The
[diagnostic manifest](diagnostic_manifest.json), [exact command](commands_parallel3.json),
[copied-source diff](aes_cipher_core.parallel3.diag.diff.gz), and
[runtime](parallel3_runtime.stdout.log.gz) identify a disposable full-design
probe that preserves the original assertion. At the failing edge its parallel
whole-array property fails once while a scalar share-zero property passes
twice across overlapping attempts. The state-init and output words change
later in the antecedent clock slot. The isolated [parameter-derived
reducer](aes_clear_overlap_param.sv) without that same-slot change passes
positive and deliberate-negative controls in both 2017 and 2023; its four
logs delimit the cause.

The registered [same-slot net-array reducer](../../ivtest/ivltests/sv_assert_net_uarray_preponed.v)
adds a positive whole-array `$past` assertion, an independent scalar and
procedural oracle, a deliberately wrong update, second-word sampling, a
held-force control, and two strength-resolved net words. Against the PR #366
private VVP it is RED: [legacy
0/1](baseline_focus_legacy.log) and [paired JSON 0/2](baseline_focus_json.log).
The final reducer source also fails against that baseline VVP in
[2017](baseline_final_source_2017.runtime.log) and
[2023](baseline_final_source_2023.runtime.log). Net-backed `__vpiArray`
words change through their underlying signal, bypassing the array's
`set_word()` snapshot. The symbolic whole-array `$past` therefore read a
late live word. The fix enables each integral net word's existing first-write
Preponed history and reads it through the wire, preserving held-force bits;
value-backed arrays keep their previous path.

A [standalone strength-resolved reducer](vec8_standalone.sv) confirms the
separate `vvp_wire_vec8` branch. Both array words have opposing explicit
strength drivers, and generated VVP marks them `.net8` with two drivers.
Its baseline [2017](vec8_baseline_2017.runtime.log) and
[2023](vec8_baseline_2023.runtime.log) runs fail the Preponed/`$past`
checks, while the final [2017](vec8_final_2017.runtime.log) and
[2023](vec8_final_2023.runtime.log) runs pass. The standalone source is also
integrated into the registered reducer.

## Final private tool and released replay

The final private `iverilog`/`ivl`/`vvp` SHA-256 values are
`4e98b3a27b646486860199f176a71fa732c192b5abb6ca99aa48518b9ee2a0ca`,
`5a9cc2b3f3fe5912640f508e2d72e4206fb4362993f255f1fe01675e23da398d`,
and `e9c5a713c88c040fe4e941bd75a0f0e5c40995b273fcd17d1227325cdc4a038b`.
The [exact final runtime command and input hashes](release_final_commands.json)
include the filelist, hash-checked BlkLen overlay, original pinned AES
source, compiled VVP program, and native DPI library.

The [final released replay](release_final_runtime.stdout.log.gz) completes at
77,830,086 ps with scoreboard-observed SW-app instantiate, generate, and
uninstantiate traffic, completed `csrng_smoke_vseq`, zero UVM_ERROR/FATAL,
`TEST PASSED CHECKS`, and VVP exit zero: **1/1 released nonstandard OpenTitan
CSRNG DV**. The compile still warns that `int_state_read_enable_c` is ignored
by the constraint solver, a separate qualification limit. OTP released DV
remains 0/1. Neither result is a full OpenTitan DV qualification.

## Strict and broad checks

The final strict reducer passes [legacy 1/1](final_focus_legacy.log) and
[paired JSON 2/2](final_focus_json.log) under IEEE 1800-2017/2023, including
the strength-resolved array controls. The
neighboring resolved-net Preponed focus passes [legacy 1/1](neighbor_focus_legacy.log)
and [JSON 1/1](neighbor_focus_json.log); [`make check`](make_check.log) passes.
The IEEE boundary is 2017 §7.4.3 / 2023 §7.4.6 for fixed unpacked-array
equality and both editions §§16.5.1, 16.9.3, 16.12.7 for sampled values,
`$past`, and next-tick implication. The focused fix does not qualify other
array kinds or a force transition within the sampled slot.

The final [full legacy sweep](broad_legacy.log.gz) passes 6,613 ordinary
tests of 6,618 total, with zero unexpected failures, two not implemented,
and three expected failures. The [full JSON suite](broad_json.log.gz) passes
3,658/3,658. Its first run had two expected-diagnostic mismatches solely
because the private install lacked the optional FPGA target; the
[initial log](broad_json_pre_fpga.log.gz),
[private target install](private_fpga_install.log.gz), and
[2/2 focused correction](fpga_focus.log) preserve that setup correction.
The final `iverilog`/`ivl`/`vvp` hashes above did not change.

[Negative tests](negative.log.gz) pass 155/155, the
[SVA dual-engine gate](sva_nfa.log.gz) passes 62/62, bundled
[VPI with PLI1](vpi.log.gz) passes 140/140, and the adjacent
[force-array runtime controls](force_array_runtime.log) pass 2/2. The
[real-DPI UVM regression](real_dpi_uvm.log.gz) loads the umbrella and
passes 358/358 with zero failed/skipped. These are separate compiler/UVM
regression results, not released DV numerator credit. The
[machine-readable result](result.json) records the exact counts, tool
fingerprints, release markers, and traffic.
