# L43–L52 combined regression qualification

The ten focused increments were integrated locally at `e5a1eb846` before
running combined qualification. The first pass found 29 legacy failures and
13 JSON failures; this candidate is not fully qualified. No expected outputs,
failure classifications or suite thresholds were relaxed.

First-pass results:

| Gate | Result |
| --- | --- |
| Legacy | 5018 total; 4984 passed, 29 failed, 2 not implemented, 3 expected failures |
| JSON | 1927 run, 13 failed |
| VPI | 108 passed |
| Negative diagnostics | 149 passed |
| Runtime invariants / copy-out | 15 / 6 passed |
| UVM | 357 passed, 0 failed, 0 skipped; real DPI umbrella |
| SVA NFA | 58 passed |
| UVM release matrix | 15 SMOKE_PASS; complete, valid baseline, unchanged inputs |
| make check | Passed |
| Frontend | Deferred until the observed compiler regressions are corrected |

The failures group around shared compiler behavior:

- Explicit semicolons must retain null-statement identity. Representing them
  as sequential blocks broke deferred assertion action validation and cover
  lowering. `PNoop` preserves the distinction from an omitted action and can
  elaborate into the existing empty sequential block. Null cover pass actions
  are consumed before dispatch, preserving match counters without a spurious
  unsupported-action warning.
- Constant indexed selects already carry a canonical base. Sensitivity
  analysis must accept their retained source selection kind instead of
  asserting that every constant base came from an ordinary select.
- Assertion-control selector arguments are hierarchical names (IEEE
  1800-2017/2023 20.12). Value-reference diagnostics must follow that special
  name handling, so unknown selector indices do not become value lookup
  errors or accidentally select a valid assertion.
- A defined constant's internal BOOL classification does not establish a
  declared two-state selection type. The added generic selection cast erased
  required X padding and changed existing ordinary selection behavior. The
  final packed-carrier selection is represented as a four-state intermediate
  followed by an explicit cast only for declared two-state data. Typed select
  duplication preserves its selection kind; synthesis must preserve that
  intermediate type as well.
- VPI array-word handles need the element's signedness when their full-width
  value supplies a part-select base. A signed negative base must not become
  a large positive base merely because the word is accessed through VPI.

Durable first-pass logs, the source/install freeze and the correction
reproducers are under `evidence/batch-20260914-l43-l52/`. The first JSON
invocation used an unsupported harness option and ran no tests; its separate
`json-invocation-error` records are excluded. One focused legacy invocation
resolved the system compiler; its separately named invocation-error records
are likewise excluded. Corrected commands use the installed campaign tools
and positional list arguments.

The corrected tree passes 45/45 focused legacy tests and 42/42 JSON tests,
including every first-pass failure. The permanent
`sv_packed_prefix_read_synth` test checks invalid and valid declared-bit
carrier reads through synthesis in both editions. Ordinary null-statement
controls and independent signed-base/unknown-value controls pass in both
editions. Build/install and diff checks pass. Final correction logs are named
`corrections/final-*`; earlier intermediate runs are not qualification.

Corrected candidate `c686a4781` passed every broad gate:

| Gate | Corrected result |
| --- | --- |
| Legacy | 5019 total; 5014 passed, 0 failed, 2 not implemented, 3 expected failures |
| JSON | 1929 run, 0 failed |
| VPI / negative diagnostics | 108 / 149 passed |
| Runtime invariants / copy-out / exports | 15 / 6 / 66 passed |
| UVM | 357 passed, 0 failed, 0 skipped; real DPI umbrella |
| SVA NFA | 58 passed |
| Release matrix | 15 SMOKE_PASS |
| make check | Passed with configured Bison 3.8.2 |
| Frontend | All 12 scenarios passed |

Frontend restoration preserved all six frozen compiler/runtime/DPI/header
hashes. The tracked tree was clean. Results and exact installed hashes are in
`qualification-corrected/qualification-summary.json`. An initial make-check
invocation resolved the older system Bison and stopped at parser generation;
its separate invocation-error log is preserved. The rerun used the Bison
3.8.2 toolchain recorded by configure and passed. No compiler source changed
between these two invocations.

An evidence-only VPI probe independently checked signed and unsigned fixed
and dynamic array words, with constant and runtime indices: 8/8 properties
passed in each edition. Its sources, commands and outputs are in
`corrections/vpi-signed-array-probe/`.

This qualifies the bounded L43–L52 batch, not full IEEE/UVM conformance.
Unindexed hierarchical missing-task calls remain DD-020, and constant-invalid
or dynamic packed write prefixes remain DD-022. Frozen-candidate reproducers
for both next increments were prepared without changing the candidate.
No remote push or merge occurred. No new clone or worktree was created;
the active campaign tree and unrelated dirty controlling tree were retained.
