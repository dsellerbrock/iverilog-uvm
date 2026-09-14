# L59 — Runtime assignment-expression destination conversion

Assignment expressions into two-state variables retained X/Z bits in both
the stored value and expression result. A dynamic `bit [3:0]` assignment
from `4'bx101` stored X and returned 0X instead of 5 and 05. IEEE 1800-2017
and 1800-2023 11.3.6 require destination conversion before storage and return;
6.11.2 requires unknown/high-impedance bits to become zero in two-state types.
The local normative extracts are in `evidence/dd018-assessment/`.

The VVP target now emits the existing `%cast2` operation in the common
assignment-expression path, before duplicating the result for the store.
Four-state destinations retain their four-state values. No runtime opcode,
new abstraction, application-source change, or remote action was needed.

## Focused evidence

Evidence root: `evidence/runtime-assignment-conversion-assessment/`.

- Original delayed module-level runtime reproducer fails both editions.
- Independent operator matrix: four widths/types, twelve plain/compound
  forms, both editions. Baseline 8/96; corrected 96/96, exact clean output,
  stable compiler/target/runtime hashes. Includes signed byte result extension
  and 128-bit storage and return values. Expected values are manually derived.
- Permanent test pins plain X/Z conversion, arithmetic, bitwise and shift
  compounds, nested assignments, signed widening, wide vectors, integer atom,
  four-state preservation, and exactly one RHS call.
- Incremental target build/install exit 0; focused legacy 2/2 and JSON 4/4.
  Existing assignment-expression, rejected syntax/select, and L58 constant
  neighbors pass 8/8 paired runs. No broad suite was run.

Compiler SHA-256: `d745779660da40278f77fa5e5418faca6755c03bebe1d80e7b3cd841b9d21386`.
Target: `1e77610a23f5285f0a3e19cf26c261a099f03a7ad52b86287caa9f9b421ceac3`.
Runtime: `cee0a60c11c7d401646159701e2d341932a6812a4e5199fed18f6cda516d9e2f`.

## Integration and remaining scope

Local integration is pending. Six focused features precede L59 in the current
batch. Broad qualification remains deferred until approximately ten features;
`c686a4781` remains the last broadly qualified semantic revision.
M4C-22 is reopened to PARTIAL pending batch qualification: its earlier
conversion claim missed these X/Z cases. Existing lvalue restrictions remain
explicit; DD-027 runtime fixed-array increment/decrement remains open.
The same lower-model worker and retained checkout were reused.
