# IEEE 1800 §11.9–§11.12 audit

Probes ran on macOS Darwin ARM64 under `~/codex-supervisor/localrun` on
2026-10-19. Checkout HEAD: `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`;
built compiler source: `b9441bafbdb0b6b7413c09e0381845e69481391b`; Icarus
13.0-devel SHA-256 `7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`;
VVP SHA-256 `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`.
All results below matched in `-g2017` and `-g2023`.

## §11.9–§11.11

The corrected `p11_09b_no_pkg.sv` compiles/runs and prints `INFO mtm=7` and
`RESULT pass=8 fail=0`. It covers tagged-union member and nested-member access,
string literal padding/concatenation/empty-string behavior, let default
arguments, declarative binding, and the captured outer variable. The first
attempt used `matches` inside a parenthesized ordinary expression; the lead
corrected it to a conditional predicate, as required by the grammar. Initial
syntax-error logs are retained; they are a probe-source error, not a result.

`r11_09_wrong_tag.sv` exits 1 in both editions with an inactive tagged-union
member runtime error and `TAGRD x=x`. Recursive and hierarchical-let negatives
are rejected. Interface/program/module `let` controls work (`I 2`, `P 2`,
`MODULE 1`). The lead classified §11.9, §11.10–§11.10.3, and §11.11 as
IMPLEMENTED (tested subset); the typ value is informational and can vary by
tool option.

## §11.12 placement and body-shape probes

The standard's §11.12 p.292–293 placement list includes packages,
compilation-unit scope, generate blocks, sequential/parallel blocks and
subroutines. Module, interface and program placements work. Paired reducers
show package and compilation-unit declarations fail with syntax errors (with
or without formals); task, function and sequential-block declarations also
fail with syntax errors; a generate-block declaration reports that it is
unsupported and is dropped.

The standard's own `mult` let example with a `$bits`-sized cast fails to
elaborate (`sorry: ... expression shape the let expander cannot copy`). A size
cast and type cast body fail similarly; simple `$bits`, concatenation,
conditional and reduction bodies pass. Typed and ranged formal ports emit
`typed/ranged let ports are not supported yet`; the `untyped` control passes.
Removing those two failed calls from the no-package aggregate yields
`INFO mtm=7`, `RESULT pass=8 fail=0`.

All raw source, compile/run logs, runner scripts, and the unsuccessful first
probe attempt are in `attempt-01-tagged-string-let/` through
`attempt-05-let-shapes/`. Dedupe searches are all-state and stored alongside
the attempts. Placement-query union was #8, #27 and #44 (all CLOSED); #44's
generic module-scope `let` tracking does not cover the placements tested here.
Typed/formal-shape searches `let expander` and `let typed port` returned no
issues.

The lead authorized four distinct new issues, all OPEN with `1800-audit`:
[#773](https://github.com/dsellerbrock/iverilog-uvm/issues/773) package and
compilation-unit scope; [#774](https://github.com/dsellerbrock/iverilog-uvm/issues/774)
task, function, sequential-block and generate-block scope;
[#775](https://github.com/dsellerbrock/iverilog-uvm/issues/775) cast-containing
let body shapes; and [#776](https://github.com/dsellerbrock/iverilog-uvm/issues/776)
typed/ranged formals.

## Classification

- §11.9 and §11.10–§11.11: IMPLEMENTED (tested subset).
- §11.12: PARTIAL; four verified issues above. Module, interface and program
  placements; default-argument and declarative binding; untyped formals; and
  rejected recursive/hierarchical forms are covered by the passing probes.
  Checker and clocking-block placements remain UNASSESSED.

This tranche filed four new §11.12 issues. The audit total at this checkpoint
is 45 new issues above the 89-open-issue baseline; GitHub shows 134 open issues
with the `1800-audit` label.
