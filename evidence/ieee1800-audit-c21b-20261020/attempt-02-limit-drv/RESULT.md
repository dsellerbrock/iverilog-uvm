# Result

Slurm job 3553 completed with exit code 0 on DAN-DESKTOP in 1 second (1 CPU, 1 GiB requested). Compiler and VVP hashes are recorded in [sha256.txt](remote-3553/sha256.txt); the exact command and outputs are in [run.sbatch](remote-3553/run.sbatch) and [slurm-3553.out](remote-3553/slurm-3553.out). Each compile and simulation had a 30-second timeout.

Both probes compiled and ran successfully under `-g2017` and `-g2023`. All eight compile/run return codes are zero. For each probe, the 2017 and 2023 EVCD files are byte-identical.

## §21.7.3.4 and §21.7.3.7

The 200-byte limit was reached during initial dumping. `lim.evcd` contains the header, the initial low input record, the required `Dumpports file size limit (200 bytes) reached` comment, and the final `$vcdclose`; it contains no subsequent value records despite 50 scheduled toggles. The file is 299 bytes total: 216 bytes precede the comment, so the threshold was crossed by 16 bytes before the marker; the comment and close record add the remaining 83 bytes. The resulting overage comes from the final record/header crossing and the required marker/close records; no later value data is dumped.

At time 2 the probe called `$dumpportsoff("unmatched.evcd")`. It produced no diagnostic. The independent unlimited `control.evcd` continued recording through time 52000, with 52 time checkpoints and no `$dumpportsoff` marker. This shows the unmatched filename did not disable the other open file. Both tasks behaved the same in both editions.

## §21.7.4.3.2

The port-state character for `<0` matched the expected continuous-driver cases:

| Time | Drivers | Expected | Observed |
|---:|---|:---:|:---:|
| 1000 | strong input low only | `D` | `D` |
| 2000 | strong input low + weak output low | `d` | `d` |
| 3000 | weak input low + strong output low | `l` | `l` |
| 4000 | equal strong input/output low | `0` | `0` |
| 5000 | equal weak input/output low | `0` | `0` |
| 6000 | both sides three-stated | `F` | `F` |

Observed strength digits also track the active strong/weak ranges (`p0 6 0` for equal strong drivers and `p0 3 0` for equal weak drivers). No mismatch was found; no new issue was filed.
