# 2026-07-17 — Frontier: assertion control + DPI-export/multidim findings

Directive: "continue on the outlined frontier" (DPI export → multidim
open arrays → M9D automaton → M12B → M1B). This entry records one
implemented increment and two rigorous "why this is blocked" findings
that correct the roadmap.

## Implemented — assertion control (IEEE 1800-2017 20.12)

`$asserton` / `$assertoff` / `$assertkill` were undefined. Implemented as
a global enable flag gating the synthesized concurrent-assertion
checkers' failure actions:

- `vpi/sys_sva.c`: a global `sva_assert_enabled` (default 1), the query
  function `$ivl_sva_enabled()` (returns the flag), and the three
  control tasks (`$asserton` sets it, `$assertoff`/`$assertkill` clear
  it). Registered alongside the existing `$rose`/`$past`/… systf.
- `pform.cc`: a new `sva_gate_(action)` wraps every fail-dispatch action
  in `if ($ivl_sva_enabled()) …`, applied at all fail sites — the main
  concurrent-assertion dispatch, the `until` monitor, `within`, the
  liveness `nexttime` per-cycle check, and the strong end-of-simulation
  `$error` blocks. Gating the *action* (not the whole checker) keeps the
  token/pipeline state advancing, so `$asserton` resumes cleanly.

Scope: global. The optional `[levels, list]` scope-selection arguments
are accepted but treated globally; `$assertkill`'s in-flight-attempt
reset is not modeled (it behaves as `$assertoff`). The enable flag
defaults on, so every existing assertion behaves identically.

Test `m9e_assert_control_test`: an `a |-> b` assertion with `b` low fails
every cycle; failures accrue while ON, freeze on `$assertoff`, resume on
`$asserton`, and freeze again on `$assertkill`.

## Finding — DPI export is architecturally blocked

`export "DPI-C" function/task` is a parse-time sorry. Making it real is
**not a next increment**; it is blocked on two things vvp does not have:

1. **A C-linkable symbol.** A separately-compiled DPI library calls the
   exported subroutine as `extern int foo(int);` — the dynamic linker
   must bind `foo` to something the simulator provides. A compiled
   simulator emits a C function for each export; vvp is an interpreter
   and cannot synthesize an arbitrarily-named C symbol for the loader to
   bind at `.so` load time.
2. **Synchronous SV execution from a C callback.** Even given a symbol,
   running the exported SV subroutine from inside a C call requires the
   scheduled-call / function-atomicity protocol that the M6B ledger
   already records as the large, risky, currently-disabled
   `IVL_SCHED_CALLF` item (13.4.3). DPI export sits directly on top of
   that unsolved rearchitecture.

Recommendation: keep DPI export behind its loud sorry until the
synchronous-call protocol lands; do not treat it as a small task.

## Finding — multidim open arrays need non-contiguous access

The DPI open-array path (`'o'`, `dpi_raw_data()`) assumes **contiguous
atom storage** and a flat 1D descriptor (`svDimensions` returns 1). A
2-D unpacked dynamic array in vvp is a `vvp_darray_object` — an array of
inner dynamic arrays, i.e. **non-contiguous**. Multidimensional open
arrays therefore require either a nested `svGetArrElemPtr2/3` access path
that walks the object structure, or a copy into a contiguous canonical
buffer with copy-back — a real feature, not a descriptor tweak, and one
of narrow practical demand.

## Roadmap correction

Of the outlined frontier, the two DPI items are large/blocked (above),
and the M9D automaton features (local variables, `.matched`, `expect`,
goto/nonconsecutive repetition) need an automaton-based sequence engine
rather than the current flat linear chain. The tractable, high-value
increment this pass was assertion control. The next genuinely bounded
items are **M12B** (assertion VPI object identity — enumeration first)
and pieces of **M1B** (semantic-IR remediation); the rest are multi-
session rearchitectures.

## Regression gate

UVM 177/177 (zero no-check), ivtest baseline-identical, negative 32/32.
