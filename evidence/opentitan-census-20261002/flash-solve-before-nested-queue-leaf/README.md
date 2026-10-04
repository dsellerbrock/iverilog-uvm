# Flash solve-before queue-leaf replay

This evidence records a disposable-source compile replay of the two census11 Flash clauses that order nested fixed-array queues. The pinned OpenTitan checkout and the census11 build/source tree were not modified.

## Strict controls

- `sv_constraint_solve_before_fixed_array` and its 2023 wrapper preserve whole one-dimensional fixed-array ordering: **2/2 legacy and 2/2 JSON runs pass**.
- `sv_constraint_fixed_queue_leaf_order` orders four selected queue leaves before a scalar in `rand entry_t q[2][2][$]`: both editions pass in both harnesses (**2/2 legacy and 2/2 JSON runs**). The 400-sample bound checks that queue constraints do not collapse the earlier variable's distribution.
- All these controls use strict `-g2017`/`-g2023`; none use `-gcommercial-unsafe`.

## Disposable census11 replay

The two census11 source files were hash-checked before editing. The fixed `rand_regions`/`mp_regions` array operands remain whole-array operands, covered by the existing whole-1D control. Each nested queue aggregate was expanded to its 26 statically selected packed leaves: two banks times queue lengths 10, 1, and 2 for the three info types. The solve direction and every selected item are retained.

The compile succeeded with explicit `-gcommercial-unsafe` and zero hard errors. It removes both targeted aggregate-omission warnings at `flash_ctrl_otf_base_vseq.sv:49` and `flash_ctrl_mp_regions_vseq.sv:43`. Sixteen warning occurrences remain for packed `flash_op_t` member ordering in the OTF and legacy base sequences; census11 counts these as eight unique semantic-debt entries. The existing strict paired fixture documents that packed-struct member ordering is an unsafe compatibility extension and is not currently represented as an ordered variable. This replay does not resolve those entries or qualify the Flash DV row, so no runtime was run on this image.

The exact two-file source patch, before/after source hashes, compiler log, and filtered warning delta are retained here. The complete census11 matrix remains **38 PASS, 7 DEBT, 1 compile FAIL, 2 RUNTIME_FAIL, 1 RUNTIME_TIMEOUT**; **49/49 is not met**.

## Compiler image

- Installed `iverilog` driver SHA-256: `02f5a2f162250fd33b2a7a3c22109fd66f047dd890caa58b5fe09a510a1785f1`
- Installed `ivl` engine SHA-256: `6b7e1807e3a9894710f71bf14f150f0fd271742a43f23e37289087ee25c1901d`
- VVP SHA-256: `9232df0eedec084a93d91580fca668cbfb90cafcb628569f55e4e481f4d7076b`

The OpenTitan source was replayed from census11's generated build copy, whose revision metadata is `a78922f14a8cc20c7ee569f322a04626f2ac6127`. Its exact source-copy hashes and the overlay hashes are listed in `flash-census11-overlay-hashes.txt`.
