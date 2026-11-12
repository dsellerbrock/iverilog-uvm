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
| 2026-11-06 | 16.12.4 (SVA Q1) | | When `P1 or P2` reports, and its vacuity | Reports when the truth is decided; nonvacuous iff a finished operand is nonvacuous. | owner |
| 2026-11-06 | 16.12.14 (SVA Q2) | | When asynchronous `accept_on`/`reject_on` resolve | At the next clock tick or change of the condition. | owner |
| 2026-11-07 | 31.9 | #890 | "Changing the smallest negative limit value to 0": most negative, or smallest magnitude? | Smallest magnitude (closest to zero). | owner |
| 2026-11-07 | IEEE 1497 / 30 | #900 | Are SDF LABEL values scaled by the SDF TIMESCALE? | No, written unscaled (a specparam need not be a time). | owner |
| 2026-11-10 | 20.11 (SVA Q3) | #863 | `$assertpassoff`/`failoff`/`vacuousoff` (and the On calls) on an attempt already in flight | Read when the action is dispatched; an in-flight attempt is not grandfathered, in either direction. | owner |
| 2026-11-10 | 39.5.1 (SVA Q4) | #1351 | VPI `vpi_control` action ops vs `$assertcontrol` | VPI action ops snapshot the action state per attempt (39.5.1's text); `$assertcontrol` keeps Q3. | explicit text |
| 2026-11-10 | 30.5.3 | #2740 | Delay of an output transition whose cause is not a path input | Scheduled at now + the selected path delay; the 30.6 max model applies when a path input changed. Same as Eve. | owner |
| 2026-11-10 | 16.14.6, 20.11 (SVA Q5) | #2835 | A procedural assertion instance that has matured but waits for its leading clock, under `$assertoff`/`$assertkill` | Discarded under both; an instance that matures while Off is discarded at its clock. | owner |
| 2026-11-10 | 5.7.1 | #2365 | Width of an unsized decimal literal | Strict 32 bits is the default for `-g2017`/`-g2023` only. | owner |
| 2026-11-10 | (non-IEEE `$psprintf`) | #670 | A trailing empty `$psprintf` argument | Accepted only under `-gcommercial-unsafe`. | owner |
| 2026-11-10 | 6.19.5 | #740 | Chained paren-less enum methods (`e.next.name`) | Accepted. | owner |
| 2026-11-10 | | #811, #817 | (see issues) | Strict error; a warning under the unsafe flag. | owner |
| 2026-11-10 | 6.7.1 | #819 | A 2-state type on a net or input port | Warning. | owner |
| 2026-11-10 | | #953 | (see issue) | Left as is. | owner |
| 2026-11-10 | 20.6.1 | #791 | Does `$typename` carry the package prefix? | Yes, per 20.6.1; the `sv_typename1` gold is updated. | owner |
| 2026-11-10 | 37 VPI | #1310 | Emit `.vpi_contassign` records always or on demand? | Always (+0.7% VVP bytes on the sample, no run-time cost, existing lines unchanged). | supervisor |
| 2026-11-10 | 37 VPI | #1290 | A parameter default's `vpiExpr`: evaluated where, and before or after overrides? | In the declaring instance, after overrides. **Provisional** (vpi-solver), not yet ruled by the owner. | provisional |
| 2026-11-10 | 18.4 | #2535 | A grown leaf of a nested dynamic array during resize | 18.4 is explicit; the test's "grown leaf kept" check is dropped. | explicit text |
| 2026-11-10 | 25.6 | #2804 (part B) | Which readers of a delayed path see the delayed value | Same reading as Eve's mppath ruling: the modport-path reader sees the undelayed shadow, other readers the delayed value. | supervisor (consistency with Eve) |
| 2026-11-11 | 16.14.6 (SVA Q6) | #1192 | Order of same-tick action blocks of one procedural assertion | Strict enqueue order (a sequence number per slot), not slot order. | owner |
| 2026-11-12 | 18.5.9 | #2926 | May a solver speed-up change the random stream of under-cap solves? | No: keep under-cap random streams stable (Eve compares rand output against this simulator). | supervisor |
| 2026-11-12 | 39.5.2, 39.4.2 (SVA Q7) | #1348 | Does `vpiAssertionEnableStep` issued in an attempt's own `cbAssertionStart` callback come "before the attempt has started"? | Yes: an EnableStep/DisableStep matching the attempt's start time, issued no later than that attempt's `cbAssertionStart` (or earlier), applies; later ones have no effect. One step = one clock tick of one attempt. Step callbacks are off until enabled, so `m12_assert_step`'s gold changes. | owner |

## Process rulings

| Date | Ruling | Decided by |
|---|---|---|
| 2026-11-06 | No MSYS2/Windows job in PR checks (too slow); the static check `ci/check-win-posix.py` (PR #2714) instead. | owner |
| 2026-11-07 | New VVP record kinds use distinct record namespaces per agent and are emitted only when the design needs them. | supervisor |
