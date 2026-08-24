# OpenTitan packed clocking sampling and selected-drive closure

Date: 2026-08-24

Base commit: `299087d23b7311e5aeaad77ac92dbee70ea2d5c0`

Worktree toolchain:

- Compiler: `local-install/bin/iverilog` (native ARM64)
- Runtime: `local-install/bin/vvp` (native ARM64)
- Process wrapper: `../evidence/arm64-tooling/resource-runner`
- Slang reference: `/Users/danielellerbrock/oss-cad-suite/bin/slang`
- Slang driver Python: `/opt/homebrew/opt/python@3.13/bin/python3.13`

## Packed-member Preponed history

A concurrent assertion that directly referenced a packed-aggregate member
lowered its sample as an `IVL_EX_SELECT` over an `IVL_EX_SIGNAL`. The VVP
target's `$ivl_clocking_hist_on` handler recognized only terminal signal and
array expressions. It therefore emitted `%load/preponed` for the checker but
did not enable history for the underlying signal, so the member was read live.

The target now peels only `IVL_EX_SELECT` wrappers and enables history on the
terminal signal. It deliberately stops at `IVL_EX_SIGNAL`: operand 1 of a
signal expression can be an unpacked-array word index and is not another
wrapper. `sv_assert_packed_member_preponed_sample` proves both `0 -> 1` and the
OpenTitan-shaped known `1 -> X` transition. The previous compiler reports two
live member transitions while scalar controls remain correctly Preponed; the
fixed compiler reports zero for all four counters.

## Virtual-interface selected output drives

OpenTitan's TL device driver issues assignments such as:

```systemverilog
cfg.vif.device_cb.d2h.a_ready <= 1'b1;
```

The previous lowering stored `a_ready` in the hidden 66-bit output buffer and
then scheduled the complete buffer into `d2h_int`. Fields that had never been
written in that buffer were `X`, so this one-member drive changed unrelated
fields, including `d_valid`, to `X`. `tlul_assert.sv` consequently failed
`dKnown_AKnownEnable` at 4,272,815 ps.

The hidden pending flag is now a bit-for-bit write-enable mask with the same
packed type as the clockvar. A selected VIF drive preserves its member or
constant bit/part-select suffix on the buffer, mask, and raw paths. The
clocking-event apply process schedules one selected NBA for each pending bit
and then clears the mask. This retains NBA merge behavior for unrelated raw
updates instead of taking a whole-value snapshot.

Red proof with the compiler built from the base commit:

- `sv_vif_clocking_partial_member_preserve`: five failed preservation/order
  checks and exit status 1; untouched fields include `X`.
- `sv_vif_clocking_partial_select_preserve`: two failed bit/part-select checks
  and exit status 1.

Focused fixed results:

- VIF clocking-output legacy focus: 2/2 passed.
- VIF clocking-output JSON/VVP focus: 2 run, 0 failed.
- Caliptra SVA/runtime legacy focus: 53/53 passed.
- Caliptra SVA/runtime JSON/VVP focus: 13 run, 0 failed.
- Slang IEEE 1800-2017 differential: 25 cases, 0 failed.
- Existing VIF clocking drive/member/alias controls: 3/3 passed.

Broad fixed results:

- Complete default legacy sweep: 4,000 records, 0 failed, 2 recorded NI,
  3 expected failures.
- Complete SystemVerilog legacy manifest: 1,816/1,816 passed.
- Complete JSON/VVP manifest: 884 records, 0 failed.
- VPI: 97/97 passed.
- Negative diagnostics: 111/111 passed.
- `make check`: passed.
- Real-DPI UVM: 338 passed, 0 failed, 0 skipped; the real DPI umbrella was
  loaded rather than falling back to `UVM_NO_DPI`.

The unmodified OpenTitan DMA image was recompiled from
`matrix-iverilog.scr`. With `IVL_SVA_NFA=1`, it advances to at least
3,866,045,985 ps before the 45-second CPU guard, more than 900 times beyond
the former assertion, without `dKnown_AKnownEnable` or another assertion
failure. `IVL_TIME_TRACE_NS` was used only to distinguish continued simulated
time advance from quiet UVM output.

## Recorded boundaries

This is not a full clause-14 claim. Current-event VIF drives do not yet carry
the clocking output skew metadata. Selected clockvar drives through same-scope
or statically named instance spellings still fall through the whole-clockvar
path. Dynamic selected VIF NBA targets and non-default parameterized-interface
widths require separate lowering/typing work. These boundaries are recorded in
the clause matrix rather than silently treated as supported.
