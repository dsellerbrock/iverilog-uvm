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

2026-09-10, native ARM64, validated compiler/runtime implementation `9a1b6beb3`.
Actual mode: `-g2012`. Each command has a 300-second per-process CPU guard
and a configurable wall timeout (300 seconds by default), with no RSS cap.
The smoke checks factory creation, clone/field copy and independence, phase
execution/objections, positive/negative DPI regex and a timed DPI HDL read.
It uses the installed Icarus DPI backend; it does not build or qualify every
release's native DPI backend/ABI. No `UVM_NO_DPI` fallback is requested.

| Release | Result | First compile failure / smoke scope |
| --- | --- | --- |
| 1.0p1 | COMPILE_FAIL | `process` class lookup, followed by component delay syntax |
| 1.1a | COMPILE_FAIL | Unparenthesized member delay in `uvm_component.svh` |
| 1.1b | COMPILE_FAIL | Unparenthesized member delay in `uvm_component.svh` |
| 1.1c | COMPILE_FAIL | Unparenthesized member delay in `uvm_component.svh` |
| 1.1d | COMPILE_FAIL | Unparenthesized member delay in `uvm_component.svh` |
| 1.2 | COMPILE_FAIL | Unparenthesized member delay in `uvm_component.svh` |
| 2017.0.9 | COMPILE_FAIL | Unparenthesized member delay in `uvm_component.svh` |
| 2017.1.0 | COMPILE_FAIL | Unparenthesized member delay in `uvm_component.svh` |
| 2017.1.1 | COMPILE_FAIL | Unparenthesized member delay in `uvm_component.svh` |
| 2020.1.0 | COMPILE_FAIL | Resource queue type parameter / assignment compatibility |
| 2020.1.1 | COMPILE_FAIL | Resource queue type parameter / assignment compatibility |
| 2020.2.0 | SMOKE_PASS | All smoke checks passed; zero UVM warnings/errors/fatals |
| 2020.3.0 | SMOKE_PASS | All smoke checks passed; zero UVM warnings/errors/fatals |
| 2020.3.1 | SMOKE_PASS | All smoke checks passed; zero UVM warnings/errors/fatals |
| 2020.3.2 | SMOKE_PASS | All smoke checks passed after L06/L07; zero UVM warnings/errors/fatals |

All 15 sources were acquired; 4 passed compile plus runtime smoke and 11
failed compilation. These are observed compatibility gaps, not waived
requirements or standards-conformance verdicts. The first syntax failure in a
legacy library still needs classification against the applicable language
edition before being called a compiler defect. Full UVM regressions,
IEEE1800.2 qualification and unmodified application DV remain separate.

Machine-readable output is in
`third_party/uvm-releases/results-jdbvlt0_/results.json`, with per-release
commands, logs, source tree hashes, and compiler/target/preprocessor/VPI/DPI
fingerprints. It records `complete: true` and `baseline_valid: true`.
The script also fingerprints the manifest, itself and the smoke source; changes
during a run invalidate saved row statuses. A smoke pass requires its exact
marker, exit zero, no timeout and zero counts in every UVM summary. Missing
checks or warnings cannot become a pass. Any failed release makes the overall
command exit nonzero while preserving all rows; this matrix intentionally
continues through later releases after an earlier failure.

The default library/toolchain is not changed and no release compatibility
fixes are included in U02. U01 OpenTitan teardown evidence remains preserved.

- `ivl` SHA-256: `07b302c2c24b66f0b034ae225fc51a621eded450e565c9cd40d26aedc4d91d8a`

- `ivlpp` SHA-256: `8e378933711e11da81e2df44c4210e01bf8e1795acc634d3f0cdb1a1feb1c7f9`

- `vvp` SHA-256: `3b162fd92a10cb221af69321fc072bda01c04f3a5fd62445b89e869d470a1337`

- `uvm_dpi.vpi` SHA-256: `23a2d7a5a0696d0102f7ad254a7c142688202824caf19772c5583b74ecc85dd1`
