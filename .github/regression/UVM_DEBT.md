# Full-UVM debt tracker (cost-aware regression system)

Full UVM last passed: R1 head (222/222, 4x~55 batches, 2026-07-25 —
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
