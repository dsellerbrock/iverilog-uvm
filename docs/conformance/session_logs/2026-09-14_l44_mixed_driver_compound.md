# L44 — Packed mixed-driver compound stores

User cadence: focused reproducer and positive/negative tests for approximately ten
features, followed by full suites. L44 is the second focused feature after L43.

IEEE 1800-2017/2023 6.5 permits disjoint packed elements to have procedural and
continuous drivers; 11.4.1 defines compound assignment equivalence and single
index evaluation. Local copies of both standards were inspected.

Fresh unmodified OpenTitan PRINCE compilation succeeded, then simulation aborted
with concat port width 256 versus full value width 384. The reducer adds one
compound assignment to an otherwise passing mixed-driver packed array. N=2/4/5/6
all aborted in both editions. Ordinary stores routed unresolved nets through
`%force/vec4/off`; compound partial stores incorrectly used `%store/vec4`.
The patch shares the established ordinary-store route with compound stores.
It does not modify runtime width checks or application sources.

The original eight reducer configurations pass after the target-only rebuild.
Permanent tests check static mixed-driver updates at two input values, continuous
upper elements, ordinary dynamic single evaluation and unknown-index no-write.
An explicit wire procedural compound assignment remains rejected. Focused legacy
2/2 and JSON 4/4 pass, with exit statuses recorded in
`evidence/opentitan-runtime-assessment/final-focus-{legacy,json}.log`.
Root reviewed the target routes, cached offset/X flag preservation and tests;
`git diff --check` passes. Broad suites are pending at the batch boundary.

The original PRINCE replay compiles and runs past the former immediate assertion;
its runtime reached the 300-second CPU guard (exit -24) without completion.
`prince-after-repro.json` records the exact commands and installed fingerprints.
No application pass is claimed; the remaining nontermination needs separate triage.
Dynamic subparts of fixed mixed-driver elements still fail elaboration (DD-021),
and are not registered as expected language errors. DD-020 separately records
unresolved calls being ignored; it is the next bounded diagnostic correction.

No worktree or clone was created. Both pre-existing worktrees are retained;
local branch commits are ready for the next local integration checkpoint.

A separate three-second verbose replay was interrupted deliberately with SIGINT
(`prince-after-scheduler.log`). It reported five simulation time steps and 25,537
thread scheduling events. Its exit 0 reflects interruption under `-n`, not test
success. Do not repeat long PRINCE runs until a focused nontermination reducer
explains the remaining scheduler/application behavior.
