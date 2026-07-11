# Icarus Verilog IEEE 1800 and UVM Implementation Manifesto

## Purpose

This document is the governing implementation plan for extending the `dsellerbrock/iverilog-uvm` fork toward robust Accellera UVM compatibility and broad IEEE 1800 SystemVerilog conformance.

It must be treated as the project's implementation Bible.

The project has two related but distinct goals:

1. Run the Accellera UVM reference implementation reliably and without simulator-specific edits.
2. Implement the IEEE 1800 language and simulation semantics systematically enough that support can be measured clause by clause.

Passing UVM is application-level evidence. It is not proof of full IEEE 1800 conformance.

---

## Current assessment

The fork is substantially beyond stock Icarus Verilog in several UVM-critical areas, including:

- Class and parameterized-class handling
- Constraint and randomization work
- String methods
- Queue and array methods
- Covergroup/bin APIs
- Fork/join scheduling fixes
- VVP runtime fixes
- UVM-specific regressions and compatibility work

The fork already contains a useful probe-driven audit and phased implementation plan. However, that audit is primarily UVM-driven and does not represent a complete clause-by-clause IEEE 1800 audit.

The existing gap list must therefore be treated as:

> A UVM-driven exploratory gap audit, not a complete inventory of every unsupported IEEE 1800 feature.

---

## Governing implementation principles

### 1. The IEEE standard is the normative source

Every implementation must be grounded in the applicable IEEE 1800 clause.

Do not implement behavior from memory.

For every feature:

- Identify the applicable clause and subclause.
- Record required syntax.
- Record semantic requirements.
- Record scheduling implications.
- Record type-system implications.
- Record error conditions.
- Add positive and negative tests.

Use IEEE 1800-2017 as the primary baseline unless the project explicitly changes the target. Track IEEE 1800-2023 as a separate delta.

### 2. The Accellera UVM library is the application-level reference

The UVM implementation must remain unmodified except where an upstream portability branch already exists.

When UVM exposes a failure:

1. Reduce it to the smallest pure-SystemVerilog reproducer possible.
2. Identify the underlying language or runtime defect.
3. Fix the simulator.
4. Preserve the reduced reproducer as a permanent regression.
5. Re-run the unmodified Accellera UVM code.

Do not patch UVM to hide simulator defects.

### 3. Never claim support based only on parsing

A feature is not supported until all relevant layers work:

- Lexing and preprocessing
- Parsing
- Name resolution
- Type checking
- Elaboration
- Code generation
- Runtime behavior
- Scheduling behavior
- VPI visibility
- DPI behavior where applicable
- Positive tests
- Negative tests

### 4. Eliminate silent miscompiles

Permissive compile-progress fallbacks must be converted into one of:

- Correct implementation
- Explicit compile error
- Explicit unsupported-feature diagnostic
- Deliberately specified safe lowering

Silent approximation is incompatible with a conformance project.

### 5. Prefer architectural fixes over UVM special cases

Repeated failures in factory lookup, method chaining, config databases, callbacks, assignment patterns, and arrays often indicate missing compiler architecture.

Fix shared foundations rather than adding one-off checks for specific UVM identifiers.

### 6. Every stable implementation increment must be committed

Work must be divided into small, reviewable, regression-clean checkpoints.

At each stable point:

1. Run the relevant focused tests.
2. Run the canonical regression suite.
3. Update implementation notes and conformance records.
4. Commit with a descriptive message.
5. Push the branch to the remote repository.

Do not leave large amounts of validated work uncommitted.

Do not commit known-broken partial work to the main integration branch. Use a topic branch and mark incomplete checkpoints clearly.

---

## Architectural direction

### Typed SystemVerilog semantic IR

Every expression must preserve:

- Exact SystemVerilog type
- Signedness
- Packed width
- Unpacked dimensions
- Two-state or four-state nature
- Class specialization
- Enum identity
- Lvalue or rvalue category
- Constant-expression status
- Source location

This is necessary for:

- Chained method calls
- Enum methods
- Class-return expressions
- Parameterized class lookup
- Assignment patterns
- Casts
- Array behavior
- UVM factory access
- UVM config database casts

### Separate parsing, semantic analysis, and lowering

The intended flow is:

```text
Parser AST
    ↓
Name and type resolution
    ↓
SystemVerilog semantic IR
    ↓
Feature-specific lowering
    ↓
Netlist/VVP IR
    ↓
VVP runtime
```

Do not lower advanced constructs directly in parser actions when they require semantic information.

### Aggregate layout service

Use one shared representation for:

- Packed structs
- Packed unions
- Unpacked structs
- Static arrays
- Dynamic arrays
- Queues
- Assignment patterns
- Streaming operations
- DPI descriptors
- VPI traversal

It must provide:

- Width
- Member offsets
- Array strides
- Flattening order
- Streaming traversal order
- Recursive assignment compatibility
- Default propagation

### Runtime type descriptors

Every runtime class object should have a descriptor containing:

- Concrete class type
- Base class
- Parameter specialization identity
- Property descriptors
- Virtual method table
- Cast relationships
- Factory-visible type name
- VPI-visible metadata

### Generic container model

Static arrays, dynamic arrays, queues, associative arrays, and strings where appropriate should share reusable operations for:

- Iteration
- Indexing
- Resizing
- Copying
- Comparison
- Sorting
- Reduction
- Locator methods
- VPI access
- DPI access

### Formalized scheduler

The runtime scheduler must be treated as an explicit state machine covering the relevant SystemVerilog event regions.

Every scheduling operation should declare its destination region.

Add trace support recording:

- Simulation time
- Delta cycle
- Event region
- Process identity
- Event identity
- Source location

---

## Verified high-priority gap families

### Clocking blocks and program semantics

Implement and test:

- Module-level clocking blocks
- Interface-level clocking blocks
- Program-level clocking blocks
- Global clocking
- Default clocking
- Input/output skew
- Clocking signal directions
- Clocking sampling and driving regions
- Program reactive-region execution

### SVA

Build a coherent property and sequence engine supporting:

- Clocked properties
- Default clocking
- Sequence delays
- Repetition
- Implication
- Disable conditions
- Strong and weak semantics
- `and`
- `or`
- `intersect`
- `throughout`
- `within`
- Local variables
- Formal arguments
- Multiclock semantics
- Assertion action blocks
- Assertion controls
- Procedural concurrent assertion contexts

### Constraint solving

Implement as a subsystem:

- Implication
- `if`/`else`
- `foreach`
- `inside`
- `dist` with `:=` and `:/`
- `solve ... before`
- Enum constraints
- Inherited constraints
- Parent/child random fields
- Dynamic-array size constraints
- Inline constraints
- Soft constraints
- `constraint_mode`
- `rand_mode`
- `randc`
- `pre_randomize`
- `post_randomize`
- Failure-state preservation
- Seed stability

### Class and method semantics

Implement:

- Method calls on arbitrary class-valued expressions
- Property access on function-return class handles
- Chained class methods
- Chained enum methods
- Static factory access
- Parameterized class specialization through expressions
- Virtual dispatch
- `$cast`
- Runtime type identity

### UVM-critical language flows

Prioritize:

- Factory by-name creation
- Config database class-object storage and retrieval
- Callback registration
- Static and dynamic array field automation
- Deep and shallow copy behavior
- Clone, compare, pack, unpack, print, and record paths
- Phasing and objection correctness

### Interfaces and modports

Implement:

- Modport task/function imports and exports
- Interface instance arrays
- Virtual interface arrays
- Implicit and explicit modport selection
- Modport compatibility checks
- Parameterized interfaces
- Interface methods
- Clocking blocks in interfaces
- Unpacked-dimensional ports where legal

### Process and event semantics

Implement:

- `process::self`
- Status transitions
- `await`
- `suspend`
- `resume`
- `kill`
- Randstate accessors
- Parent/child process identity
- Correct fork/join interaction
- Event arrays
- Event assignment
- `event.triggered`
- Multiple waiters
- Nonblocking event triggers
- Correct event-region lifetime

### Arrays, queues, and containers

Implement complete behavior for:

- Static arrays
- Dynamic arrays
- Queues
- Associative arrays
- Nested containers
- Resize-with-copy
- Reverse
- Sort
- Rsort
- Shuffle
- Min
- Max
- Unique
- Unique index
- Find
- Find index
- Reductions
- Iterator and `with` semantics

### Assignment patterns, structs, unions, and streaming

Implement:

- Typed assignment-pattern defaults
- Recursive defaults
- Packed aggregate defaults
- Tagged unions
- Pattern matching
- Streaming RHS
- Streaming LHS
- Unpacked array slicing
- Recursive aggregate assignment

### DPI-C

Implement:

- Installed `svdpi.h`
- Scalars
- Two-state vectors
- Four-state vectors
- Strings
- Chandle
- Packed arrays
- Unpacked arrays
- Open arrays
- Multidimensional arrays
- `svOpenArrayHandle`
- Bounds and dimensional queries
- Element and slice accessors
- Scope APIs
- Pure imports
- Context imports
- Imported tasks
- Exported tasks/functions
- Re-entrant calls
- Scheduler integration
- Cross-platform ABI tests

### VPI

Systematically cover:

- Classes
- Packages
- Interfaces
- Modports
- Generate scopes
- Dynamic arrays
- Queues
- Associative arrays
- Strings
- Assertions
- Covergroups
- Tasks and functions
- Values
- Delays
- Callbacks
- Force/release
- Stable handle lifetime

### Functional coverage

Create an independent runtime coverage service supporting:

- Covergroups
- Coverpoints
- Explicit bins
- Automatic bins
- Wildcard bins
- Ignore bins
- Illegal bins
- Transition bins
- Repetition
- Arrayed bins
- With clauses
- Crosses
- `binsof`
- `intersect`
- Per-instance coverage
- Type coverage
- Options and type options
- Sampling events
- Explicit sampling
- Query APIs
- Coverage reporting
- Durable serialization

### Long-tail language support

Eventually cover:

- `bind`
- `let`
- Config declarations
- `trireg`
- Specify paths
- Timing checks
- Strength and charge semantics
- Rare net forms
- Compilation-unit rules
- Preprocessor corner cases
- Complete constant-expression semantics

---

## Conformance infrastructure

Create:

```text
docs/conformance/
    ieee1800-2017-matrix.csv
    ieee1800-2023-delta.csv
    ieee1800.2-uvm-matrix.csv
```

Each feature row must include:

- Clause
- Subclause
- Feature
- Parser status
- Semantic status
- Elaboration status
- Runtime status
- Scheduler status
- VPI status
- DPI status
- Positive test
- Negative test
- Differential test
- Current result
- Issue or gap identifier
- Owning subsystem

### Test hierarchy

#### Tier A: Language microtests

One feature per test.

#### Tier B: Interaction tests

Examples:

- Classes plus randomization plus dynamic arrays
- Interfaces plus clocking plus virtual interfaces
- Packages plus parameterized classes plus factory
- Assertions plus default clocking plus program blocks

#### Tier C: Application tests

Use the unmodified Accellera UVM library and representative examples.

---

## Milestone sequence

### M0 — Reproducible baseline

- Import all temporary probes into the repository
- Document build and regression commands
- Record current upstream and fork commit IDs
- Produce baseline regression results

### M1 — Typed expression and runtime class descriptors

- Preserve return types
- Support method/property lookup on arbitrary expressions
- Preserve enum identity
- Preserve parameter specialization
- Add virtual dispatch metadata

### M2 — UVM factory, config, callbacks, and field automation

- Fix by-name factory paths
- Fix class-valued config database paths
- Fix callback macro reductions
- Fix array field copy/clone/print/pack behavior

### M3 — Constraint solver

- Implement common UVM constraint semantics as one subsystem

### M4 — Container runtime

- Unify array, queue, associative-array, and string container operations

### M5 — Interfaces and modports

- Complete connection, array, modport, and virtual interface behavior

### M6 — Process, events, and scheduler

- Formalize event-region behavior
- Fix process state and event observation

### M7 — Accellera UVM core qualification

Run the unmodified library through:

- Factory
- Config
- Callbacks
- Reporting
- Phases
- Objections
- Sequences
- TLM
- Register model
- Field automation
- Resource database
- Events and barriers

### M8 — Clocking blocks and program scheduling

### M9 — Core SVA engine

### M10 — DPI and open arrays

### M11 — Functional coverage

### M12 — VPI SystemVerilog object model

### M13 — Bind, let, configs, specify, timing, and rare constructs

### M14 — IEEE 1800-2017 clause matrix with complete disposition

### M15 — IEEE 1800-2023 delta

---

## Definition of done for a feature

A feature is complete only when:

1. The governing IEEE clause is identified.
2. Legal syntax parses.
3. Illegal syntax produces a controlled diagnostic.
4. Names resolve correctly.
5. Types are preserved correctly.
6. Elaboration is correct.
7. Runtime behavior is correct.
8. Scheduling behavior is correct where applicable.
9. VPI behavior is defined where applicable.
10. DPI behavior is defined where applicable.
11. Positive tests pass.
12. Negative tests pass.
13. Interaction tests pass.
14. Existing regressions pass.
15. Documentation and conformance matrices are updated.
16. The work is committed and pushed.

---

## Immediate recommended implementation sequence

Begin with the typed-expression and method-dispatch foundation.

Implement:

1. Exact return-type preservation on function-call expression nodes.
2. Member lookup against the returned type.
3. Method calls on arbitrary class-valued expressions.
4. Property access on arbitrary class-valued expressions.
5. Chained method calls.
6. Enum method calls on function returns.
7. Parameterized class specialization preservation.
8. Virtual dispatch metadata.
9. Focused tests for:

```systemverilog
f().method();
f().property;
f().method().method();
enum_f().name();
C#(T)::get().method();
```

Then rerun the UVM factory, config database, process enum, and builder-chain probes.

After that, implement the constraint solver as a coherent subsystem.

---

## Commit and branch discipline

Use topic branches for each milestone or tightly scoped feature.

At stable checkpoints:

```bash
git status
git diff
# run focused tests
# run canonical regression
git add <intentional files>
git commit -m "<subsystem>: <precise completed behavior>"
git push -u origin <branch>
```

Commit messages must describe behavior, not merely phase numbers.

For incomplete but valuable branch state, use a clear WIP commit only on a topic branch:

```text
WIP: <subsystem> <current state and remaining failure>
```

Never push known-broken work to the main integration branch.

Maintain a session log containing:

- Branch
- Starting commit
- Ending commit
- Tests run
- Results
- Root cause
- Files changed
- Remaining work
- Exact next action

---

## Final project principle

The project must not chase a vague claim of “full SystemVerilog support.”

It must build measurable conformance:

> Every supported behavior is tied to a standard clause, a durable test, a documented implementation path, and a regression-clean commit.
