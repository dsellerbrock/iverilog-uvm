# Disjoint virtual-interface property writer, private focus (2026-09-24)

This evidence covers only the `elaborate.cc` mixed-driver correction. It does
not establish a Caliptra L0 result. The shared compiler installation and the
running L0 replay were not changed for these checks.

The pre-fix installed compiler rejected both legal `vif.reset`/`bus.count`
tops in both 2017 and 2023, strict and `-gcommercial-unsafe`, with the same
mixed-driver diagnostic as `tests/vif_smoke*.sv:96`. A private `ivl` linked
from the current campaign objects with a newly compiled `elaborate.o` was
placed at `/tmp/vif-disjoint-private-20260924/ivl`. Its support directory was
copied from `local-install/lib/ivl` and selected with `iverilog -B`;
`sha256.json` records that initial private focus. The final six-top fixture
SHA256 is `c6cf56c414c5a66d7c1d2118986a81aed970847fc542f603f1278db7907036b7`.

The dedicated `ivtest/ivltests/sv_vif_disjoint_property_writer.v` fixture
selects six tops. Module-port and direct continuous drivers each run to
`PASSED` when a VIF writes a distinct ordinary member. Same-member overlap
through either driver path, runtime-selected receiver, and `.reset(count)`
modport alias overlap retain exact compile errors. Its 24 paired 2017/2023
strict/unsafe configs and five gold outputs are in `ivtest/vvp_tests` and
`ivtest/gold`. The initial private `vvp_reg.py` focus was **20/20**
(`new_focus.log`); 16 neighboring
port/ref/dynamic/modport rejection controls were **16/16**
(`neighbor_focus.log`). The focus lists and private logs are under
`/tmp/vif-disjoint-private-20260924/`.

The later direct same-member negative completed **4/4** exact compile-error
checks with the installed compiler in both editions and both strict/unsafe
modes. The diagnostic is:

```text
ivltests/sv_vif_disjoint_property_writer.v:79: error: Variable 'count' cannot have continuous and procedural drivers on the same bits.
1 error(s) during elaboration.
```

The installed `ivl` SHA256 was
`ba1dda3daf01870311a137a0b27b46be8a05575e871dba30321ce13480720ba3`.
Its temporary focus list and `vvp_reg.py` logs are under
`/tmp/vif-direct-same-installed-20260924/`.

Both real-DPI `tests/vif_smoke.sv` and `tests/vif_smoke_v2.sv` compiled
privately with `-uvm -g2017`, and both completed runtime with
`PASS counter_test`, `UVM_ERROR : 0`, and `UVM_FATAL : 0`. Their VVP programs
embed the copied real `uvm_dpi.vpi` path. Exact commands and output are in
`vif_smoke.log` and `vif_smoke_v2.log`.

The source fix excludes an unresolved VIF property writer only after the
interface layouts match, both property names map to ordinary authoritative
`PWire` declarations, the names differ, and neither view has a modport.
Same-member overlap, hidden or uncertain properties, modport aliases, and the
separate unresolved interface-ref guard still block the continuous driver.
