# Caliptra post-AES SVA runtime triage (2026-09-23)

Scope: read-only inspection of the active `smoke_test_veer` diagnostic run at
`../caliptra-icarus-l0-diagnostic-aesfix-first-20260923/`. Its pinned Caliptra
source is clean at `49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e`.
The compile command and compiler fingerprints are in that run's
`compile.command.json`. The run was still active during this inspection; this
record is neither a completed test result nor a pass claim.

## First divergence

`smoke_test_veer/sim.log:74-80` shows reset release at SoC cycle 20, then the
first `Signature C 00000000 ... expected cc513461` diagnostic. The PK, SK,
and KV detailed diagnostics follow at lines 81-84 and repeat. The firmware
`exec.log` begins at simulation time 150 with reset-vector instructions; its
early instructions do not command MLDSA. This is before a legitimate MLDSA
check can be triggered.

The pinned checker is `caliptra-rtl/src/integration/asserts/caliptra_top_sva.sv`:
signature detail is printed by `check_mldsa_signature()` at lines 717-725;
PK and SK details by `check_mldsa_pubkey()` at 685-691 and
`check_mldsa_privkey()` at 648-654. Their properties at 775-797 sample on
`rdc_clk_cg`, disable in scan/unlocked state, and require an MLDSA testbench
mode **and** `abr_status_done` before calling the check on the next clock.
The mode bits reset to zero in
`caliptra_top_tb_services.sv:1219-1228` and only change on mailbox command
bytes such as D9, DA, and DC (`:1280-1320`). The KV detailed diagnostic is
inside `check_all_kv_debug_values()` at SVA lines 208-220; its property at
224-236 requires a rising debug/scan/fatal flush condition, then a next-clock
check. No corresponding outer assertion failure strings occur in the bounded
log inspection.

The compiled VVP is decisive about the diagnostic path: in the assertion thread around line 11366558,
the signature antecedent is stored, then `%callf/vec4 ...check_mldsa_signature`
is executed unconditionally, **before** `$ivl_assert_clock` receives the
sampled expressions. The same sequence occurs for SK around VVP line
11365888, PK around 11366224, and KV around 11358200. Their functions print
on mismatch. Thus detailed `SVA ERROR` lines are side effects of eager
consequent evaluation, even when the implication is vacuous. They do not, by
themselves, establish that the assertion property failed or that the DUT
produced a bad MLDSA/KV result. This matches the independently documented KV
control in `../caliptra-kv-sva-overlay-20260923/README.md`.

The nonzero expected PK/SK word is consistent with the generated
`keygen_output.hex` beginning `F401B8E4`, which the checker byte-swaps to
`e4b801f4`. A reset register still containing zero is therefore expected to
produce a *function-internal* mismatch when called early. This evidence does
not implicate the keygen vector generator. The services startup `initial`
block calls `mldsa_input_hex_gen()` at line 2637 before reset is released;
that task generates and parses keygen and sign output into `mldsa_test_vector`
at lines 2029-2110. The first signature expected value `cc513461` is nonzero,
so its vector field was populated at the first diagnostic, but the observed
diagnostic alone does not validate its full contents against `sign_output.hex`.
The first causal divergence is that a
diagnostic-bearing checker runs on every assertion sampling clock, outside its
property trigger; the source function's side effect makes this visible.
Existing Verilator evidence also shows eager consequent-function evaluation,
so this observation alone does not establish an Icarus-only compiler semantic
defect. The classification is testbench diagnostic side effect during startup.
There may be later true assertion failures, but this bounded inspection cannot
classify them.

## Paired 2017/2023 reducer

`eager_consequent.sv` has four `|=>` properties: false and one-cycle true
antecedents, each paired with an impure or pure function consequent that
returns false. The impure functions print an `INNER` marker and count calls;
each assertion action prints an `OUTER` marker and counts property failures.
The true antecedent is sampled at time 15, with its consequent due at 25.

Commands from the campaign checkout:

```sh
local-install/bin/iverilog -g2017 -gassertions -s eager_consequent -o evidence/caliptra-post-aes-sva-triage-20260923/eager_2017.vvp evidence/caliptra-post-aes-sva-triage-20260923/eager_consequent.sv
local-install/bin/vvp evidence/caliptra-post-aes-sva-triage-20260923/eager_2017.vvp > evidence/caliptra-post-aes-sva-triage-20260923/eager_2017.log
local-install/bin/iverilog -g2023 -gassertions -s eager_consequent -o evidence/caliptra-post-aes-sva-triage-20260923/eager_2023.vvp evidence/caliptra-post-aes-sva-triage-20260923/eager_consequent.sv
local-install/bin/vvp evidence/caliptra-post-aes-sva-triage-20260923/eager_2023.vvp > evidence/caliptra-post-aes-sva-triage-20260923/eager_2023.log
```

Both compiles and runs exited 0. Both edition logs have the same substantive
output: the impure false-antecedent and true-antecedent functions each print
at times 5, 15, 25, 35, and 45. Only at time 25 do `OUTER pure true` and
`OUTER impure true` print. The exact count line in each log is:

```text
COUNTS false_calls=5 true_calls=5 false_failures=0 true_failures=1 pure_false_failures=0 pure_true_failures=1
```

This proves eager function evaluation with side effects for a vacuous
implication in the current Icarus build. It also shows correct implication
truth in this narrow case: false antecedents cause no property failure; true
antecedents with false consequents fail once on the next clock, identically
for pure and impure functions. The evidence does not establish an IEEE
requirement to suppress calls to side-effecting functions used in assertion
expressions, nor an Icarus-only property-truth defect. A diagnostic-only
testbench overlay can move reporting into the assertion failure action while
preserving the property predicate and genuine failure detection.
