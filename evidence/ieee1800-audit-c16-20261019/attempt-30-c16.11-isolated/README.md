# IEEE 1800 §16.11 isolated probes

Job 3200 established that the local-variable-by-value argument case fails at the sequence match-item call, but the combined positive source could not run its zero-argument calls after that failure. This run separates them and reruns the existing regression that covers `$display`, a user task, and void-function calls in both editions. It also reruns the semantically valid §16.10 increment probe and the §16.11 empty-match rejection case.

- Slurm job: `3201` on `DAN-DESKTOP`, 2026-10-19 15:48 MDT; request was 1 CPU, 1 GiB, 10 minutes. Start/finish are in the same second; the remote run directory was removed after copying results.
- Toolchain: Icarus from main `c31cbf1b52f1a39d5775f276e2340525a444a79e`; binary hashes are in `results/sha256.txt`.
- The existing `sv_sva_cover_match_item_runtime.v` regression compiled and ran exit 0 in both editions; its output was `MATCH`, `MATCH`, `PASSED`. This verifies direct system `$display`, zero-argument user void functions, and a delayed user task on nonempty sequence matches.
- Passing a local variable to a user task attached as a match item fails compilation in both editions with the diagnostic that only direct `$display` and zero-argument user calls are currently supported. This confirms a §16.11 gap.
- The empty-match attachment probe is rejected with a syntax error at the attachment in both editions. The required rejection is observed, but the compiler gives no empty-match-specific diagnostic; the cause may overlap the §16.10 composite-sequence parser gap.
- The semantically valid §16.10 local-variable increment probe (`count = 0`, followed by `count++`) fails syntax at the increment item in both editions.

- Slurm job: `3201` on `DAN-DESKTOP`, 2026-10-19 15:48 MDT; request was 1 CPU, 1 GiB, 10 minutes. The batch metadata has same-second start and finish; the remote run directory was removed after copying results.
- Toolchain: Icarus from main `c31cbf1b52f1a39d5775f276e2340525a444a79e`; hashes are in `results/sha256.txt`.
- The existing runtime regression `ivtest/ivltests/sv_sva_cover_match_item_runtime.v` compiled and ran exit 0 in both editions; output was `MATCH`, `MATCH`, `PASSED`. It exercises direct `$display`, zero-argument user void functions and a delayed task call attached to nonempty sequence matches.
- `p16_11_local_argument.sv` fails compilation in both editions with: `sequence match-item subroutine calls currently support only direct $display calls or zero-argument user calls in a cover property ...`; no runtime occurred. The empty-match attachment probe is rejected with a syntax error at the match-item line in both editions (the compiler does not give a rule-specific empty-match diagnostic).
- The corrected §16.10 probe initializes its local through a match-item assignment before `count++`, but still fails syntax at the increment match item in both editions. This confirms the #718 gap with a semantically valid target.
