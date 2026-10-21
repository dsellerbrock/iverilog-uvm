# Open and closed issue dedupe — 2026-10-21

Snapshot: `dedupe-latest.json`, fetched from `dsellerbrock/iverilog-uvm` with `gh issue list --state all --limit 1000 --json number,title,state,labels,body,url`; 435 total issues, 308 open and 127 closed.

Searched titles and bodies across both states for: `modport expression`, `port expression`, `modport clocking`, `virtual interface modport`, `virtual interface clocking`, `selected modport`, and §§25.5.4, 25.5.5, 25.9.1 and 25.9.2. The only broad text hit was #767, an unrelated §6.10 undeclared-identifier issue; no candidate duplicate found.

Reviewed nearby issues explicitly:

- #813 (open, §25.5): undeclared or enclosing-scope names in a modport; separate from valid modport port expressions and clocking-block association.
- #815 (open, §25.9): null virtual-interface dereference must be fatal; separate run-time rule.
- #816 (open, §25.9): virtual-interface component accepted in continuous assignment; separate procedural-only rule.
- #906 (open, §14.16): cycle-delayed virtual-interface clockvar drive fails code generation; exact overlap for I4b if it exhibits that diagnostic.
- #917 (open, §§16.16/14.3): property/sequence declarations inside clocking blocks fail parsing; those declarations are omitted from I3a/I3b.
- #919 (open, §§16.18/16.5.1): clocking input sample lags in concurrent assertions; separate assertion sampling rule.
- #921 (open, §25.9): interface with outside hierarchical reference accepted as a virtual-interface type; separate type restriction.
- #475 (closed, §16): assertion-local mixed-type declarations; unrelated despite its historical audit label.

No new issue is justified before running the ten probes. The snapshot is retained to support diagnostic-specific follow-up searches if a new failure appears.

After the run, searched the same snapshot for the exact new I1 compiler diagnostic (`Class I does not have a property P`) and I2 diagnostic (`Class I does not have a property Q`): no matches. A broader `clocking cbx` / `clocking block` + `modport` search surfaced #17 (closed Phase 13, whose out-of-scope list explicitly names “Modport with clocking blocks”) and #813 (open, same-interface name resolution for modport signal names). These are candidates for lead review before any filing; I1’s exact P diagnostic has no match.

The lead classified the N2 follow-up as the same name-resolution family as #813, not a new issue. The declaration-only form compiles when the modport is unused; the elaborated N2b use is correctly rejected, while the N2c same-interface control compiles and prints `tick 5`. Posted the lead-requested scope comment on #813: https://github.com/dsellerbrock/iverilog-uvm/issues/813#issuecomment-6320861717.

The lead filed #932 for the standard positive modport-expression example I1, after the open+closed snapshot and exact-diagnostic search found no duplicate.

The lead requested a traceability comment for the already-tracked I4b failure; posted on #906: https://github.com/dsellerbrock/iverilog-uvm/issues/906#issuecomment-6321007598.
