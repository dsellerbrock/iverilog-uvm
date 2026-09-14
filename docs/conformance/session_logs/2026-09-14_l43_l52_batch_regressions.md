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

Broad qualification of the corrected candidate remains pending. Its results
will be recorded under `qualification-corrected/`, preserving the first pass.
