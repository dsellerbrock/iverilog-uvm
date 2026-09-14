# L57 — Receiver task resolution and diagnostics

Unresolved dotted/indexed task calls could compile into empty blocks. Calls
with familiar UVM/TLM names could also bypass real method lookup, and
collection names such as `delete` accepted integer class members. This
silently discarded intended effects and accepted invalid programs.

The compiler now preserves ordinary task, function, method, built-in, and
named constraint lookup, then diagnoses missing receivers or methods.
Name-only UVM/TLM and multi-hop collection stubs are removed. Existing
method errors stop further fallback attempts. Real methods named `write`,
`reset`, `mirror`, or `get_fields` follow their declarations and retain effects.
The source change removes substantially more code than it adds.

IEEE 1800-2017 and IEEE 1800-2023 are tracked independently. Authority:
13.3 (task declarations/calls), 23.6/23.8.1 (scope and hierarchical name
resolution), with 18.6.2 implicit randomization hooks and 18.9 constraint
mode controls retained by their dedicated implementations. Deferred receiver
handling remains limited to unspecialized type-parameter templates; concrete
specializations must resolve real calls or diagnose invalid ones.

## Focused validation

- Permanent focus: 9/9 legacy, 10/10 JSON, both terminal status 0. Logs:
  `evidence/unresolved-task-assessment/l57/final-legacy-2.log` and
  `final-json-2.log`. The negative golden pins each invalid call diagnostic;
  the positive asserts exact direct/indexed/nested effects, constraint-mode
  argument evaluation, and nested queue contents.
- Independent final root controls: 40/40 paired outcomes in
  `l57-root/final-results.json`, with stable compiler/target/runtime hashes.
  Missing receiver/method/scalar collection calls reject normally; real named
  methods, constraints, and queue methods retain their effects.
- Independent specialization/hook neighbors: 12/12 paired outcomes in
  `l57-root/specialization-neighbor-results.json`. A concrete task forwarder
  increments its receiver exactly, invalid/default-int specializations reject,
  and implicit/overridden hook behavior and invalid hook arguments remain sound.
- Original receiver corpus: 20/20 appropriate outcomes on the preceding
  corrected candidate (`l57-root/original-corrected-results.json`). The final
  source additionally removes the untyped collection-name fallback.
- `git diff --check` passes. Installed compiler SHA-256: `b646b0f33501c55f2646adaa21bf58ef3234af78cca994245ca28812d3bf2cb5`.

No broad suite was run. L53–L56 provide four focused batch items; L57 is
the fifth, integrated into local main at `e025a775d`. The last full qualification remains
`c686a4781`; larger UVM/application effects will be checked at the requested
approximately-ten-feature gate. No UVM or application source was modified,
no remote action was taken, and the same worker and worktree were reused.

In parallel, DD-025 was reduced to 15 local scalar assignment/inc-dec forms:
30/30 runtime controls pass, all 30 constant invocations fail across the two
editions. That separate constant-function feature remains queued.
