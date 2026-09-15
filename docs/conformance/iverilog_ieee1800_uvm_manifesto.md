# Icarus Verilog IEEE 1800 / UVM Conformance Manifesto

## Purpose

This document is the governing correctness and conformance policy for the `dsellerbrock/iverilog-uvm` fork.

Its goals are:

1. Implement broad, measurable IEEE 1800-2017 and IEEE 1800-2023
   conformance as two first-class selectable language editions.
2. Run the unmodified Accellera UVM reference implementation and make
   representative OpenTitan and Caliptra RTL/DV flows practically usable
   without source patches that hide compiler defects.
3. Target source, run-time, DPI, and VPI interoperability with the commercial
   RTL/DV ecosystem represented by VCS, Questa, and Xcelium wherever their
   behavior agrees with IEEE 1800.
4. Eliminate silent miscompiles and make every support claim evidence-based
   and falsifiable.
5. Build a standards-correct, typed, formal-ready frontend and assertion IR;
   a proof engine is a later program, not a present capability claim.
6. Defer UPF/IEEE 1801 and other adjacent standards until the IEEE 1800
   language, elaboration, simulation, and verification surfaces are
   substantially closed.

Passing UVM, OpenTitan, or Caliptra is valuable application evidence. None is
proof of full IEEE 1800 conformance.

A milestone is not complete because unsupported corners are documented. A milestone is complete only when its defined scope is implemented, tested, and free of known in-scope gaps.

---

## Documentation authority

This is the Level 1 constitution: mission, correctness policy, and completion
requirements. [AGENTS](../../AGENTS.md) defines the operational workflow.
[The documentation index](../README.md) identifies the owner of each live
status or usage topic. The [blocker registry](BLOCKERS.md) is the backlog;
[ACTIVE_WORK](../../.ai/ACTIVE_WORK.yaml) authorizes the selected implementation.

Historical milestone plans and implementation checkpoints are retained in the
[planning archive](session_logs/2026-09-14_manifesto_planning_archive.md).
They do not set current status, implementation scope, or publication authority.

## Strict honesty policy

Name the exact scope of a completion claim. Completing a tested subset leaves
the surrounding clause open when other required semantics are missing. Use
[conformance status rules](#conformance-status-rules) for standards labels;
old milestone terms remain in historical records only.

Never use `CLOSED` or `FULL` merely because UVM passes, a representative test passes, unsupported forms emit `sorry`, a recorded-corners ledger exists, no silent miscompile is currently known, or the parser accepts the construct.

A loud diagnostic is better than a silent miscompile, but it is still unsupported functionality.

---

## Normative sources

Use sources in this order:

1. The selected edition of IEEE 1800: 2017 in `-g2017` mode and 2023 in
   `-g2023` mode, including published errata applicable to that edition.
2. Reduced positive, negative, and interaction reproducers tied to the
   governing clause and subclause.
3. The unmodified Accellera UVM reference implementation and unchanged
   OpenTitan and Caliptra sources as application conformance witnesses.
4. VCS, Questa, and Xcelium behavior as practical commercial interoperability
   evidence after the IEEE text; disagreement must be recorded rather than
   resolved by majority vote.
5. Slang as a parser/elaboration differential and independent diagnostic
   cross-check.
6. Existing regression evidence and dated application matrices.

Verilator is useful diagnostic evidence, but it is not the language, run-time,
or Annex-H ABI oracle for this project. Never invent clause semantics from
memory or infer standards completeness from one simulator.

For each feature, identify the relevant clause and subclause; record syntax, semantics, typing, scheduling, VPI/DPI implications; and add positive, negative, and interaction tests where applicable.

---

## Core engineering principles

### 1. Fix the simulator, not UVM

When UVM exposes a failure:

1. preserve the original UVM failure;
2. reduce it to pure SystemVerilog;
3. identify the real compiler/runtime defect;
4. implement the general language behavior;
5. preserve the reduced test;
6. rerun unmodified UVM.

Do not add identifier-based UVM special cases.

### 2. Eliminate silent miscompiles first

Priority order:

1. silent wrong behavior;
2. compiler crashes and assertions;
3. runtime corruption;
4. scheduler races;
5. known UVM semantic blockers;
6. loud unsupported features;
7. rare syntax completeness.

Unsupported behavior must be implemented correctly, rejected explicitly, or intentionally lowered with documented standards-justified semantics.

### 3. Parsing is not support

A feature is supported only when all relevant layers work: preprocessing, parsing, name resolution, typing, elaboration, lowering, code generation, runtime, scheduling, VPI/DPI where applicable, and durable tests.

### 4. Prefer architecture over patch accumulation

Repeated failures involving type reconstruction, parameterized classes, aggregate lvalues, method dispatch, event scheduling, assertion execution, or container access must trigger architectural fixes rather than local workarounds.

### 5. Preserve working behavior through characterization tests

Do not rewrite large subsystems blindly. Characterize, test, migrate incrementally, and remove legacy paths only when equivalent behavior exists.

---

## Architectural requirements

Preserve these invariants when simplifying or extending the implementation:

- **Types and values:** retain exact type, signedness, width, unpacked dimensions,
  two/four-state identity, enum and class specialization, lvalue category,
  aggregate layout, constant-expression status, and source location through
  resolution, elaboration, and lowering. Define ownership and lifetime;
  diagnose unsupported shapes. Migrate incrementally with characterization tests.
- **Scheduling:** map each path to its runtime API, IEEE region, and permanent
  test. Cover Active, Inactive, NBA, Observed, Reactive, Re-Inactive, Re-NBA,
  Postponed, programs, assertion sampling/evaluation, clocking sampling/driving,
  events, VPI callbacks, DPI suspension/resumption, cleanup, and finalization.
  Region ownership and race-sensitive tests are required before claiming closure.
- **Containers:** preserve declared kind, bounds, element identity, independent
  value copies, reference identity where required, and mutation ownership across
  indexing, slicing, iteration, resizing, copying, comparison, sorting,
  reductions, locators, assignments, VPI, and DPI. Optimization must preserve
  argument effects, formal lifetime, and copy-back. Validate malformed runtime
  metadata before execution. Compatibility extensions remain explicitly bounded.
- **Class identity:** retain concrete/base type, specialization, property and
  virtual-method descriptors, cast relationships, factory names, and VPI metadata.
- **Formal boundary:** simulation assertions and constrained-random Z3 solving
  are not a hardware model checker. A future proof backend needs a defined
  supported profile, initial/transition relations, property/assumption lowering,
  counterexamples, replay, and soundness qualification.

Implementation records and outstanding forms belong in the clause matrices
and blocker registry, not in this policy.

## Conformance status rules

Use `UNASSESSED`, `UNSUPPORTED`, `PARTIAL`, `IMPLEMENTED`, or `QUALIFIED`.
`IMPLEMENTED` is not `QUALIFIED`. Old `FULL`, `DIAGNOSED`, and `PROVISIONAL`
labels in retained evidence do not certify completeness. Known missing
semantics, crashes, or silent wrong answers prevent qualification of the
containing scope. Positive, negative, and interaction evidence is required.
Each edition and each application goal needs its own explicit disposition.

## Definition of done

A feature is complete only when:

1. governing clause identified;
2. syntax implemented;
3. illegal forms diagnosed;
4. names resolve correctly;
5. exact types preserved;
6. elaboration correct;
7. runtime correct;
8. scheduling correct where applicable;
9. VPI defined where applicable;
10. DPI defined where applicable;
11. positive tests pass;
12. negative tests pass;
13. interaction tests pass;
14. UVM regression passes where applicable;
15. broader regression remains baseline-clean;
16. conformance documentation updated;
17. no known in-scope corner remains hidden behind a completion label;
18. both `-g2017` and `-g2023` have an explicit, tested disposition where the
    feature is shared or edition-sensitive;
19. unchanged UVM, OpenTitan, and Caliptra application gates are rerun where
    the feature is on their path, with every remaining failure classified;
20. work is committed and pushed.

---

## Final principle

The goal is not to produce the appearance of completeness.

The goal is measurable conformance.

Every support claim must be tied to a standard clause, real implementation, permanent tests, regression evidence, and honest remaining limitations.

When reality and milestone wording disagree, change the milestone wording.
