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

## Latest recorded smoke result

The [2026-09-14 L64 qualification record](session_logs/2026-09-14_constraint_function_presolve_qualification.json)
records **15 release smoke passes** on semantic revision `4bc02c51b`.
See its [final seven-gate account](session_logs/2026-09-14_constraint_function_presolve.md#final-seven-gate-qualification)
for validation scope. This supersedes the older 13-pass/two-compile-failure
checkpoint; it is not a fresh run on this documentation branch.

The release runner uses `-g2012` and the installed Icarus DPI backend.
The smoke checks factory creation, clone/copy independence, phasing and
objections, regex behavior, and a timed HDL read. It does not qualify every
release's original native DPI backend, all library features, IEEE 1800.2,
or a complete DV application. Per-release sources remain pinned and unmodified;
compiler-side compatibility support must be distinguished from strict IEEE
language support. In particular, 1.1b/1.1c recording-macro compatibility is not
complete recording qualification.

Each run writes per-release commands, diagnostics, source hashes, tool
fingerprints, and statuses to its results directory. `complete` means every
row was attempted; `baseline_valid` requires stable inputs/tools. Inspect both,
individual statuses, diagnostics, and DPI mode. An available release, successful
compile, or warning about missing semantics is not a qualified feature.

## Legacy compatibility

- Legacy dotted-name delays (`#setting.offset`) require `-gicarus-misc`, enabled
  by default. Strict IEEE syntax uses `#(setting.offset)`.
- The installed backend supplies legacy command-line and cached/uncached regex
  entry points. Native POSIX regex details can differ by platform; invalid
  patterns are not retried as globs.
- UVM 1.1d has an explicit recording adapter. Its lifecycle and typed-attribute
  checks are separate from release smoke results; do not infer automatic setup
  or complete recording support from a smoke pass. See
  [`test_legacy_recording.py`](../../tests/uvm_releases/test_legacy_recording.py)
  and [`uvm_legacy_recorder.svh`](../../uvm_dpi/uvm_legacy_recorder.svh).

## Historical results

The [release history](session_logs/2026-09-14_uvm_release_history.md) retains
older per-release failures, source/tool hashes, ABI fixes, recording milestones,
and the scoped OpenTitan UVM 1.2 debug-crossbar witness. Those results describe
their named revisions. [CURRENT_WORK](CURRENT_WORK.md) points to the newest
committed compiler and application evidence.

A newer, separate result — OpenTitan's `xbar_smoke` reaching `TEST PASSED
CHECKS` against a stable Earlgrey-PROD-M6 release — is recorded in
[2026-09-15_opentitan_xbar_smoke_patched.md](session_logs/2026-09-15_opentitan_xbar_smoke_patched.md).
**It is a patched-release result** (one OpenTitan source file corrected for a
nonstandard `foreach` spelling), not an unmodified-source pass; do not cite it
as satisfying application objective 5 without that caveat.
