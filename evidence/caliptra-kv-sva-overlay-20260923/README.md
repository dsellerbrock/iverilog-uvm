# Caliptra KV debug SVA diagnostic overlay

This is a testbench-only overlay for pinned Caliptra `v2.1.2`, commit
`49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e`. It changes only
`src/integration/asserts/caliptra_top_sva.sv`; the pinned checkout was left
clean.

The comprehensive checker remains the assertion consequent and still returns
false on the first mismatched key-vault dword. Its detailed `$display` is now
gated by a `report_error` argument: the property calls it with `0`, and the
assertion failure action calls it with `1` after printing the comprehensive
failure. Thus eager consequent-function evaluation under a false antecedent is
pure, while a real property failure retains both diagnostics.

## Patch application

The patch applies cleanly to a disposable copy of the pinned source:

```sh
cp /path/to/caliptra-rtl/src/integration/asserts/caliptra_top_sva.sv \
  evidence/caliptra-kv-sva-overlay-20260923/disposable/src/integration/asserts/caliptra_top_sva.sv
patch --dry-run -p1 -d evidence/caliptra-kv-sva-overlay-20260923/disposable \
  -i "$PWD/docs/conformance/release_overlays/caliptra/kv_debug_check_pure.patch"
patch -p1 -d evidence/caliptra-kv-sva-overlay-20260923/disposable \
  -i "$PWD/docs/conformance/release_overlays/caliptra/kv_debug_check_pure.patch"
```

The 96 KB disposable patched source copy remains local and is intentionally not committed. SHA-256 values:

- Pinned source file: `6bd2ade137a90c0701aab28951ba6f8918724e0467c21756b0c308e6e9081c89`
- Overlay patch: `f9c2673783665cd4c6f0d174f63823f935642bad50a9a62772a949420ad7a7e8`
- Patched disposable file: `7e832e09d1b95785db47226cc3dfaf1064771c14e413e354e7f66fd69938cac6`

## Focused Verilator check

`tests/kv_debug_overlay_check.sv` is a small fixture for the patched checker
and property-action pattern. Verilator 5.050 built it with:

```sh
verilator --binary --timing --assert --top-module kv_debug_overlay_check \
  --Mdir build-positive tests/kv_debug_overlay_check.sv
```

Three runs exercised the branches:

- `+trigger +match`: actual property trigger and matching value; prints
  `TESTCASE PASSED`, with no SVA diagnostics (`positive.log`).
- no plusargs: mismatched value but false antecedent; no SVA diagnostics
  (`vacuous.log`). This confirms the consequent function's eager evaluation
  has no diagnostic side effect.
- `+trigger`: actual property trigger and mismatched value; prints exactly one
  comprehensive failure and the detailed `KV[0][0]` mismatch, followed by
  `EXPECTED_ASSERTION_FAILURE_OBSERVED` (`negative.log`).

The negative run's process exits zero because the Caliptra assertion action is
`$display`-based and Verilator continues to `$finish`; that exit and the fixture
marker are not an application pass. The fixture isolates the SVA behavior and
does not claim a Caliptra DV run.

## Baseline and limits

The coordinator supplied the clean pinned `iccm_lock` baseline observation:
146,107 inner `SVA ERROR: KV[0][0] debug flush failed` lines, zero outer
`KV debug flush comprehensive check failed` lines, and `TESTCASE PASSED`.
The separate eager-function reproducer is in
`../caliptra-kv-sva-verilator-eager-20260923/`.

This overlay changes testbench diagnostics only. It does not repair key-vault
contents, alter the assertion predicate, suppress an assertion, or make the
application's own pass/fail accounting reliable. Re-run the selected
application and inspect its SVA diagnostics before making any qualification
claim.

## Pinned `iccm_lock` replay with the overlay

A second full test replay applied this patch to an 87 MB disposable copy of
pinned Caliptra v2.1.2 with `.git` entries excluded. The source/build scratch
copy was removed after preserving the logs. The [exact command and environment](patched-iccm-lock.command.json), [machine-readable result and fingerprints](patched-iccm-lock.result.json), and captured [build](patched-iccm-lock.build_log.log), [simulation](patched-iccm-lock.sim_log.log), and [stderr](patched-iccm-lock.make_stderr.log) are retained. The 432 KB raw make stdout remains local; its SHA-256 is recorded in the result JSON.

The run exited 0 and printed one `* TESTCASE PASSED` marker, with zero
`SVA ERROR:` lines: 0 detailed KV mismatch messages and 0 comprehensive-check
failures. It also printed no `TESTCASE FAILED` or `TEST FAILED` marker. This is
a diagnostic result, not qualification by pass banner: the test's assertions
were clean under this overlay, but firmware provenance still has a toolchain
caveat. The evidence-local xPack GCC 12.2.0 aliases were used; inspection of
this bundle found the release-selected
`rv32imc_zicsr_zifencei`/`ilp32` build resolving to default-root `libc.a` and
`libgcc.a`, whose architecture attributes include `A` rather than the narrower
`rv32imc/ilp32` multilib. The run's shell stderr also says `nproc` is missing;
the single-test build nevertheless completed. No `-Wno-fatal` or other
warning waiver was used; only `-Wno-MISINDENT` was supplied to Verilator.

This replay used the pinned Caliptra sources and Verilator, independent of the
Icarus compiler runtime. It does not claim a full L0 suite, full Caliptra DV,
or signoff.
