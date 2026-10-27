# IEEE 1800 §12 audit: conditionals, case, patterns

Probes ran on macOS Darwin ARM64 under `~/codex-supervisor/localrun` on
2026-10-20. Checkout HEAD: `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`;
built compiler source: `b9441bafbdb0b6b7413c09e0381845e69481391b`; Icarus
13.0-devel SHA-256 `7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`;
VVP SHA-256 `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`.
The results below match under `-g2017` and `-g2023`.

## §12.4–§12.5

`p12_04a_if_case.sv` passes 11/11 checks. It tests X as false in `if`,
dangling-else binding, short-circuit `else if` evaluation, case-expression
single evaluation, ordered case-item evaluation, X/Z matching, no-match
preservation, and case sizing/signedness. The `unique if` no-match and overlap
produce warnings, while covered `priority if` and unmatched `unique0 if` are
silent. The nested `else unique if` negative source compiles; the lead
classified it as a legal nested conditional, not an invalid qualifier.
Logs/runner: `attempt-01-if-case/` (0.87 s wall, 16,924,672 B peak RSS).

The duplicate-default negative is silently accepted. Its runtime reducer
prints `DD r=20` in both editions, so the last default executes. It is tracked
by [#778](https://github.com/dsellerbrock/iverilog-uvm/issues/778). Source,
runner and logs: `attempt-02-double-default/` (0.50 s wall,
16,826,368 B peak RSS).

## §12.5.1–§12.6.3 probe status

The first combined casez/casex/case-inside/tagged-pattern probe fails to
compile at its first `&&&` case-pattern filter. Minimal reducers confirm that
an unguarded tagged `matches` case works (`f3 hit=5`) but guarded patterns fail
with `Incomprehensible case expression` across tagged, wildcard and constant
patterns in both editions. The initial `if`-predicate form compiles as
malformed and aborts in parser cleanup. In `attempt-06-if-guard-controls/`,
the unguarded tagged `matches` if condition passes (`g1 hit=5`), while plain
`&&&`-chained if predicates (`g2`, `g3`) and a guarded `matches` if predicate
(`g5`) fail in both editions; the last form aborts in parser cleanup. The
initial conditional-operator probe `g4` put the `matches` clause in
parentheses, so it is invalid evidence and is superseded by h1–h6 in
`attempt-09-cond-expr-controls/`. Those unparenthesized controls compile for
the unguarded forms: h1 binds `.n` as 0 rather than 5 in the consequent, while
h2 correctly selects its false arm (`nv=2`). Adding `&&&` rejects the plain
expression and pattern conditional predicates in h3–h6 in both editions.

The unguarded case-pattern reducer is split into `p12_05c_no_guards.sv`.
After correcting the parenthesized `matches` spelling and the casex expectation,
it compiles in both editions and reports `RESULT pass=12 fail=1`; only
`match_cond` fails. The masked casex value is `x1x0x1x0`: the first item
mismatches at known bit 6 and the second item `1100xx00` matches, so ordered
selection correctly produces 2. The `match_cond` compile warns that `n` could
not be bound; runtime gives `nv=0` instead of 5. The unique/priority warnings
are as expected (W1, W3, W5 report; W2 and W4 stay silent). See
`attempt-07-no-guards/p12c.corrected.*.run.log`; the original invalid
parenthesized attempt is preserved in `p12c.*.compile.log`. The #780 issue body
was corrected to cite only valid conditional-predicate probes.
#780 covers the `&&&` conditional
predicate rejection, separate from [#779](https://github.com/dsellerbrock/iverilog-uvm/issues/779),
which covers filters on pattern-matching case items.

All-state dedupe results are in attempt-01 and attempt-05. Relevant hit #19
(CLOSED) covers unguarded pattern matching, but not filters; #539 (CLOSED)
covers assignment-pattern member sizing. Other search hits are unrelated.

## Issue count at this checkpoint

Seven new §12 issues are open: §12.5 (#778), §12.6.1 (#779), §12.4 /
§12.6.2 (#780), §12.6.3 (#781), §12.7.2 (#782), §12.7.3 (#783), and §12.8
(#784). The §12.7.1 scope case is recorded under existing issue #767. Cumulative
new issue counts by clause are §6: 36, §10: 2, §11: 8, and §12: 7 (53 total
above the 89-open-issue baseline). GitHub shows 142 issues with the
`1800-audit` label open.
