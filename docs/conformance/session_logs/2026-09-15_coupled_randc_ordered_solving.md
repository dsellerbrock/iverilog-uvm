# Coupled cyclic and ordered solving — L111

FOCUSED_TESTED; broad qualification pending. IEEE1800-2017 18.4.2/18.5.10
and IEEE1800-2023 18.4.2/18.5.9.

Enumerable components containing one active cyclic scalar or fixed-array leaf
can now coexist with coupled ordinary ordered variables. The cyclic projection
is selected first; existing ordered stages then solve its conditional fiber.
Distribution resolution distinguishes success, empty legal mass and unsupported
representation. Existing callers retain their Boolean behavior.

Touching distribution representations are checked before cyclic selection.
Existing unrelated late unsupported failures remain safe because graph failure
restores every owning object's RNG, values and cyclic history. A deterministic
failed-call/control comparison checks both root and child random states and
subsequent results. No skipped cyclic draw or conditioned successful retry is
introduced. Multiple coupled cyclic leaves and excessive tables remain explicit
unsupported boundaries.

Both harnesses pass73 combined cases: fourteen new checks, eight L109 controls,
and51 registered neighbors. Coverage includes multiple cycles, ordered prefix
fibers, disabled mode, scalar/element storage, zero weights, UNSAT/unsupported
rollback and cap/multiple-cyclic rejection. L109's formerly rejected one-cyclic
case is migrated to a positive two-cycle test; its old source is preserved in
git history and local evidence.

A first nested-array reducer printed PASSED while the compiler warned that a
constraint was ignored. That is not valid evidence. Its replacement exercises
the same runtime element mechanism through supported local indexing and passes
without the warning. The nested-index frontend gap is retained separately.

See the [validation record](2026-09-15_coupled_randc_ordered_solving_validation.json)
for commands, source/tool hashes, failed attempts and exact results. Broader
cyclic distributions and clause coverage remain incomplete.
