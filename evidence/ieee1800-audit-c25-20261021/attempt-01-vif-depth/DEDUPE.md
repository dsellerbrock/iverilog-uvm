# Open and closed issue dedupe: Clause 25.9 virtual interfaces

The snapshot [`dedupe-all-issues.json`](dedupe-all-issues.json) contains all 424 repository issues fetched after job 3762: 297 open and 127 closed. Searched titles and bodies in both states for `virtual interface parameter`, `virtual interface modport`, `virtual interface port`, `virtual interface union`, `defparam virtual interface`, `vif task`, `wait vif`, `virtual interface hierarchical`, `outside hierarchical`, and `interface containing hierarchical references`.

No issue covers the V9 rule requiring rejection of an interface containing an outside hierarchical reference when used as a virtual-interface type. Broader near matches are distinct:

- #5 (closed) is an older virtual-interface-as-class-member milestone. It records event-control and class-member paths and a remaining question about passing a VIF through a module port; it does not cover the §25.9 declaration restriction for interfaces with outside hierarchy.
- #815 (open) is the null-VIF fatal runtime behavior; #816 (open) is use of a VIF component in a continuous assignment; #906 (open) is cycle-delayed clockvar drive through a VIF. None concerns V9's type-declaration restriction.
- #812 (open) concerns a module `ref` port, not a virtual-interface port. #758 (open) concerns hierarchical references inside `type()`. #764 (open) concerns `chandle` union use, and #790 (open) a struct member named like a package; neither covers virtual-interface union members.
- The exact `virtual interface port` phrase found only #5, whose scope is distinct as above. The other scoped phrases had no matches.

All 424 open and closed issue records are preserved in the JSON snapshot (297 open, 127 closed at query time, before filing). The lead reviewed both editions, confirmed the §25.9 gap, and filed [#921](https://github.com/dsellerbrock/iverilog-uvm/issues/921). The two pre-existing §25.9 gaps, #815 and #816, remain separate.
