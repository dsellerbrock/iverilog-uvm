# Nested fixed-element constraints — 2026-09-15

FOCUSED_TESTED; broad qualification pending.

A constant indexed fixed integral/enum element reached through a class-object
prefix now has a canonical solver graph identity. References resolve the live
owner and reuse existing element variables, activity, cyclic history,
transaction rollback and writeback. Repeated and aliased paths share identity.
Missing nested members cannot bind to same-named outer members. Existing
struct and indexed aggregate handlers retain their own dispatch.

The paired cases exercise ordinary/cyclic elements, enum and signed values,
nonzero/negative multidimensional bounds, inherited deep paths, equality,
inside, solve-before, dist zero-weight exclusion, aliases, failed-call history,
element activity and null owners. Bounds, dynamic selector, protected access,
missing member, nonintegral and wider terminal controls have focused diagnostics.
Successful cases do not drop constraint items. Null-owner randomization failure
is explicitly checked; it is not a successful randomization claim.

Twenty new outcomes plus neighbors pass107 legacy and102 JSON cases; the
additional dist pair passes2 cases in each harness. A signed-one-bit fixture
oracle and an unrelated rand-string declaration were corrected during review;
original failed captures are retained. The installed candidate also includes
an independently unqualified L114 SVA patch; these tests qualify neither that
patch nor a whole application.

Nested elements wider than64bits remain unsupported. A separate direct65-bit
reproducer confirms existing shared transport truncates bit64 after reporting
successful randomization; DISCOVERED_DEBT owns that unresolved issue.
[Revision-scoped evidence](2026-09-15_nested_fixed_element_constraints_validation.json)
contains commands, fingerprints, results and retained failures.
