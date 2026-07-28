# Scope `std::randomize` Z3 closure — 2026-07-26

## Boundary

This campaign closes roadmap item M3B-10 for simple integral scalar and
packed-vector variables from 1 through 64 bits. It covers statement,
`void'(...)`, and expression calls, enum and automatic-local destinations,
runtime state references, SAT writeback, and UNSAT preservation. Arrays,
selected/container lvalues, and wider vectors remain loud unsupported forms.

## Pre-fix evidence

The discriminating regression failed six checks on the pre-fix installation:

- statement and expression constraints produced wrong values;
- signed and unsigned width cases produced wrong values;
- an unsatisfiable constraint returned success;
- the failed solve changed destinations.

The former parser implementation used a range/enum fast path and bounded
retry loop in statement position, while expression position warned once and
discarded the constraint. Neither was a general constraint solve.

## Implementation

The parser now preserves the with-clause AST for both call forms. Elaboration
maps each supported destination to a synthetic `p:N:W[:s]` solver token and
maps other identifiers to call-time value slots. One VVP operation invokes
the common constraint parser and Z3 optimizer, keeps one model per call, and
loads successful values for ordinary `%store/vec4` assignment. UNSAT skips
all stores.

Numeric IR carries literal width and signedness, which is required for full
64-bit writeback and correct enum/integral semantics. The full ivtest sweep
found that a signed decimal literal initially forced an unsigned property
comparison into signed mode; relational selection now uses signed predicates
only when both operands are signed, matching the mixed-sign rule.

## Durable coverage

`ivtest/ivltests/sv_std_randomize_with_solver.v` covers:

- exact and cross-variable statement constraints;
- expression and `void'(...)` forms;
- 64-bit, signed 8-bit, unsigned 16-bit, enum, and automatic-local values;
- runtime state references and a state value in an `inside` set;
- conditional and soft constraints;
- expression and statement UNSAT with multiple-destination preservation;
- an unconstrained control call.

The test was added to `ivtest/regress-sv.list`.

## Final integrated gates

- focused scope/class constraint cases: pass;
- `make check`: pass;
- constraint UVM group: 22/22, real DPI, zero skips;
- DPI group: 20/20, real DPI, zero skips;
- SVA dual-run: 36/36;
- ivtest name-diff: 3,218 total, exactly 44 documented failures, no drift;
- bundled VPI: 94/94;
- negative suite: 61/61;
- full UVM with real DPI: 226/226, zero failures, zero skips;
- installed/relocated `-uvm` front end: all eight scenarios passed.

These were rerun after rebasing onto `2e5eab5d8`, the merge of VPI
container-observability PR #123, so the evidence covers the integrated
runtime rather than the pre-merge branch.
