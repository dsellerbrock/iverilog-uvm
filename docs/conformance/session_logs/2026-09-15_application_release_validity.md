# Application release validity audit — 2026-09-15

## Release identity

Both current corpora are clean, reproducible upstream development snapshots,
not tagged stable-release checkouts. Existing results remain valid only for
the exact recorded snapshots and simulator artifacts.

| Corpus | Tested pin | Release disposition |
| --- | --- | --- |
| OpenTitan | `7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19` | Untagged upstream commit; all official direct and annotated tags checked. |
| Caliptra | `bd31614182fb56e55578f48086a10ded650434fd` | Development snapshot, `v2.1-70-gbd316141`; not the stable patch branch. |
| Adams Bridge | `e59eba955eac2a1adcb059f250641ede78e304be` | Development snapshot; exactly matches the Caliptra parent gitlink. |

Official [OpenTitan releases](https://github.com/lowRISC/opentitan/releases)
separate the Earlgrey production hardware milestone `Earlgrey-PROD-M6` from
Earlgrey 1.0.0 development bundles. The August 21 bundle is a prerelease;
the June 2 bundle contains built tools, bitstreams, and a Verilated simulator.
Neither establishes release qualification for our Darjeeling crossbar run.
Selecting an Earlgrey release would change the application target scope and
requires its own fresh baseline. Do not relabel the Darjeeling result.

The latest official stable [Caliptra v2.1.2](https://github.com/chipsalliance/caliptra-rtl/releases/tag/v2.1.2)
is `49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e`, with gitlinked
[Adams Bridge v2.0.3](https://github.com/chipsalliance/adams-bridge/releases/tag/v2.0.3)
at `b77e3d899e828d626cfc2a0d26a6b5704cc121e0`. These stable patch branches
diverge from the tested development snapshots; a newer commit date does not
prove inclusion of release fixes. No stable-release runtime qualification is
claimed. No corpus checkout or dependency was changed during this audit.

## What the existing evidence establishes

- OpenTitan's `lowrisc:dv:top_darjeeling_xbar_dbg_sim:0.1` is an actual upstream
  simulation target at the pin. Its configuration imports the common crossbar
  tests and defaults to VCS; upstream VCS settings select UVM 1.2. Original
  UVM 1.2 is therefore a valid library choice for this workload. The recorded
  [checked smoke runs](2026-09-15_runtime_root_seed.md) are real snapshot-level
  runtime passes. They do not establish all crossbar tests, full chip DV,
  coverage closure, or stable-release qualification.
- Caliptra's parent and submodule revisions match. Its compile metadata really
  includes the Adams component benches. The [include replay](2026-09-15_caliptra_include_overlay.md)
  establishes selected compilation outcomes, not full-census or runtime passes.
- `power2round_tb` has a source wiring defect: the DUT valid input connection
  is commented out. The observer sees the DUT input as Z, despite testbench
  valid pulses. The same commented connection and relevant compile metadata
  exist in Adams `v2.0`, `v2.0.3`, and the tested development pin. **Correction
  after the stable switch:** this alone did not establish a stable bench defect.
  Stable RTL generates valid internally; the development RTL exposes an input.
  Fresh unmodified stable execution reports 2048 cases passed. The earlier
  inference that stable would also fail is withdrawn; the development failure
  remains valid only for its recorded protocol and revision. Stronger observer
  checks are being captured in the stable baseline evidence.
- Other missing providers, stale ports/parameters, source ordering, and huge
  default-top arrays require individual attribution. Availability in a compile
  specification alone does not establish a valid release-signoff configuration.

## Evidence and next baseline

Raw official API responses, local identity checks, tag peeling, and Caliptra
source comparisons are preserved under
`evidence/application-check-20260915/release-audit/`.
For future release-labeled Caliptra results, select `v2.1.2` and its exact
submodule gitlink and run fresh checks. Keep the existing development-snapshot
results separate. For OpenTitan, identify Earlgrey production versus Darjeeling
DV scope before selecting a release baseline. Preserve the working Darjeeling
smoke as a compiler regression application. These are baseline requirements,
not claims of additional successful simulation.
