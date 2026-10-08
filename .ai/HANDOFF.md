# Compiler campaign handoff — 2026-10-08

## Active task

Issue #468: accept escaped `text_macro_identifier` names in ordinary
`ifdef`, `ifndef`, and `elsif` conditions under IEEE 1800-2017 and 1800-2023.
The work is on `agent/ieee-ifdef-parenthesized-20261008`, which updates draft
PR #467 to `main`; #460 remains a separately tracked change in that PR.

`ivlpp/lexor.lex` recognizes escaped names in the four plain conditional
states, requires the whitespace terminator without consuming it, and removes
the leading backslash for macro lookup. Punctuation inside the name is
preserved. The no-terminator case remains an error. No parser grammar change.

## Verification

- Forced `make -B -C ivlpp -j2` and `make -C ivlpp install` pass. Flex emits
  its two existing misleading-indentation warnings in generated scanner code.
- Issue #468 legacy focus: 3/3; JSON focus: 3/3.
- Neighboring macro-definition tests: legacy 28/28; JSON 8/8.
- Issue #460 parenthesized-expression tests: legacy 3/3; JSON 3/3.
- These are local macOS results. Full ivtest/UVM gates and exact-head CI have
  not been run for the current uncommitted #468 increment.

The baseline failure is recorded in issue #468. The applicable standards
clauses are 1800-2017/2023 §22.5 Syntax 22-5 and §5.6.1.

## Next action

Review the complete diff and YAML/CSV validity, commit and push the #468
increment to existing PR #467, update its body with the exact local commands,
then inspect exact-head CI once. Investigate any reported failure. Keep the PR
draft and do not merge or claim qualification before every required platform
check is green.

## Worktrees

Three checkouts remain. Reuse the current feature checkout; do not create a
new worktree. Preserve the clean census checkout and canonical `main` checkout
with the shared graph.
