# L86 — Bounded delay-window multiclock antecedents

Two-clock implications now retain every endpoint of finite constant delay
windows in otherwise fixed antecedents, including internal windows and fixed
first-clock consequent prefixes. Each source start keeps one parent identity.
A failed child reports one parent failure immediately; success waits for
antecedent closure and all children. Vacuous closure does not wait for a
destination edge, and cover property actions remain once per successful
attempt, including vacuous attempts.

The source uses the existing finite acyclic NFA builder, then transports
parent-tagged lifecycle and child records through generated associative
storage. Observed-region aggregation and the existing Reactive dispatch retain
sampling and action timing. Prefix children preserve the source parent while
waiting for their destination-clock handoff. Two producer-owned reclamation
cursors release completed lifecycle records past pending children without
removing child records before both consumers have acknowledged them.

Kill/restart needed separate source and destination epoch handling. A lazy
reset now retains records created after restart, including a START emitted on
the first new-epoch source tick. Disable pulses still cancel the old attempts.
These cases initially lost fresh verdicts; the failed reducers are preserved.
Fixture mistakes involving an unimplemented convenience control task and
incorrect clock times were corrected from existing controls and IEEE timing,
without changing the parent verdict oracle.

Applicable IEEE1800-2017 and2023 clauses are16.6/16.7 (Boolean and sequence
semantics),16.12.7 (implication),16.13 (clock flow),16.14.1/.3 (actions and
coverage), and20.12 (assertion control). Delay-window scope retains the existing
64-tick frontend limit. Repetition, empty-match extensions, general operators,
locals and broader multi-domain shapes remain separate; S02's consecutive
repetition reducer is still rejected.

Forty-six cases pass in each harness. They cover internal/zero/equal/maximum
delay ranges, both implication forms and coincident source orders, first-clock
prefixes, overlapping parents, early failure and source-clock closure,
vacuity, cover, disable pulses, kill/restart, invalid bounds and retention.
A paused-clock check queues128 parents and384 child obligations, then requires
exactly128 successful parent actions when the destination resumes. White-box
storage checks additionally verify that roughly1000 completed vacuous attempts
do not accumulate behind pending children. The existing multiclock-kill
neighbor and all58 NFA compatibility cases pass. See the
[validation record](2026-09-15_multiclock_bounded_antecedents_validation.json)
for exact commands, hashes and initial failures.

These are focused results. Broad batch qualification remains pending near ten
integrated fixes; no new whole-application or full-SVA qualification is claimed.
