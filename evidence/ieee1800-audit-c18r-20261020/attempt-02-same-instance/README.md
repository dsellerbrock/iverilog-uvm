# §18.14.1 initialization RNG probe, same instance

Probe: `tests/1800_audit/c18/p18_14_initialization_rng.sv`.

IEEE 1800-2017 §18.14.1 (pp. 540–541) and IEEE 1800-2023 §18.14.1
(pp. 561–562) require an initialization RNG for each module instance and say
static processes are seeded from it. The probe compiles the same top-level
module twice. The second build appends a static process after the original
processes; both runs use the same Icarus-specific `+ntb_random_seed` so their
first two `$urandom()` results can be compared. Each build was run twice as a
replay control. This avoids comparing separate module-instance RNGs.

Source commit: `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`.
Probe SHA-256: `938157b43cc9f7f0b010f94b983a4df6daf1f1c875332da805953d89c46ea491`.
Slurm job: `3574` on `DAN-DESKTOP`, one CPU and 1 GiB requested. The pinned
compiler is Icarus 13.0-devel from the `fb584a25` source snapshot
(`iverilog` SHA-256 `9760f8c1ab8ad03d64761b257db74ff07603a15c4d44d2bcdba75073f006911c`).

Both editions compiled and ran both variants successfully. Baseline replay and
appended-process replay matched; the baseline and appended-process runs also
matched. For each edition, the two existing processes returned `first=2887658792`
and `second=2538823573`. Raw logs and result are retained under this directory.
