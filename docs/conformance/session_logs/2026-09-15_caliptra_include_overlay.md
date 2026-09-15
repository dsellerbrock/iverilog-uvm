# Caliptra include adapter and first runtime replay — 2026-09-15

The read-only [adapter](../../../scripts/caliptra_include_overlay.py) resolves
upstream RTL provider directories plus seven source-demonstrated supplemental
header dependencies. It does not edit the corpus, reorder source files,
change tops or override parameters. Duplicate providers, cycles, missing
providers, unresolved variables and nonexistent or relative directories fail
explicitly. Standard register-header jobs exclude `caliptra_reg_ss`.

Use Python with PyYAML. Run `python scripts/caliptra_include_overlay.py
--corpus-root /absolute/caliptra-rtl --job decompose` to emit ordered include
directories and their provider provenance; repeated `--job` and explicit
`--env NAME=VALUE` are supported. Default adapter tests are synthetic;
`python tests/test_caliptra_include_overlay.py --corpus-root
/absolute/caliptra-rtl` additionally checks the pinned 40-job selection.

The coordinator ran all six adapter checks and the 40 selected compiler
commands with assertions enabled and disabled. Each mode produced 23 clean
compilations, two warning-only compilations and 15 failures. This confirms the
configuration correction; it is not a new whole-census total or a semantic
feature count. Remaining failures are retained in the
[revision-scoped record](2026-09-15_caliptra_include_overlay_validation.json).

The unmodified Adams Bridge `power2round_tb` then compiled for VVP with the
same provider inputs. Its metadata-required Python generator ran under native
ARM64 Python with NumPy2.3.5 and produced all three2048-record vector files.
Simulation terminated normally but printed `TESTCASE FAILED`: zero public-key
writes were observed against expected256. Exit zero does not override that
failed checking verdict. No application runtime pass is claimed; a non-driving observer subsequently confirmed an upstream wiring omission. The record retains the vector hashes, tool identity,
commands, warnings and full runtime verdict. Corpus sources remain unchanged.

The observer replay records 256 read requests and 256 TB valid pulses, but
zero known cycles on DUT `mem_rd_data_valid` and zero writes. The DUT input
remains `Z` because `power2round_tb.sv:90` comments out its connection. This is
a source/configuration failure; no compiler change can honestly synthesize the
missing connection. Original failure and observer replay are both preserved,
with independent vector hashes. No upstream patch was applied.
