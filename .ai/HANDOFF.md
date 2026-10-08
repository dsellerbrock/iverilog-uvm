# Compiler campaign handoff — 2026-10-08

## Active task

Issue #460: IEEE 1800-2023 §22.5 parenthesized conditional-compilation
expressions. Work in `agent/ieee-ifdef-parenthesized-20261008`, based on fresh
`origin/main` `af89cfc50be1084cc86c48865f3f6ba78d4512fa`. Draft PR #467 targets
`main`.

The driver passes the selected generation to `ivlpp`; expression conditions
for `ifdef`, `ifndef`, and `elsif` are enabled only for 2023. The local change
also accepts comments and line breaks between a directive and `(`, per §22.5
token separation, including nested suppressed branches. The fixture covers
simple and escaped identifiers, an escaped name containing operator
punctuation, all operators, precedence, nesting, comments, line breaks, and
plain-identifier controls. No `parse.y` changes.

## Current verification

- `make -C ivlpp -j2 && make install`: passes after the current lexer change.
- Focused legacy and JSON lists: 3/3 each, including the directive comment and
  line-break cases.
- Neighboring macro definition legacy list: 28/28; JSON/VVP list: 8/8.
- Negative suite: 152/153 locally. Its only failure is
  `m9b_intersect_unequal_len`, an unrelated SVA case already recorded as
  DD-107. Do not fix it under #460.
- Bison conflicts are unchanged from clean `origin/main`: 574 shift/reduce and
  1,122 reduce/reduce.

## CI and next action

Pushed PR head `812c2c364cdf655f1125406a3f656cab8ee12549` run
`37775071993` failed the Ubuntu 22.04 and 24.04 hard gates at the negative
suite (152/153). Both logs show a clean ivtest name-diff gate and bundled VPI
131/131. The local replay identifies DD-107's `m9b_intersect_unequal_len`;
the CI log only reports the suite count. At the last snapshot macOS was queued
and MINGW64, UCRT64, and CLANG64 were still running.

The token-separator follow-up is pushed in commit `9bca7ab6`; the PR body and
DD-107 record the previous Ubuntu failures. Run `37796344976` was queued on
this source head when checked. The handoff update itself may advance the PR
head, so read the current SHA and checks from GitHub before relying on that
run. Inspect exact-head CI once after any head update. Keep PR #467 draft; do
not merge or call it CI-qualified while a required check fails.

## Worktree boundary

Three checkouts remain. Reuse the existing feature worktree; do not create a
new one. Preserve dirty `agent/timeunit-timeprecision-20261007` and canonical
`main` with the shared graph. Do not select DD-107 as the next blocker; it is
record-only and outside #460.
