# Clause 25.5 / 25.9 modport and clocking results

Pinned Icarus 13.0 devel `cc25756d1` from `/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb`; DAN-DESKTOP, one CPU and 1 GiB. Slurm jobs 3778 and 3779 completed with exit 0:0. Every compile/run used a 30-second timeout and both `-g2017` and `-g2023`. Scheduler records, raw logs, exact source hashes, and normalized results are retained under `raw-slurm-3778/` and `n2-followup/raw-slurm-3779/`.

## Standards checked

The selected wording is the same in both supplied editions:

- IEEE 1800-2017 §25.5.4, printed pp. 758–759; IEEE 1800-2023 §25.5.4, pp. 790–791. The standard's own `I`/`M` example uses `.P(r[3:0])` and `.Q(x)` and prints `00100001`. It also says the `Q` port cannot be output or inout because its expression is constant.
- IEEE 1800-2017 §25.5.5, p. 759; IEEE 1800-2023 §25.5.5, p. 791: all clocking blocks used in a modport must be declared by the same interface.
- IEEE 1800-2017 §§25.9.1–25.9.2, pp. 771–772; IEEE 1800-2023 §§25.9.1–25.9.2, pp. 803–804. Clocking blocks can be accessed through virtual interfaces; modport-selected virtual interfaces expose the clocking block through the corresponding modport. The §25.9 `PBus` example marks assigning a selected-modport VIF to an unmodded VIF illegal and the reverse direction legal.

## Paired outcomes

| Case | `-g2017` | `-g2023` | Finding |
| --- | --- | --- | --- |
| I1 standard §25.5.4 modport-expression example | compile rc 2; `Class I does not have a property P` twice | same | Required example fails; lead filed #932. |
| I2 constant expression declared as output | compile rc 1; `Class I does not have a property Q` | same | Confounded by the same named-expression failure as I1. The rule remains untested until #932 is fixed; no second issue. |
| I3a modport clocking access | compile/run 0/0; `granted 25` | same | Pass. |
| I3b class-held `virtual A_Bus.STB` clocking access | compile/run 0/0; `granted 25` | same | Pass. |
| I4a virtual-interface array, zero-cycle drive | compile/run 0/0; `0 0` | same | Pass. |
| I4b standard `##1` clocking drive branch | compile rc 1; VVP reports `this nonblocking property assignment form is not yet supported without changing its NBA semantics` | same | Exact overlap with #906; no new issue. Posted paired evidence on #906: https://github.com/dsellerbrock/iverilog-uvm/issues/906#issuecomment-6321007598. |
| N1a selected-modport VIF assigned to unmodded VIF | compile rc 1; assignment-compatibility error cites §25.9 | same | Correctly rejected. |
| N1b selected-modport interface instance assigned to unmodded VIF | same required error | same | Correctly rejected. |
| N1c legal assignment directions from the standard example | compile/run 0/0; `legal` | same | Pass. |
| Initial N2 declaration-only source | compile rc 0, no diagnostic | same | Inconclusive by itself because M2 was never elaborated. |
| N2b elaborated outside-interface clocking item | compile rc 1; `Class A_Bus has no property cbx` on `p.cbx` | same | The used modport is rejected. |
| N2c same-interface clocking control | compile/run 0/0; `tick 5` | same | Pass. |

## Classification and issue accounting

| Clause | Classification | Probe summary | Issue |
| --- | --- | --- | --- |
| §25.5.4 | PARTIAL | The standard's modport-expression example fails; the constant-expression output restriction is untestable until the expression form resolves. | #932 |
| §25.5.5 | IMPLEMENTED (tested subset) | Modport clocking access passes; N2b is rejected when elaborated and N2c passes. An unused declaration naming an outside clocking block is accepted; this declaration-time check is tracked by #813. | #813 scope comment |
| §25.9.1 | PARTIAL | Virtual-interface array access passes for the zero-cycle drive; the `##1` branch fails with #906's exact code-generation diagnostic. | #906 |
| §25.9.2 | IMPLEMENTED (tested subset) | A class-held modport virtual interface drives and samples through its clocking block. | — |
| §25.9 | Existing row refined | N1a/N1b reject the illegal selected-to-unmodded assignments; N1c passes the legal assignments. | Existing |

Fresh prefiling open+closed dedupe snapshot: 435 issues (308 open, 127 closed). The dedupe terms, exact-diagnostic search, and related issues are recorded in `DEDUPE.md`. The lead created #932 after the exact standard-example failure and no duplicate hit. No new issue was filed for N2 because #813 already covers the same-interface name-resolution family; its scope comment is at https://github.com/dsellerbrock/iverilog-uvm/issues/813#issuecomment-6320861717.

New issue count for this tranche: §25.5.4 +1 (#932); §25.5.5, §25.9.1, and §25.9.2 +0. Clause 25's current sweep count is +2 (#921 and #932).
