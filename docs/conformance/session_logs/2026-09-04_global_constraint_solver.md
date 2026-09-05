# Global constraint solving — 2026-09-04

This increment uses one constraint problem for the selected object graph.
Parent/child fields and aliases share actual storage identities, and the new
joint sampler requires a complete legal tuple set before choosing a result.
Support remains partial. The full IEEE and unmodified full-DV goal is open.

Installed build18 passes the complete repository gate. Both application censuses
are complete and every row has been compared with the member checkpoint. Evidence lives in the workspace directory
`evidence/xbar-zero-traffic-after255-arm64-20260904/` (N below). No OpenTitan,
Caliptra, Adams Bridge, UVM, or generated application source was changed.

## Normative contract

| Mechanism | IEEE 1800-2017 | IEEE 1800-2023 |
|---|---|---|
| Constraint expressions, X/Z, prohibited four-state operators | 18.3 | 18.3 |
| Active object graph and state operands | 18.5.9 | 18.5.8 |
| Uniform legal combinations and variable order | 18.5.10 | 18.5.9 |
| Distribution weights and state endpoints | 18.5.4 | 18.5.3 |
| External constraint declarations | 18.5.1 | 18.5.1 |
| Declaration/handle soft priority and disable soft | 18.5.14.1/.2 | 18.5.13.1/.2 |
| Randc cycle semantics | 18.4.2 | 18.4.2 |
| Iterative array constraints | 18.5.8.1 | 18.5.7.1 |
| TRUE/FALSE/ERROR/RANDOM constraint guards | 18.5.13 | 18.5.12 |
| Failure and callback barrier | 18.6.1/18.6.3 | 18.6.1/18.6.3 |
| Active selection and checker calls | 18.8/18.11 | 18.8/18.11 |
| Object RNG stability and replay | 18.14.1/18.14.3 | 18.14.1/18.14.3 |
| Handle identity, equality, and visibility | 8.4/11.4.5/18.4/8.18 | same clauses |
| Expression width and signedness | 11.6.1/11.8.1–11.8.2 | same clauses |

The local IEEE texts are normative. Slang was used only as an independent
syntax/elaboration comparison. Both edition modes use the same behavior for
the mechanisms above; this increment introduces no edition-specific exception.

## Graph, priority, and transaction

One owner-aware Z3Builder represents actual instance and shared static storage.
Direct properties, struct members, object paths, and fixed object-collection
members converge on canonical identities. An alias of selected storage remains
random even when reached through a state handle. Nonselected fields stay state.
Domains, array sizes, and element variables retain their actual owners.

Graph collection and journals precede prefills. Shared static properties prefill
once; value structs use their containing object's RNG. Values and cyclic histories
commit only after the complete solve. Failure restores all participants and
prevents implicit post callbacks, including after provisional container fills.

Declaration order survives prototypes and out-of-body definitions. An implicit
prototype can remain an empty optional body and cannot consume an outstanding
extern requirement. Base constraints precede derived constraints and inline
preferences; older unmerged metadata retains a separate inherited band. Parser
productions did not change: the generated automaton matches its earlier snapshot
with 541 shift/reduce and 1122 reduce/reduce conflicts.

## Joint sampling and explicit limits

For more than one selected class object, the sampler enumerates complete projected
semantic tuples, blocks each whole tuple, proves exhaustion with an extra UNSAT
check, and sorts the complete set for replay. Selection uses the existing unbiased
bounded draw from the invocation root's RNG. Auxiliary/state assignments are not
additional random outcomes. A singleton consumes no extra draw.

Exact randc stages precede ordinary tuple sampling. Every active declared randc
leaf, including unmodeled fields, must fit the existing history representation.
Owner RNGs replay between solve passes. Array sizes require one proven value;
an allocation cap is an explicit failure bound rather than an inserted constraint
on the legal domain. Ordinary sampling and writeback wait for the final expanded
foreach pass.

The new route explicitly rejects:

- More than 1024 projected tuples, incomplete enumeration, UNKNOWN, or extraction
  failure. It never accepts a partial prefix or substitutes the old XOR sampler.
- Cyclic soft graphs and joint staged `dist` or `solve before` problems.
- Handle-collection resizing, multivalued sizes, and unsupported projected widths
  above 64 bits. A size used only in a discarded soft may be rejected conservatively.
- Global randc storage beyond the existing 20-bit history representation, even
  with a tiny feasible domain. Live normalized queue words supply their widths;
  typed size metadata checks prospective entries before prefilling.
- Fixed arrays of queues, whose older prefill route does not cycle their elements.

Existing single-object distribution/history limits remain open. UNKNOWN during
explicit soft resolution now fails there too. An existing single-object weighted
fallback remains loud; this increment does not claim full randomization conformance.

## Handles, guards, and state operands

Typed handle readers retain actual object identity, including null, through direct,
chained, struct-member, and fixed/dynamic/queue element paths. Caller handles remain
owned until solving completes. Invalid owner/index/metadata is an error distinct
from a valid final null. Existing local/protected access checks remain in use.
Unsupported caller dereference captures and nonconstant non-loop selectors diagnose.
Comparisons produce one-bit integral values.

Source references and actual call selection classify guards before algebraic
simplification or state pins. An active `x == x` or `x ** 0` remains RANDOM.
X/Z state errors survive beside random operands; valid false state implications
exclude bodies before soft/disable/order/foreach registration. Associative state
reads use the existing occupied-entry reader and retain raw four-state values.

State foreach expansion uses the same canonical registry as the solve. Active
instance/static fields reached through caller-state collections stay symbolic.
Inactive ternary arms retain their width/sign even when their error is guarded
away. The legacy scope route keeps its existing expansion path. Null receivers
are rejected before graph deferral using the same shared diagnostic.

Inactive scalar storage becomes a typed constant before expensive operator
expansion. This avoids creating 32 symbolic power stages for a known state
exponent. Reference collection still precedes folding, preserving soft dependencies
and guard provenance. Signed constants retain occurrence-specific type metadata.
State widths above 64 bits and X/Z diagnose explicitly; this is an implementation
bound, not an IEEE width restriction. Legacy numeric pinning has separate remaining
width/X coercion limits outside this corrected shared scalar route.

Both editions prohibit case equality/inequality inside constraints. Class, inline,
and scope forms now hard-error. Procedural handle case comparisons remain legal;
the separate null-property `!==` code-generation inversion is corrected.

## Regression and review evidence

There are 27 new paired test families, 54 entries in each legacy/JSON harness.
They cover global domains, aliases, source/soft priority, prototypes, sampling,
cyclic histories and rollback, explicit unsupported boundaries, handle carriers,
selection and guards, and state foreach aliases, widths, and associative storage.
Every new entry is registered once. Existing handle-foreach assertions also cover
an active child. No test assertion or expected-failure list was weakened.

The original three-tuple reducer produced counts 3022/0/2978 in 6000 calls before
the joint sampler correction. The permanent test requires all three outcomes and
checks RNG save/restore replay despite unrelated randomizations and `$urandom` calls.
Paired reducers also cover old unmerged inherited metadata, wide-history failures,
container cycles across failed solves, and selected/static aliasing.

Native declaration, transaction, exact-sampler, handle/guard, state-foreach, and
associative-reader reviews are reconciled. Claude Code CLI review2 used an immutable
build13 snapshot. Full helper context and eight direct runs refuted its whitespace,
non-rand-child, and general procedural inequality claims. IEEE 18.3 requires the
X/Z errors it proposed suppressing. Its associative-state reader finding was real
and is fixed. Native reviews cover subsequent deltas through build18.

Retained failed/interrupted gates establish what the checks caught:

- Gate1 found the aggregate `disable soft` reference regression; the original test
  passes after preserving containing struct identity in the shared matcher.
- Gate2 found the null-receiver invariant; the shared rejection is restored.
- Gate3 was interrupted during UVM for the associative-reader fix. It is not a
  completed gate and neither census ran.
- Gate4 passed legacy 4621/4626 (0 failed, 2 NI, 3 EF), name diff, VPI 103/103,
  negative 149/0, runtime invariants, and JSON 1515/0. UVM finished 354 passed,
  1 failed, 0 skipped: the unchanged nested-state test exceeded its 60s wall timeout.

Build18 resolves that slowdown. The unchanged 20-call test completes in 0.285s
and 0.039s in 2017/2023 modes, and its real-DPI UVM harness passes 1/0/0. All 58
direct handle/guard checks pass. Focused legacy initially passed 186/187; the only
mismatch was an obsolete distribution fallback warning, with all runtime assertions
passing. State endpoints now enter the existing exact path. Four edition-paired
state/active endpoint controls show that active endpoints retain the warning.
The audit removes only that line from two golds; the corrected case passes and
focused JSON passes 166/166. Other diagnostic gold changes preserve error sites,
counts, or exact line multisets, with separate audit records.

## Final validation and application comparison

Full gate5 passes on frozen build18: legacy 4621/4626 (0 failed, 2 NI, 3 EF),
clean name diff, VPI 103/103, negative 149/0, runtime invariants including state
foreach 15/15, JSON 1515/0, and real-DPI UVM 355 passed / 0 failed / 0 skipped.
Both censuses completed against the same source/binary fingerprints. OpenTitan's
exit status 1 means its completed matrix contains failing rows. The first
coordinator stopped on that status; after verifying all 530 keys and absence of
MATRIX_ERROR, the authorized Caliptra run and per-row diff completed separately.
No failing row was reclassified as success. After the gate, three negative-test
first-line comments named both IEEE editions; all other lines are identical.

Builds use serial `make` followed by `make install`, native ARM64, Homebrew Bison
3.8.2, installed worktree tools first PATH, and the user-authorized 300s per-process
CPU guard. No compiler RSS ceiling is imposed. The existing UVM 60s wall timeout
was unchanged. Build18 adds no warning; all six worktrees are retained.

All 530 OpenTitan rows were compared against member checkpoint a20a99142:
203 PASS is unchanged, with no formerly passing row lost. Summed
`semantic_debt_count` stays 2223. The only status change is TL agent from
RUNTIME_TIMEOUT to RUNTIME_FAIL; this is not a completion improvement.

Twenty already-failing runtime rows now stop earlier at the explicit joint
`dist`/`solve before` boundary. All eight xbar compile rows still pass. Their
runtime rows now fail at time-zero `cfg.randomize()` in dv_base_test.sv:75,
before the former `test_seq.randomize()` failure at line143. Lower error counts,
shorter durations, and avoided later crashes/timeouts do not establish improved
runtime coverage. Joint weighted/order solving is the next shared frontier.

All commands, source lists, mappings, and application inputs match. Eight compiler
warning sites moved with source declaration order: the same per-class unsupported
warning now names the first source-ordered block. The other raw compiler log
changes are interleaving, with all macro/error/warning token totals and return
codes matching. Entropy-source compile debt shifts +1 in runtime and -1 in UVM,
leaving the sum unchanged. Full per-row and raw-diagnostic audits are retained.

All 105 Caliptra classifications and per-job fields match: 52 PASS, ICARUS_GAP 0,
51 SHARED_SOURCE_OR_CONFIG, one DEBT, and one SOURCE_ORDER_DEBT. Source, fileset,
and input hashes match. The census script differs only in its output directory.
This remains a static census, not full Caliptra DV.

PRs 255/256/257 were externally merged. Member PR257 landed in its parent after
that parent reached main, leaving its changes absent from main. Current main
269cd208e is tree-identical to root c5d07f600, and the merged member parent is
tree-identical to a20a99142. The fresh main-based draft carries the exact member
patch followed by this global increment, preserving the validated final tree.
The complete PR therefore adds five member families plus 27 global families,
64 entries per harness. No merge was performed or authorized for this agent.
Additional frontend gaps include hierarchical `solve before`, nested
class-to-struct paths, and hierarchical `constraint_mode`.

## PR258 portability follow-up — installed build19

The initial Ubuntu 24.04 CI job failed compiling `vvp_z3.cc`: its typed handle
reader uses `std::function` without directly including `<functional>`. Apple
libc++ supplied that declaration transitively. The correction adds that single
standard-library include. IEEE references are N/A for this C++ build correction;
SystemVerilog semantics and the regression expectations are unchanged.

Native Homebrew GCC 16.1.0 (`aarch64-apple-darwin25`) reproduced the missing-type
error using the actual make compile flags with `-fsyntax-only`. The same command
passes after the include. Its pre-existing shadow warning remains. Evidence:
`pr258-functional-include-gcc-red.json`, `pr258-functional-include-gcc-green.json`,
and the retained initial Ubuntu CI log under N.

Serial ARM64 make followed by make install passed as build19 with the 300s CPU
guard and Homebrew Bison 3.8.2. Its broader timestamp-triggered rebuild reports
existing source/generated-parser warnings; this is not a warning-free build.
All 58 existing direct handle/guard/state checks pass in both edition modes, with
installed binary fingerprints unchanged during the checks. See
`global-build19-fingerprints.json`, `global-build19.log`, and
`global-handle-build19-results.json`. The complete gate and application censuses
above were run on build18; they were not repeated for this include-only change.
