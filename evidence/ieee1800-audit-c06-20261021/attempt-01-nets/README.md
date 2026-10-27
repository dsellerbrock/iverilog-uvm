# Clause 6.6 net-type probes

Lead-selected standalone probes for IEEE 1800-2017 and 1800-2023 §§6.6–6.6.8. Each source is compiled independently under both editions with the pinned Icarus toolchain. Each compile and run has a 30-second process-group timeout.

| Case | Coverage | Expected |
|---|---|---|
| T1 | wire and tri, Table 6-2, all 16 pairs from {0,1,x,z} | Both net kinds produce the standard resolved value. |
| T2 | wand and triand, Table 6-3, all 16 pairs | Any zero driver dominates; otherwise standard four-state resolution. |
| T3 | wor and trior, Table 6-4, all 16 pairs | Any one driver dominates; otherwise standard four-state resolution. |
| T4 | tri0 and tri1, Tables 6-5 and 6-6, all pairs and undriven strengths | Pull values resolve correctly; undriven strengths print Pu0/Pu1. |
| T5 | supply0/supply1 strength and value | Values 0/1 and Su0/Su1 strengths. |
| T6 | undriven wire | z. |
| T7 | uwire with two continuous drivers | Compile-time error. |
| U1 | standard T/Tsum user-defined resolving nettype example | Two real drivers resolve to field1 = 3.5. |
| U2 | alias of the resolved user-defined nettype | The aliased net also resolves to 3.5. |
| U3 | force and release on a resolved user-defined net | Prints forced 9.0 then resolved 3.5. |
| U4 | unresolved user-defined nettype with two drivers | Compile-time error. |
| I1 | interconnect connected only through module ports | Compiles/runs and prints 1. |
| I2 | continuous assignment to interconnect | Compile-time error. |
| I3 | procedural expression using interconnect | Compile-time error. |

Standard references: IEEE 1800-2017 §§6.6–6.6.8, Tables 6-2 through 6-6 (printed pp. 86–94); IEEE 1800-2023 corresponding clauses and tables, checked by the audit lead. This evidence records probe outcomes, not unprobed behavior.
