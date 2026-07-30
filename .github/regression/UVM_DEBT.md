# Full-UVM debt tracker (cost-aware regression system)

Full UVM last passed: Recovery Campaign 3 head (229/229, real DPI, zero
skips, 2026-07-30, re-run at every wave and finally on the exact
five-wave tree in one uninterrupted ladder). What earns the run: the
campaign rewires container value semantics (%store/qobj/obj + the
element copy policy touch every whole-container assignment), struct
member-path elaboration (check_for_struct_members and the method-call
walk now take class hops -- every a.h.v read and a.q.push_back call
routes differently), static-property signal SHAPE (array-typed static
properties are now real arrays -- every class with a static array
property elaborates differently), and the packed assignment-pattern
arity check (two silent-accept hatches removed -- every packed pattern
re-validates). Each is a HIGH-risk category on its own. One earlier
full run of wave 4 was DISCARDED and redone: the install tree was
replaced mid-run (same failure mode as the R2-era discarded run below),
so its result described no single compiler.
Previous recorded pass: Recovery Campaign 2 head (229/229, real DPI, zero
skips, 2026-07-30 — includes the new phase_hook_count_test). What earns
the run: the campaign changes virtual-method dispatch flagging (every
class method call in every design) and the ref-formal binding runtime
(vvp_ref_signal_aa carries a tagged binding now), both HIGH-risk
categories. NOTE (recovery audit, 2026-07-30): between the previous
recorded pass (PR #126 head, 2026-07-27) and this one, ~60 commits and
11 merges (#129-#140) landed WITHOUT this file being updated, including
parse.y grammar, vthread.cc scheduler and vvp_cobject representation
changes that the policy's own trigger table treats as mandatory-full-run
categories. The C1 (#140) and C2 heads did get full runs (228/228 and
229/229 respectively) — they were just never recorded here. Keep this
file honest or the policy's automatic trigger cannot fire.
Previous recorded pass: object-randomize statement-with head (226/226,
real DPI, zero skips, 2026-07-27). This validates the new parser productions and
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

Commits since full UVM: 0 (Campaign 3 final ladder ran on the exact tree)
Highest risk change since last full run: —

Triggers for a full run (see docs/conformance/REGRESSION_POLICY.md):
  - HIGH-risk commits since last full UVM >= 2
  - stable commits since last full UVM >= 8
  - before milestone COMPLETE / major PR merge / architecture change
