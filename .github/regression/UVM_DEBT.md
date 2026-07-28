# Full-UVM debt tracker (cost-aware regression system)

Full UVM last passed: object-randomize statement-with head (226/226, real
DPI, zero skips, 2026-07-27). This validates the new parser productions and
the shared expression/statement randomize-with elaboration path across the
whole UVM suite. Previous full run at R11-closed head (222/222, 4x~55
batches, 2026-07-25 — three new runtime opcodes
(%load/preponed/av, %load/preponed/real, %hist/on/av) plus per-word history
on every unpacked array and history on every real wire. The array history
hooks __vpiArray::set_word, which every unpacked-array write in every design
goes through, so a mistake there would be broad rather than narrow.
Previous full run, same result, at
M9-7 D.4 + R4 + R11 + R2 head —
2026-07-25 — one run over the whole batch. The Observed-region move (R2) is
what earns it: EVERY concurrent assertion in every design now suspends into
a different scheduler region before evaluating, so a mistake there would
change verdicts broadly. The process-identity fix (R4) is the second reason
— UVM leans on process::self() throughout. An earlier run of this batch was
discarded and redone: the install was replaced mid-run, so its result
described no single compiler. Previous full run, same result, at
convergence head —
validated DELETING the uvm_shared/value/T type-inference fallback (R9). The
run is the evidence, not a formality: the fallback only ever fired for UVM's
own parameterized wrapper, so UVM is the only thing that could have depended
on it, and the roadmap row required exactly this run to close. Previous full
run, same result, at M9-7 D.3 head —
validated a parse.y grammar addition plus changes to the multiclock
assertion lowering. The grammar change is the reason a full run was needed
rather than a subset: a new production in sva_seq_expr affects how every
source file is parsed, not just multiclocked ones. Conflict baseline
unchanged at 494 s/r + 1161 r/r. Previous full run, same result, at R1 head —
validated the Preponed-sampling change to $ivl_clocking_sample elaboration.
Every concurrent-assertion operand in every design passes through that code,
and a select operand's value now comes from a different simulation region
than before, so a wrong rewrite would change assertion verdicts broadly
rather than narrowly. Previous full run, same result, at M9-10 head —
validated the assertion-lowering scope fix. Concurrent assertions inside a
procedural begin/end were silently dropped; they now run, so any such
assertion in UVM changes from inert to live. That can only be shown by a
full run, and it is the reason a full run was mandatory here rather than a
subset. Also covers the pform_make_assertion park path, which every
assertion in every design now passes through.)

Commits since full UVM: 0
Highest risk change since last full run: —

Triggers for a full run (see docs/conformance/REGRESSION_POLICY.md):
  - HIGH-risk commits since last full UVM >= 2
  - stable commits since last full UVM >= 8
  - before milestone COMPLETE / major PR merge / architecture change
