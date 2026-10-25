# IEEE 1800 uniqueness constraints, §18.5.5 / §18.5.4

- Standard text checked directly: IEEE 1800-2017 §18.5.5, p. 513; IEEE 1800-2023 §18.5.4, p. 534.
- The lead-directed probe covers scalar and unpacked-array members, equivalent types, the `randc` restriction, expression rejection, the fewer-than-two-members rule, and the 2023 real-member addition. Shape isolation is included after U1's failure. A scalar-only real case isolates 2023 §18.5.4 from the real-array shape currently reported by #463. The 2017 real-member compile is only a control: `rand real` itself is disallowed by §18.4 in that edition.
- Inputs are copied from `tests/1800_audit/c18/` and hashed in `SHA256SUMS-input.txt`; `run_with_timeout.py` kills each compile/run process group after 30 seconds.
- Slurm job 3442 ran on DAN-DESKTOP with 1 CPU / 1 GiB from 15:20:39Z to 15:20:44Z. Each compile/run had a 30-second process-group timeout. Toolchain and per-input hashes, version, result table and full logs are in `remote-results-3442/`; Slurm accounting is disabled, so peak RSS is unavailable.
- Dedupe queries searched open and closed issues and are recorded in `dedupe-open-closed.txt`; #463 was also inspected because it covers remaining `rand real` forms.

Expected results per the lead: in both editions U1 `rc_ok=500 bad=0`; U2 `bad=0` and at least 20 distinct permutations; U3 `rc=0`; U4 `rc=1 s=1`; U5 `bad=0`; the three negative controls should fail compilation. In 2023, the real test should produce `R1 ok=100 bad=0 R2 ok=100 bad=0 R3 rc=0`; a 2017 compile rejection is conforming.
