# CURRENT WORK — continuation state

This is the short resume state. `ROADMAP.md` is the living tracker,
`iverilog_ieee1800_uvm_manifesto.md` carries policy, and dated technical
narratives live in `session_logs/`.

## Resume state — 2026-07-26

Branch: `codex/vpi-container-observability`, based on the merge of
PR #122 (`d0d51c226`).

The VPI runtime-container observability campaign is closed:

- queue, dynamic-array and associative-array class properties expose a
  live `vpiArrayVar` surface with declared/live kind, current size,
  member/index iteration, and typed int/string/real element access;
- VPI element writes update the SystemVerilog object;
- member handles stay live across owner replacement and container growth;
- `cbValueChange` on direct and class-property container elements fires
  immediately for both SV and VPI writes;
- per-element snapshots prevent a mutation elsewhere in the same class
  object from spuriously firing sibling callbacks.

Discriminating pre-fix evidence:

- `m12_container_props` produced 36 deterministic failures: property
  queues appeared empty, dynamic arrays looked like 64-bit class
  variables, associative arrays had the wrong kind, element handles were
  null, typed/nested properties were missing, writes had no effect, and
  saved handles did not follow owner replacement;
- `m12_container_cb` produced three deterministic failures, including a
  null class-property element and callbacks that registered but never
  fired.

The root causes were split across metadata, handle adaptation, callback
routing and mutation notification. Dynamic-array properties had been
serialized as generic objects; class members exposed only static property
metadata; a runtime word callback cast its parent to the static-array
implementation; associative stores did not notify the owning object; and
class-root notifications required element-level filtering.

Final gates:

- focused property/callback family: pass;
- `make check`: pass;
- negative suite: 61 passed, 0 failed;
- SVA dual-run: 36 passed, 0 failed;
- vendored ivtest: 3,217 total, exactly 44 expected failures and no
  failure-identity drift;
- bundled VPI: 94 passed, 0 failed;
- dedicated DPI subsystem with real DPI: 20 passed, 0 failed, 0 skipped;
- full UVM with real DPI: 226 passed, 0 failed, 0 skipped;
- installed/relocated `-uvm` frontend: all eight scenarios passed.

The macOS run also exposed `mapfile` in the targeted-subsystem helper; it
now de-duplicates with Bash 3.2-compatible array handling.

Detailed implementation and pre-fix evidence:
`session_logs/2026-07-26_vpi_container_observability.md`.

The public VPI status remains **substantial**, not FULL. Whole-container
class-property writes and detailed assertion sub-expression/
variable-latency attribution remain documented boundaries.
