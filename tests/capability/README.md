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
| `m10_4f_auto1` | M10-4(a) | An `automatic`-lifetime DPI export reads `x` for every argument, even on a single non-concurrent call |
| `m10_4c_trace` | M10-4(b) | Two concurrent invocations of one exported task alias their arguments — `sv_wait(3,1)` runs as `id=0 d=5` |
| `m10_4d_auto` | M10-4(a+b) | The two above compounding: concurrent *and* automatic |
| `m6b4_det` | M6B-4 | A concurrent assertion samples the **Active**-region value, not the **Preponed** one (IEEE 1800-2017 16.5.1). Deterministic — one thread, no inter-process race |
| `m6b4_sample` | M6B-4 | The same defect in the racy form a testbench would actually hit |
| `m3b5_seed_stability` | M3B-5 | `srandom()` is a no-op: the same object re-seeded with the same value yields different results |
| `m13_5_timingchecks`, `m13_6_edgedesc`, `m13_7_pulsestyle`, `beh_nochange_fires`, `beh_setup_fires` | M13-5/6/7 | Timing checks, edge descriptors and pulse controls parse, elaborate, and are silently ignored |
| `m4b4_p_packed_struct`, `m4b5_p_nested_dims` | M4B-4/5 | `%p` prints a packed struct as a plain integer and flattens nested dimensions (deferred cosmetic) |

## Verified working — candidates to pin as regression tests

| Probe | Item |
|-------|------|
| `m10_3_chandle`, `m10_3b_adv` | M10-3 — `chandle`/`real`/`string` ABI, including output/inout formals and `chandle` in a class property or array |
| `m10_5_reentr` | M10-5 — two-deep C→SV→C→SV reentrancy |
| `m10_4_slowtask`, `m10_4e_diff` | M10-4 — the parts that *do* work: a single time-consuming export, and two *different* exports concurrently |
| `m6b3_kill` | M6B-3 — `join_any` + `disable fork` correctly abandons a blocked DPI import |
| `m13_1_bind_instpath`, `m13_2_bind_instlist` | M13-1/2 — bind to an instance path and to a target list, checked functionally rather than by parse |
| `m3b4_randmode` | M3B-4 — `rand_mode()`/`constraint_mode()` in all combinations |
| `m1b3_generic` | M1B-3 — the same shape the hardcoded `uvm_shared` fallback patches, under a different class name, works through the general path |
| `m6b4_nba` | M6B-4 — the NBA case that happens to be right, kept as the contrast to `m6b4_det` |

## Loud gaps (correct behaviour today, kept for the record)

`m13_3_config` and `m13_4_trireg` are unimplemented and say so with a sorry.
`m4c10_event_lifetime`, `m9_7_midseq_clock` and `m9_7_crossclock_overlap`
are a parse error and a sorry respectively. `m6b2b_syncregions` shows the
existing sync-region ordering (`cbReadWriteSynch` → `cbAtEndOfSimTime` →
`cbReadOnlySynch`, all after NBA settle); `cbNBASynch` is absent from
`vpi_user.h` entirely, so it cannot be registered at all.
