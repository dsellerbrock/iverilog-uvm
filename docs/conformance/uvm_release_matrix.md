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

2026-09-10, native ARM64, validated source `c9626a449` (U08 inherited method lookup).
The release sweep and all required U08 local validation gates are complete.
Actual mode: `-g2012`. Each command has a 300-second per-process CPU guard
and a configurable wall timeout (300 seconds by default), with no RSS cap.
The smoke checks factory creation, clone/field copy and independence, phase
execution/objections, positive/negative DPI regex and a timed DPI HDL read.
It uses the installed Icarus DPI backend; it does not build or qualify every
release's native DPI backend/ABI. No `UVM_NO_DPI` fallback is requested.

| Release | Result | First compile failure / smoke scope |
| --- | --- | --- |
| 1.0p1 | COMPILE_FAIL | `process` class lookup |
| 1.1a | COMPILE_FAIL | Fork/join_any in function and void casts of void functions; standards legality remains to be assessed |
| 1.1b | COMPILE_FAIL | Undefined `uvm_record_attribute` macro, syntax errors and parser assertion in `uvm_tlm2_generic_payload.svh` |
| 1.1c | COMPILE_FAIL | Undefined `uvm_record_attribute` macro, syntax errors and parser assertion in `uvm_tlm2_generic_payload.svh` |
| 1.1d | RUNTIME_FAIL | Missing `uvm_dpi_regcomp`; four UVM errors and one fatal before smoke completion; codegen fallback warnings remain visible |
| 1.2 | RUNTIME_FAIL | Root recursion removed; missing `uvm_dpi_regcomp`, five UVM errors and one fatal before smoke completion. Constraint/codegen warnings remain visible |
| 2017.0.9 | SMOKE_PASS | All smoke checks passed through time1 after U08; zero UVM warnings/errors/fatals |
| 2017.1.0 | SMOKE_PASS | All smoke checks passed through time1 after U07; zero UVM warnings/errors/fatals |
| 2017.1.1 | SMOKE_PASS | All smoke checks passed through time1 after U07; zero UVM warnings/errors/fatals |
| 2020.1.0 | SMOKE_PASS | All smoke checks passed through time1 after U06; zero UVM warnings/errors/fatals |
| 2020.1.1 | SMOKE_PASS | All smoke checks passed through time1 after U06; zero UVM warnings/errors/fatals |
| 2020.2.0 | SMOKE_PASS | All smoke checks passed; zero UVM warnings/errors/fatals |
| 2020.3.0 | SMOKE_PASS | All smoke checks passed; zero UVM warnings/errors/fatals |
| 2020.3.1 | SMOKE_PASS | All smoke checks passed; zero UVM warnings/errors/fatals |
| 2020.3.2 | SMOKE_PASS | All smoke checks passed after L06/L07; zero UVM warnings/errors/fatals |

All 15 sources were acquired; 9 passed compile plus runtime smoke, 4 failed
compilation and 2 failed runtime checking. These are observed compatibility gaps, not waived
requirements or standards-conformance verdicts. U07 classifies unparenthesized member delays as compatibility syntax under
`-gicarus-misc`; strict IEEE mode still requires parentheses. Full UVM regressions,
IEEE1800.2 qualification and unmodified application DV remain separate.

Machine-readable output is in
`third_party/uvm-releases/results-eb3ghca7/results.json`, with per-release
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

- `ivl` SHA-256: `aa57713aeb8493c09fa1da2015a17d46a7df2d37f57b51875336dfc986a37faf`

- `ivlpp` SHA-256: `8e378933711e11da81e2df44c4210e01bf8e1795acc634d3f0cdb1a1feb1c7f9`

- `vvp` SHA-256: `448929b960a25ee12740f331e68f4206e9e8f79719286e7ba75b550124d814e0`

- `uvm_dpi.vpi` SHA-256: `e69ec1f7d0d0d94668656c50fb83982241ad912fd229464a365fc5b278c28d5a`

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
