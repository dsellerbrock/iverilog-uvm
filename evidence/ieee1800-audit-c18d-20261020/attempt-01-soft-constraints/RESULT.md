# Result: §18.5.14 soft constraints

Slurm job 3386 completed with exit code 0 on exact current main `cc25756d187314742d347267c2a513b3e640a7fb`. Both probes were run under `-g2017` and `-g2023`; every compiler and simulator process had a 20-second process-group timeout.

| Edition | Probe | Compile rc | Run rc | Result |
|---|---|---:|---:|---|
| 2017 | `p18_05_soft.sv` | 0 | 0 | `RESULT pass=9 fail=0` |
| 2017 | `neg_n18_soft_randc.sv` | 1 | — | Rejected with `randc variables cannot be used in 'soft' constraints` |
| 2023 | `p18_05_soft.sv` | 0 | 0 | `RESULT pass=9 fail=0` |
| 2023 | `neg_n18_soft_randc.sv` | 1 | — | Rejected with `randc variables cannot be used in 'soft' constraints` |

The positive checks cover soft-constraint dropping, declaration order, derived-class priority, `disable soft`, hard-constraint priority, and inline constraints. The warning about a 32-bit `randc` cyclic leaf is incidental; the expected compile-time error followed in both editions. Lead classification is pending; no issue or matrix status was changed in this attempt.
