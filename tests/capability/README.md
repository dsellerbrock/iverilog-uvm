# Capability probes

These are the probes behind the **capability analysis of all open manifesto
items** recorded in `docs/conformance/ROADMAP.md` (2026-07-24). They are not
part of any regression gate. Each one answers a single question — *what does
this feature actually do?* — so a ROADMAP row can carry an empirically
verified status instead of an assumed one.

Keeping them here makes every claim in the ROADMAP reproducible. Several are
slated to become real regression tests (see "Verified working" below); the
rest reproduce open defects and should be retired as those are fixed.

## Running a probe

Pure SystemVerilog:

    iverilog -g2012 -gassertions -o probe.vvp probe.sv && vvp probe.vvp

With a DPI object (probes that ship a matching `.c`):

    iverilog -g2012 -o probe.vvp probe.sv          # may write probe.dpiexport.c
    gcc -shared -fPIC -I<prefix>/include/iverilog \
        -o probe.so probe.c [probe.dpiexport.c]
    vvp -d./probe.so probe.vvp

VPI probes (`m6b2b_syncregions`):

    iverilog-vpi --name=m6b2b m6b2b_syncregions.c
    iverilog -o m6b2b.vvp m6b2b_syncregions.v
    vvp -M. -mm6b2b m6b2b.vvp

Probes that self-check print `PASS <name>` or a `FAIL ...` line. The trace
probes (`m10_4c_trace`, `m10_4d_auto`, `m6b2b_syncregions`) print an event
log to be read rather than a verdict.

## Silent defects reproduced here

These run to completion and print a wrong answer with **no diagnostic** —
the failure mode the project's loud-sorry rule exists to prevent.

| Probe | Item | What it shows |
|-------|------|---------------|
| `m6b4_selbound` | M6B-4 | The residual after the preponed fix: a **select** operand (`v[0]`) still reads live, while the whole-signal operand next to it samples correctly. Now warned about at compile time rather than silent |
| `m3b5_seed_stability` | M3B-5 | `srandom()` is a no-op: the same object re-seeded with the same value yields different results |
| `m4b4_p_packed_struct`, `m4b5_p_nested_dims` | M4B-4/5 | `%p` prints a packed struct as a plain integer and flattens nested dimensions (deferred cosmetic) |

## Verified working — candidates to pin as regression tests

| Probe | Item |
|-------|------|
| `m10_3_chandle`, `m10_3b_adv` | M10-3 — `chandle`/`real`/`string` ABI, including output/inout formals and `chandle` in a class property or array |
| `m10_5_reentr` | M10-5 — two-deep C→SV→C→SV reentrancy |
| `m10_4f_auto1`, `m10_4d_auto` | M10-4 — automatic-lifetime exports: a single call, and two concurrent invocations of one automatic exported task. **Both reproduced the fixed P0** (every argument arrived as `x`); now pinned by `tests/m10h_dpi_export_automatic_test` |
| `m10_4_slowtask`, `m10_4e_diff` | M10-4 — a single time-consuming export, and two *different* exports concurrently |
| `m10_4c_trace`, `staticsem` | M10-4 — concurrent invocations of a **static** export alias their arguments. Not a defect: IEEE 1800-2017 13.3.1 gives a static subroutine one copy of its arguments, and `staticsem` shows a plain SV static task doing exactly the same |
| `m10_4g_nested` | M10-4 — an automatic export whose body calls nested automatic subroutines and then delays; three concurrent invocations each keep their own frame |
| `m10_4h_recurse` | M10-4 — recursive re-entry: C → automatic export → C → the same export, four levels deep, each holding its own frame |
| `m6b3_kill` | M6B-3 — `join_any` + `disable fork` correctly abandons a blocked DPI import |
| `m13_1_bind_instpath`, `m13_2_bind_instlist` | M13-1/2 — bind to an instance path and to a target list, checked functionally rather than by parse |
| `m3b4_randmode` | M3B-4 — `rand_mode()`/`constraint_mode()` in all combinations |
| `m1b3_generic` | M1B-3 — the same shape the hardcoded `uvm_shared` fallback patches, under a different class name, works through the general path |
| `m6b4_det`, `m6b4_sample`, `m6b4_nba` | M6B-4 — preponed sampling. `m6b4_det` is the deterministic discriminator (one thread, no race); `m6b4_sample` the racy form, checking the failure count *and* time; `m6b4_nba` the NBA operand. **All three reproduced the fixed P0**; now pinned by `tests/m6b4_assert_preponed_sample_test` |

## A probe is only as good as its flags

`m13_5_timingchecks`, `m13_6_edgedesc`, `m13_7_pulsestyle`,
`beh_nochange_fires` and `beh_setup_fires` were originally read as proof
that timing checks were silently ignored. **They were not** — every one had
been run without `-gspecify`, and the entire specify block (path delays and
timing checks alike) is inert without it by design. Re-run with the flag,
`$setup`/`$hold`/`$width`/`$period`/`$nochange`/`$timeskew`/`$fullskew` all
report violations (`fires`), unsupported shapes emit a sorry, and the pulse
controls emit a warning. **Always run a specify probe with `-gspecify`.**

Probing the family properly did find one real silent defect, and only a
functional probe could have: `edge01` and `edge_both` share one stimulus so
the violation counts discriminate. `edge[01]` used to report *nothing* where
plain `$setup` reported the violation, because the previous-value tracker
was never primed — a descriptor silently discarded a real violation.
`edgeforms` extends that to `edge[10]` and multi-entry lists. All are now
pinned by `ivtest/ivltests/sv_timing_check_edge_descriptor.v`.

## Loud gaps (correct behaviour today, kept for the record)

`m13_3_config` and `m13_4_trireg` are unimplemented and say so with a sorry.
`m4c10_event_lifetime`, `m9_7_midseq_clock` and `m9_7_crossclock_overlap`
are a parse error and a sorry respectively. `m13_7_pulsestyle` is accepted
with a warning naming the directive and what is not modelled. `m6b2b_syncregions` shows the
existing sync-region ordering (`cbReadWriteSynch` → `cbAtEndOfSimTime` →
`cbReadOnlySynch`, all after NBA settle); `cbNBASynch` is absent from
`vpi_user.h` entirely, so it cannot be registered at all.
