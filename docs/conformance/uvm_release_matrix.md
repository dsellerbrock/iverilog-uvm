# UVM release compatibility matrix

The repository keeps official Git releases as pinned submodules and uses
checksum-pinned official archives for releases without published Git tags.
The existing default `uvm-core` is unchanged. Sources are never patched by this
probe. Upstream license files remain with each extracted tree/submodule.

Release inventory: [Accellera UVM downloads](https://www.accellera.org/downloads/standards/uvm).
Git pins: [Accellera official tags](https://github.com/accellera-official/uvm-core/tags).
The inventory was checked on 2026-09-10. It includes all 15 library archives
listed there, including the explicitly pre-release 2017.0.9 and the latest
2020.3.2. SHA-256 values in `scripts/uvm-releases.json` pin downloaded bytes;
they are observed checksums, not claims of upstream cryptographic signatures.

## Acquire and use

Requires POSIX and Python 3.12 or newer. From the repository root:

```sh
# Initialize Git pins and fetch/extract the archive-only releases.
python3 scripts/uvm_release_matrix.py --fetch-only --register

# Select a registered release with the compiler.
local-install/bin/iverilog --uvm-list
local-install/bin/iverilog --uvm=2020.3.1 -o test.vvp test.sv

# Compile each library with the smoke test, then run successful compilations.
# Uses local-install by default; select a different built prefix explicitly.
python3 scripts/uvm_release_matrix.py --prefix "$PWD/local-install"

# Select a release, or repeat --release for a smaller matrix.
python3 scripts/uvm_release_matrix.py --release 1.2

# Offline harness integrity checks.
python3 tests/uvm_releases/test_matrix.py
```

`--register` creates source-directory links under `<prefix>/lib/ivl/uvm/releases`.
They point to the verified submodule or archive cache, so keep those sources in
place. Existing conflicting registrations are refused, never replaced. Use
`--prefix` to register with another installation. For an independently managed
catalog, set `IVERILOG_UVM_RELEASES` to a directory of `<release>/src/uvm_pkg.sv`
trees (or source-directory links). The compiler does not download releases.
Explicit `--uvm=<release>` overrides `IVERILOG_UVM_HOME`; combining it with
`--uvm-home` is an error. `-uvm` and reporting-only `--uvm-version` are unchanged.
A listed or selected release is not thereby qualified; see the results below.

The script initializes missing submodules but refuses to reset dirty or
wrong-revision submodules. A changed cached source or mismatched archive is
also rejected so local edits are preserved. Each run creates a fresh results
directory; existing results are retained. The cache can be moved with `--cache`.

| Release | Source location |
| --- | --- |
| 2020.2.0 | `third_party/uvm/2020.2.0`, official tag `2020-2.0`, commit `39dfb0077ae25d69d1e66bf7d6a56861e244150f` |
| 2020.3.0 | `third_party/uvm/2020.3.0`, official tag `2020.3.0`, commit `b5f8562d8bee8ea11b06fc2692ed2ba0b5b7eeb7` |
| 2020.3.1 | Existing `uvm-core`, official tag `2020.3.1`, commit `78c06547a2a0a29b3dc9dcafae62b75b2ff61544` |
| Other releases | `third_party/uvm-releases/sources/<release>/<archive-root>` |

`third_party/uvm-releases/` is ignored: archives, extracted sources, logs and
compiled `.vvp` programs are regenerated from the committed manifest/script.
When the default `uvm-core` is eventually upgraded, preserve the 2020.3.1 pin
in its own release submodule and update the manifest path.

UVM is a SystemVerilog source library; the compiled `.vvp` contains both the
selected UVM package and the probe. It is not a portable precompiled library
for arbitrary testbenches. Use `iverilog --uvm-home=<source-root>` to choose a
release for another design. The installed compiler/runtime stay unchanged.

## Recorded local results

2026-09-11, native ARM64, validated source `c58035f49` (L25 return-variable reference storage).
The release sweep uses classifier `1654dc4c9` (U12); all required L25 compiler
and U12 harness validation gates are complete.
Actual mode: `-g2012`. Each command has a 300-second per-process CPU guard
and a configurable wall timeout (300 seconds by default), with no RSS cap.
The smoke checks factory creation, clone/field copy and independence, phase
execution/objections, positive/negative DPI regex and a timed DPI HDL read.
It uses the installed Icarus DPI backend; it does not build or qualify every
release's native DPI backend/ABI. No `UVM_NO_DPI` fallback is requested.

| Release | Result | First compile failure / smoke scope |
| --- | --- | --- |
| 1.0p1 | RUNTIME_FAIL | Two callback cast errors remain. Older DPI resolves and L25 removes three placeholder-net diagnostics; U12 correctly rejects the runtime |
| 1.1a | SMOKE_PASS | All smoke checks passed through time1 after U11; zero UVM warnings/errors/fatals |
| 1.1b | COMPILE_FAIL | Undefined `uvm_record_attribute` macro, syntax errors and parser assertion in `uvm_tlm2_generic_payload.svh` |
| 1.1c | COMPILE_FAIL | Undefined `uvm_record_attribute` macro, syntax errors and parser assertion in `uvm_tlm2_generic_payload.svh` |
| 1.1d | SMOKE_PASS | All smoke checks passed through time1 after U09; zero UVM warnings/errors/fatals. Compile-time constraint/codegen warnings remain visible |
| 1.2 | SMOKE_PASS | All smoke checks passed through time1 after U09; zero UVM warnings/errors/fatals. Compile-time constraint/codegen warnings remain visible |
| 2017.0.9 | SMOKE_PASS | All smoke checks passed through time1 after U08; zero UVM warnings/errors/fatals |
| 2017.1.0 | SMOKE_PASS | All smoke checks passed through time1 after U07; zero UVM warnings/errors/fatals |
| 2017.1.1 | SMOKE_PASS | All smoke checks passed through time1 after U07; zero UVM warnings/errors/fatals |
| 2020.1.0 | SMOKE_PASS | All smoke checks passed through time1 after U06; zero UVM warnings/errors/fatals |
| 2020.1.1 | SMOKE_PASS | All smoke checks passed through time1 after U06; zero UVM warnings/errors/fatals |
| 2020.2.0 | SMOKE_PASS | All smoke checks passed; zero UVM warnings/errors/fatals |
| 2020.3.0 | SMOKE_PASS | All smoke checks passed; zero UVM warnings/errors/fatals |
| 2020.3.1 | SMOKE_PASS | All smoke checks passed; zero UVM warnings/errors/fatals |
| 2020.3.2 | SMOKE_PASS | All smoke checks passed after L06/L07; zero UVM warnings/errors/fatals |

All 15 sources were acquired; 12 passed clean compile/runtime smoke, 2 failed
compilation and 1 has disqualifying runtime diagnostics. These are observed compatibility gaps, not waived
requirements or standards-conformance verdicts. U07 classifies unparenthesized member delays as compatibility syntax under
`-gicarus-misc`; strict IEEE mode still requires parentheses. Full UVM regressions,
IEEE1800.2 qualification and unmodified application DV remain separate.

Machine-readable output is in
`third_party/uvm-releases/results-3v03d7qs/results.json`, with per-release
commands, logs, source tree hashes, and compiler/target/preprocessor/VPI/DPI
fingerprints. It records `complete: true` and `baseline_valid: true`.
The script also fingerprints the manifest, itself and the smoke source; changes
during a run invalidate saved row statuses. A smoke pass requires its exact
marker, exit zero, no timeout and zero counts in every UVM summary. Missing
checks or warnings cannot become a pass. Any failed release makes the overall
command exit nonzero while preserving all rows; this matrix intentionally
continues through later releases after an earlier failure.

All release sources remain unmodified. L08, U05, U04 and U06 record the scoped
compiler, DPI and runtime compatibility changes. U01 teardown evidence remains preserved.

- `ivl` SHA-256: `f17dc867ccd3992b52cf50d4dfa2d5f88f228f825973b5c5d439ff909c821419`

- `ivlpp` SHA-256: `04cde56ac3679d5421237d3eeda62b66209d30f001b2d886a691006dbed2e196`

- `vvp` SHA-256: `448929b960a25ee12740f331e68f4206e9e8f79719286e7ba75b550124d814e0`

- `uvm_dpi.vpi` SHA-256: `24b342d192d78adb8780ae725fd457bfb60e5f65da3751bb422b79e4710030f5`

### Legacy regex ABI (U04)

The installed Icarus umbrella now provides the two C entry points imported by original2020.1 UVM: `uvm_re_match` and `uvm_glob_to_re`. Matching delegates strict ERE compilation/execution to the native POSIX library and preserves native compile errors; it does not retry invalid patterns as globs. Raw empty ERE behavior remains native-dependent (Darwin rejects it); explicit `^$` is tested for empty-string matching. See the [POSIX regular-expression specification](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap09.html).

Glob conversion retains the legacy2040-character input limit and documented preservation of slash-delimited regex, using owned expandable storage. It deliberately does not reproduce upstream bracket fall-through or fixed-buffer overflow. Tests cover anchors,metacharacters,2040input/4084expanded output,2048regex acceptance/2049rejection, copied-string lifetime and actual UVM severity/ID counts. Original library sources remain unchanged. Paired2017/2023 tests, original-release ABI4/4 checks, relocated frontendS1-S10 and all required integrated gates passed. Full release qualification remains open as recorded in the matrix.

U06 additionally passed the original2020.1.0 and2020.1.1 smoke in both
explicit2017 and2023 modes (four runs). This qualifies those bounded smoke
checks, not the full releases or IEEE1800.2. Recursive automatic input
passing is repaired; L09, L11 and L10 subsequently repair bounded output
copy-out contexts, defaults and fixed-property elements. Full argument
qualification remains separate.

L13 was reopened when narrow two-state typed-parameter indices were misinterpreted as negative. Corrected source849a779ea passes all required local gates; all15 source fingerprints, statuses and normalized compiler diagnostics match the prior sweep.

L12 removes the original1.1a/1.1d/1.2 printer member-index diagnostics. Other12 normalized compiler logs and all15 source fingerprints match the prior sweep. Compilation now reaches previously blocked1.1d codegen and runtime; its failed checking is not a smoke pass.

L14 removes original1.2 static-local reference errors. It now compiles but times out after300seconds with an empty runtime log; no UVM1.2 smoke or OpenTitan1.2 pass is claimed. Other14 normalized compiler logs and all15 source fingerprints match L12.


### Legacy cached regex ABI (U09)

The pinned UVM1.2 archive includes `src/dpi/uvm_svcmd_dpi.c` and its
SystemVerilog imports. The installed Icarus umbrella now exports
`uvm_dpi_regcomp`, `uvm_dpi_regexec` and `uvm_dpi_regfree` using strict
native POSIX ERE compilation, reusable independent handles and explicit
release. Invalid compilation returns null and reports through UVM when its
callback exists; older libraries without that callback receive a visible
native diagnostic. Historical1.1d diagnostic text identity is not claimed.

Ten focused checks passed: cached/uncached ABI, no reporting callback and
original1.1d/1.2, each under2017/2023. The full release sweep remains in
-g2012. All required integrated and relocated frontend gates passed on
19e7f5592. These results supersede the earlier L12/L14/U08 runtime frontiers,
without claiming full release or OpenTitan qualification.

L15 repairs pasted function-like macro names. All15 source hashes and statuses match U09. Original1.2 OpenTitan now passes its former macro-expansion frontier but fails on assignment to a mutable member through const uvm_top; no application run/pass.

L16 removes the direct const-handle member assignment rejection. Original1.2 OpenTitan replay42522: compiler0/runtime0,9.964s,152requests/288scoreboard items,0UVMwarnings/errors/fatals,TEST PASSED CHECKS and normal finish17625626ps. OverallDEBT from five compile-time null-fallback diagnostics on compound array-member operations; no application qualification. No waived checks/source edits.

L17 supersedes the L16 application frontier: Original1.2 OpenTitan debug-crossbar replay6645: PASS,compiler0/runtime0,10.177s,152hostrequests/288scoreboarditems,0UVMwarnings/errors/fatals,compile semantic debt0/runtime debt0,TEST PASSED CHECKS and normal finish17625626ps. Original corpus7a3ad34 clean;UVMsrcSHA885ba9f74652494aa132aaaa26c43e9f210f94cdf5a8d3a87064993ec9b35dc0 unchanged. Actual -g2012,one default-seed smoke invocation;no paired-edition/multi-seed/full OpenTitan qualification. Two existing benign runtime lines report discarded $system return value.

The host sequence joins request and response loops before logging completion.
The scoreboard check phase checks expected/actual counts, then verifies all
item/timestamp queues and input FIFOs are empty. The replay reaches that phase
with zero errors and no caught/demoted reports. Counts are not assumed to map
one-to-one: mapped and unmapped transactions follow different paths. Evidence:
`evidence/campaign-20260908/l17/opentitan/result.json` and adjacent raw logs/
`checking-source-notes.md`. No upstream application/library edits or check waivers.

L22 retains11/15 bounded smoke passes with identical original source fingerprints.
Original1.0p1 now recognizes process::state and proceeds to later errors; this
is compile progress, not a new release pass. The application smoke above remains
revision-scoped to L17, not a fresh L22 OpenTitan replay.

L23 removes the nested-background fork errors from original1.0p1/1.1a. Each
now stops at three dedicated void-cast-statement calls of void functions; no
new smoke pass or upstream-invalid classification is asserted. All15 source
and archive fingerprints and result statuses remain unchanged.

L24 permits the dedicated void-function statements; original1.0p1/1.1a now
compile and start. Both fail at the older DPI ABI, so neither gains a smoke pass.
All15 original source/archive fingerprints remain unchanged.

U11 supplies the old1.0p1/1.1a command-line/regex ABI and clears missing-DPI errors.
The historical U11 raw report said13SMOKE_PASS; its1.0p1 row was explicitly
disqualified by review. U12 fixes that classifier defect. The current fresh
report records12SMOKE_PASS,1RUNTIME_FAIL,2COMPILE_FAIL automatically.

L25 removes the three missing return-storage placeholder diagnostics from1.0p1;
its callback casts still fail. All15 originalsource/status fingerprints stay unchanged.

L26 replay at e3666fd07 (`results-8054igtp`) preserves all15 release statuses
and original source/archive hashes:12 smoke passes,1 runtime failure,2 compile
failures. Original1.0p1 retains both callback cast errors; the bounded class-default
identity fix is not an additional release pass. All required local gates passed.

L27 replay at8f2252dd3 (`results-ni3wgjii`) again preserves all15 statuses and
original source/archive hashes:12 smoke passes,1 runtime failure,2 compile
failures. Generic-master initializer removal does not resolve original1.0p1's
two callback cast errors. All required local gates passed.
