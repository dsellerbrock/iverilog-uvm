# IEEE 1800 rulings

Where IEEE 1800 leaves a behaviour open (no text, or text with two readings), or where it conflicts with what UVM
needs, the project owner rules and the ruling is recorded here. Explicit IEEE text needs no ruling: it wins. Eve, the
companion simulator, follows iverilog-uvm on unsettled points and keeps its own list in `docs/IEEE-AMBIGUITIES.md`.

**Adding a row.** The PR that implements a ruling adds its row (date, clause, issue, the question, the ruling, who
ruled). A provisional reading an agent built on before a ruling is marked "provisional" until the owner rules.

| Date | Clause | Issue | Question | Ruling | Decided by |
|---|---|---|---|---|---|
| 2026-11-06 | 6.16 | #733 | Is an integral -> string assignment legal without a cast? | No: enforce 6.16. Tests gain casts. | owner |
| 2026-11-06 | 6.22.2 | #826 | A typeless mailbox `get`/`peek` into a non-equivalent type | Run-time error (strict 6.22.2). | owner |
| 2026-11-06 | 6.21 | #752 | The static-initializer rule, which UVM code relies on breaking | Stays a WARNING, not an error. | owner (IEEE vs UVM) |
| 2026-11-06 | 16.12.4, 16.14.8 e) (SVA Q1) | #2720 (PR #2723) | When `P1 or P2` reports, and its vacuity | Reports when the truth is decided; nonvacuous iff a finished operand is nonvacuous. | owner |
| 2026-11-06 | 16.12.14 (SVA Q2) | #723 (PR #2725) | When asynchronous `accept_on`/`reject_on` resolve | At the next clock tick or change of the condition. | owner |
| 2026-11-07 | 31.9 | #890 | "Changing the smallest negative limit value to 0": most negative, or smallest magnitude? | Smallest magnitude (closest to zero). | owner |
| 2026-11-07 | IEEE 1497 / 30 | #900 | Are SDF LABEL values scaled by the SDF TIMESCALE? | No, written unscaled (a specparam need not be a time). | owner |
| 2026-11-10 | 20.11 (SVA Q3) | #863 | `$assertpassoff`/`failoff`/`vacuousoff` (and the On calls) on an attempt already in flight | Read when the action is dispatched; an in-flight attempt is not grandfathered, in either direction. | owner |
| 2026-11-10 | 39.5.1 (SVA Q4) | #1351 | VPI `vpi_control` action ops vs `$assertcontrol` | VPI action ops snapshot the action state per attempt (39.5.1's text); `$assertcontrol` keeps Q3. | explicit text |
| 2026-11-10 | 30.5.3, 30.6 | #2740 (PR #2951) | Delay of an output transition whose cause is not a path input | A change no path input caused is scheduled at now + the selected path delay. A path-caused change keeps the 30.6 max model. Path-caused means a path input changed since the previous output change arrived, not "in this time step" (the narrower reading breaks 30.6 Figure 30-4, where D->Q arrives 30 units after D). Corner case: a path input changes without moving the output, then a no-path input moves it; that counts as path-caused (the regression expects 100). Same as Eve. | owner |
| 2026-11-10 | 16.14.6, 20.11 (SVA Q5) | #2835 | A procedural assertion instance that has matured but waits for its leading clock, under `$assertoff`/`$assertkill` | Discarded under both; an instance that matures while Off is discarded at its clock. | owner |
| 2026-11-10 | 5.7.1 | #2365 | Width of an unsized decimal literal | Strict 32 bits is the default for `-g2017`/`-g2023` only; older generations stay lossless. | owner |
| 2026-11-10 | (non-IEEE `$psprintf`) | #670 | A trailing empty `$psprintf` argument | Accepted only under `-gcommercial-unsafe`. | owner |
| 2026-11-10 | 6.19.5 | #740 | Chained paren-less enum methods (`e.next.name`) | Accepted. | owner |
| 2026-11-10 | 23.3.2, 26.2 | #811, #817 | Repeated `.*` and missing module-instance parentheses (#811); a package item that refers to a compilation-unit item (#817): both accepted today | Strict error; a warning under `-gcommercial-unsafe`. | owner |
| 2026-11-10 | 6.7.1 | #819 | A 2-state type on a net or input port | Warning. | owner |
| 2026-11-10 | 22.2 (2023) | #953 | Compiler directives split across lines are accepted without a diagnostic | Left as is. | owner |
| 2026-11-10 | 20.6.1 | #791 | Does `$typename` carry the enclosing scope's prefix? | Yes, per 20.6.1: package, `$unit`, instance and class scope (`A::Cl::ct`); the `sv_typename1` gold is updated. | owner |
| 2026-11-10 | 37 VPI | #1310 | Emit `.vpi_contassign` records always or on demand? | Always (+0.7% VVP bytes on the sample, no run-time cost, existing lines unchanged). | supervisor |
| 2026-11-12 | 37.28, 23.10 | #1290 | A parameter default's `vpiExpr` refers to another, overridden parameter: which value does it read? | The declaring instance's values, after overrides, as elaboration uses them (23.10): in `m #(.P(10)) u2`, `Q = P + 1` reads 11, not 2. Shipped in PR #2839. | owner |
| 2026-11-10 | 18.4 | #2535 | A grown leaf of a nested dynamic array during resize | 18.4 is explicit; the test's "grown leaf kept" check is dropped. | explicit text |
| 2026-11-10 | 25.6 | #2804 (part B) | Which readers of a delayed path see the delayed value | Same reading as Eve's mppath ruling: the modport-path reader sees the undelayed shadow, other readers the delayed value. | supervisor (consistency with Eve) |
| 2026-11-11 | 16.14.6 (SVA Q6) | #1192 | Order of same-tick action blocks of one procedural assertion | Strict enqueue order (a sequence number per slot), not slot order. | owner |
| 2026-11-12 | 18.14 | #2926 | May a solver speed-up change the random stream of under-cap solves? (Stream stability across simulator versions is not an IEEE requirement.) | No: keep under-cap random streams stable (Eve compares rand output against this simulator). | supervisor |
| 2026-11-12 | 39.5.2, 39.4.2 (SVA Q7) | #1348 | Does `vpiAssertionEnableStep` issued in an attempt's own `cbAssertionStart` callback come "before the attempt has started"? | Yes: an EnableStep/DisableStep matching the attempt's start time, issued no later than that attempt's `cbAssertionStart` (or earlier), applies; later ones have no effect. One step = one clock tick of one attempt. Step callbacks are off until enabled, so `m12_assert_step`'s gold changes. | owner |
| 2026-11-12 | 18.5.9 (2023), 18.5.10 (2017) | #832 | A non-rand `solve ... before` target, and a circular ordering: today silent / a warning that is ignored | Both are errors ("Only random variables are allowed ... There shall be no circular dependencies"); a warning under `-gcommercial-unsafe`, as #811/#817. | explicit text + #811 precedent |
| 2026-11-12 | 18.5 | #1446 | Side-effect operators (`++`, `=`) in a constraint | Compile-time error; 18.5 forbids them. | explicit text |
| 2026-11-12 | 38.36.3 | #2897 (PR #2920) | Does `cbTchkViolation` run before or after the notifier toggle and the `$display` report? | After both, in the same statement block; the callback receives the timing-check handle. Proposed by timing-sdf; ruled by the owner 2026-11-12. | owner |
| 2026-11-12 | 38.6, 40.5 | #886 | `vpi_get(vpiToggleCoverage, module)` on an uninstrumented coverage type: an error, or just off? | Returns 0 (coverage off) with no `vpi_chk_error`; the text does not require an error. Proposed by vpi-solver; ruled by the owner 2026-11-12. | owner |
| 2026-11-12 | 36.12.2.2 | #1255 | Default VPI compatibility mode | Keep the current default (1800-2023 objects); no selector unless Eve needs one. Proposed by vpi-solver; ruled by the owner 2026-11-12. | owner |
| 2026-11-12 | 39.4.2 | #1348 (P8-P13) | Step-report details 39.4.2 leaves open | P8 state ids: fixed-shape checker, the state after tick of age a is a+2; automaton state j is j+2 (0 origin, 1 accept). P9 the tick reaching accept is a StepSuccess with stateTo=1. P10 an implication whose antecedent stops matching ends vacuously: a StepSuccess into state 1, with the failing antecedent boolean listed last. P11 several edges in one tick still give one step: an edge into accept first, else the edge from the lowest state id; a dying attempt reports its lowest active state's first guarded edge, ending with the failing guard. P12 `vpi_control` Enable/DisableStep returns 1 when it applies, 0 when too late (Q7) or the form cannot step. P13 forms with no per-attempt record (merged `##[m:$]` wait, `not`, cover, endpoint fan-out, fixed shapes over 255 ticks) refuse stepping with a runtime sorry. Proposed by sva-attempts; ruled by the owner 2026-11-12. | owner |
| 2026-11-12 | 39.4.2 b) | #1348 (P14) | "Placing a step callback results in the same callback function being invoked for both success and failure steps": does a callback registered for one reason also fire for the other? | Not yet: a callback fires only for the reason it was registered for (the literal reading makes a test that registers both reasons see every step twice). Proposed by sva-attempts; ruled by the owner 2026-11-12. A sub-issue follows. | owner |

## Process rulings

| Date | Ruling | Decided by |
|---|---|---|
| 2026-11-06 | No MSYS2/Windows job in PR checks (too slow); the static check `ci/check-win-posix.py` (PR #2714) instead. | owner |
| 2026-11-07 | New VVP record kinds use distinct record namespaces per agent and are emitted only when the design needs them. | supervisor |
