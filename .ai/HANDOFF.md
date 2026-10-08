# Compiler campaign handoff — 2026-10-08

The issue checkout sheet is [ISSUE_CHECKOUT.csv](ISSUE_CHECKOUT.csv). Before
starting a new issue, update its owner, state, branch/PR, file boundary, and
next action there and commit the checkout. Keep implementation authorization
in [ACTIVE_WORK.yaml](ACTIVE_WORK.yaml), not in the sheet.

## Active task

Issue #460, IEEE 1800-2023 §22.5 parenthesized conditional-compilation
expressions, on `agent/ieee-ifdef-parenthesized-20261008`. The branch starts at
fresh `origin/main` `af89cfc50be1084cc86c48865f3f6ba78d4512fa`. The driver now
passes `-g2023` to `ivlpp`; parenthesized `ifdef`/`ifndef`/`elsif` expressions
are edition-gated. IEEE 1800-2023 §22.5 token separation also permits the
opening parenthesis to directly follow `ifdef`, `ifndef`, or `elsif`; the
lexer now handles those adjacent forms, including nested suppressed branches.
The 2017 adjacent-expression form still rejects. Focused 2017/2023 cases pass
3/3 in the legacy and JSON runners, and neighboring macro checks pass. See the clause record in
`docs/conformance/matrices/ieee1800_2017_clause_matrix.md` and the exact results
in `ACTIVE_WORK.yaml`.

The full root `make -j2` passes with Bison 3.8.2. System Bison 2.3 alone rejects
the unchanged `parse.y:2236` `%destructor`. The conflict counts match clean
`origin/main`: 574 shift/reduce and 1,122 reduce/reduce. Draft [PR #467](https://github.com/dsellerbrock/iverilog-uvm/pull/467)
targets `main`; the first CI run was on the pre-adjacency head and is no longer
the qualification target. Verify the updated PR head across all six platforms;
CI qualification is not yet established.

## Next

Commit and push the adjacent-parenthesis fix and evidence updates, then inspect
the new exact-head CI after it has had time to run. Investigate any reported
failures deeply. Merge and advance to the next IEEE ticket only after all six
required checks are green; do not repeatedly poll unchanged CI.

Keep the checkout limit at three. Preserve dirty
`agent/timeunit-timeprecision-20261007` and the canonical `main` checkout with
the shared graph. Do not select DD-107 from the previous package-call ticket;
it remains triage-pending and out of scope for issue #460.
