# Caliptra language, covergroup, and SVA compatibility

Caliptra RTL remained unmodified and read-only. This increment reduces the
language, functional-coverage, and concurrent-assertion forms that blocked its
ordinary assertion-enabled compilation; it is not a claim that the complete
Caliptra design now compiles or simulates.

## Implemented subsets

- A based literal may place underscores between the base specifier and its
  first digit, as required by IEEE 1800-2017 5.7.1. Slang 11 rejects this form,
  so the differential records that oracle disagreement rather than changing
  the source.
- An untyped `localparam` interspersed in an old-style task/function body is a
  declaration, not an executable statement.
- Functional coverage now retains standalone constructor scope, bin `iff`,
  compact transition alternatives and repetition, and cross `with` filters.
  Hierarchical cross items are an explicit Caliptra compatibility extension,
  not a clause-19 conformance claim.
- Named properties/sequences support plain formals followed by `int` and
  unsigned packed/scalar `logic` locals. Assignment conversion is embedded in
  the property IR so cloning and parameter substitution retain the declared
  width and signedness. Every NFA attempt owns its complete local value; the
  permanent tests include Caliptra-shaped 256-bit multidimensional packed
  values and an unbounded wait with overlapping attempts.
- The supported nested nonoverlapped implication shape launches a consequent
  obligation for each variable-length antecedent endpoint.
- The compact linear assertion checker retains the clause-40 step callbacks
  and fixed-latency attempt start time that were previously supplied only by
  the larger NFA checker. This keeps VPI behavior exact while avoiding an
  attempt pool for every deterministic Boolean chain.
- `$assertoff` and `$asserton` accept labeled/hierarchical selections and use
  runtime `(scope, assertion index)` identity, so equal compile-time indices in
  two module instances do not alias. Off starts no new attempts but does not
  discard an already executing attempt.
- `$assertkill` now aborts active attempts in the linear, NFA, parameter-bound,
  generated-delay, temporal, and two-/N-domain multiclock checkers. A
  monotonically increasing generation is retained per runtime assertion
  identity, so an immediate Kill/On pair cannot lose the reset. Multiclock
  request handoffs carry the generation that created them, generated-instance
  selectors use canonical `G[2]` spelling, and final strong obligations are
  suppressed even when no later assertion clock acknowledges the kill.
  Finite `always[m:n]` attempts preserved by Off now expire at age `n`
  instead of being promoted accidentally to unbounded obligations.
- The integrated gate exposed two parent-branch collateral regressions while
  validating this work. A whole-vector delayed assignment now cancels a
  same-time pending transition when its input returns to the visible value,
  and Table-23 port collapse no longer retypes an output variable as a net.
  The existing `pr2901556` and `br_gh169a` tests permanently cover them.

## Deliberate boundaries

- `$assertkill` cancellation of queued deferred-immediate reports and pending
  procedural assertion instances remains open. The active concurrent-attempt
  support above does not silently claim those distinct queue lifecycles.
- Property/sequence locals do not yet implement every assertion-variable type,
  declaration initializer, formal direction/default, or complete branch-flow
  rule.
- General variable-length antecedents with multi-step or tree consequences can
  still merge endpoints; only the single-terminal fan-out shape above is
  closed.
- Hierarchical expressions in a cross are the documented Caliptra extension.
  Slang rejects them. Conversely, Slang 11 accepts one transition-repeat form
  that the IEEE grammar makes invalid; both differences are oracle-labeled.

## Robustness finding

A malformed raw `.vvp` covergroup transition record could previously request a
repeat bound of `UINT64_MAX`. Coverage computation then performed work
proportional to that metadata instead of terminating within the compiler's
bounded-work contract. The loader now validates bounded unsigned metadata and
the runtime/loader use saturating logarithmic power sums. Raw VVP fixtures also
reject overlong metadata and oversized/underflowing sample payloads before
allocation or stack access.

## Gates

All compiler and simulator process trees ran through the repository resource
runner with 45 seconds CPU per process and a 1 GiB aggregate RSS cap.

- Caliptra language focus: legacy 2/2; JSON 2/2.
- Caliptra covergroup focus: legacy 18/18; JSON 8/8.
- Caliptra SVA runtime focus: legacy 52/52; JSON 12/12.
- Slang 11 differential: 18/18 exact accept/reject and diagnostic-count cases.
- Assertion/Coverage VPI collateral: 6/6.
- Malformed covergroup VVP boundary: 5/5.
- Integrated hard gate: legacy ivtest 3,871 total, 3,866 passed, 0 unexpected
  failures, 2 recorded not-implemented, 3 expected failures; bundled VPI
  97/97; negative suite 111/111; malformed VVP 5/5.
- Main parser: 535 shift/reduce, 1115 reduce/reduce, 201 conflict states;
  normalized ordered conflict signature unchanged from the parent build.
