# §18.5.13 constraint guards (IEEE 1800-2023 §18.5.12)

**Classification from the audit lead: IMPLEMENTED in the tested subset; no conformance gap.** The probe reproduces the standard's Examples 1 and 2 in both editions on Slurm job 3490, using Icarus 13.0-devel `cc25756d1`. Both editions compiled and ran successfully (about 0.5 s, 41 MiB RSS each). Source: `tests/1800_audit/c18/p18_05_13_guards.sv`; the exact outputs and diagnostics are in `results/logs/`.

| Case | 2017 output | 2023 output | Lead's interpretation under Figure 18-3 |
|---|---|---|---|
| E1C1 | `ok=50 bad=0 sum10=50` | same | TRUE guard makes the implication unconditional; the null `b` term does not change the final guard value |
| E1C2 | `ok=0 bad=0 sum10=0` | same | ERROR guard causes each `randomize()` call to fail |
| E1C3 | `ok=50 bad=0 sum10=0` | same | RANDOM guard leaves a conditional implication; with uniform 32-bit variables, satisfying `x<y` and `x+y==10` is vanishingly rare |
| E2C1 | `ok=50 bad=21 sum10=0` | same | FALSE guard eliminates the implication despite null `b`; 21 unconstrained `x<y` samples are positive evidence |
| E2C2 | `ok=0 bad=0 sum10=0` | same | ERROR guard causes each `randomize()` call to fail |
| E2C3 | `ok=50 bad=0 sum10=0` | same | RANDOM guard leaves a conditional implication; the constrained solutions are a negligible fraction of the full 32-bit pair space |

Each original run log contains 100 copies of `ERROR: constraint state read: null/invalid constraint object path.` before the first stdout case label. Because stderr may be unbuffered while stdout is buffered, the original log does not identify the source case. A flushed-marker follow-up in [the §8.26 batch](../../ieee1800-audit-c08k-20261020/attempt-01-iface/) confirms that 50 are emitted during E1C2. The other 50, likely from E2C2, have not yet been independently attributed. This does not change the standards classification.

The standard's four-valued guard behavior is in 2017 §18.5.13, Figure 18-3, pp. 522–524; 2023 §18.5.12. No issue was filed.
