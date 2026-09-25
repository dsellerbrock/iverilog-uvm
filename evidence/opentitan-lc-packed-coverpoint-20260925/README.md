# OpenTitan LC_CTRL packed coverpoint shape

This ticket fixes declaration-time width and signedness inference for a legal
bitwise coverpoint over packed class properties. IEEE 1800-2017 and 2023
§§11.6, 11.7, 11.8, and 19.5 make an implicitly typed coverpoint use its
expression's self-determined integral type. The exact pinned LC_CTRL source
has `coverpoint (cfg.err_inj & ~ErrInjMask)` with `{0}` and `[1:$]` bins.

Before the fix, the private compiler returned zero for the bitwise expression
width, emitted two `runtime range expression ... bin is dropped` diagnostics,
and the paired legal 2017/2023 reducer reported **1.5625%** after the zero
sample rather than **50%**. `PEIdent::test_width()` did not recover the nested
class property in the covergroup declaration scope, although its packed
declaration type was available. `coverpoint_effective_shape` now uses that
declared type recursively for integral bitwise operands, applying the ordinary
unary and binary width/sign rules. Invalid `[$:$]` still rejects, and 65-bit
packed bins remain loudly unsupported under the existing 64-bit range limit.

Paired 2017/2023 focused tests pass **10/10 legacy and 10/10 JSON/VVP**. They
check zero/nonzero sample hits and denominator, masked-only input, mixed
3/5-bit operands, signed and mixed signed/unsigned bounds, syntax rejection,
unsupported wide bins, and a real-operand expression that must emit a dropped-bin
diagnostic. These are language/reducer results, not released
DV passes. A separate [unregistered X/Z reducer](xz_sample_red.sv)
fails in both editions: the source and expression print `xxxxx`, then their
first samples hit the ordinary zero bin and report 50% coverage. The
[2017](xz_sample_2017.log) and [2023](xz_sample_2023.log) logs capture this
independent VVP issue (DD-063); it remains unfixed.

The fresh pinned `lowrisc:dv:lc_ctrl_sim:0.1` compile uses the private Icarus
and explicit `-gcommercial-unsafe`; it runs from an ARM64 FuseSoC build root
with the pinned OpenTitan checkout unchanged. Compared with the merged PR375
matrix row, the two dropped-bin diagnostics disappear: hard errors **6 → 4**,
semantic-debt diagnostics **20 → 18**. Four hard error sites
remain (`run_clk_byp_rsp`, `run_flash_rma_rsp`, `tokens_a`, and
`process.self`), so LC_CTRL is still **0/1 released DV**. See
[current result](lc-unsafe-final-result.json), [current compile log](matrix-compile.log),
and the [prior full baseline](../opentitan-cover-open-range-20260925/README.md).
This one-row replay is not a new 49-row census. The prior checked nonstandard
compatibility baseline remains **11/49**, with **38** selected runtime rows
without a qualifying pass; the 38 rows are not 38 unique compiler bugs.

Provenance: branch `agent/ot-lc-packed-coverpoint-20260925` started at merged
PR375 `1891f0128627ff0b3124216f0040780087336f82`. Pinned OpenTitan is
`a78922f14a8cc20c7ee569f322a04626f2ac6127`. Private installed `ivl`
SHA-256 is `ab49a9f08784275c53a57ff177e6d7e68afb23718ff04198e473cbf2509fbcad`;
private `vvp` SHA-256 is
`8c7b481dc09ff49477542a3ce4e8c8e58ca8dca1f620948d26e82316a17ec781`.
The exact compile and setup commands and tool fingerprints are in
[current result](lc-unsafe-final-result.json); copied setup/compiler logs
and the [wrapper](matrix-iverilog.scr) plus [generated source list](lc-ctrl-generated.scr)
are retained here. No pinned source,
Caliptra work, or shared installed compiler was changed.

The first integrated and real-DPI UVM runs were deliberately stopped before
completion when the source added an unsupported-operand width-clear guard;
their `.partial.log` files are unqualified. On the final private compiler,
`make check`, [negative tests](negative-final.log) 155/155, and
[SVA dual-run](sva-final.log) 62/62 pass. The
[full integrated regression](integrated-final.log) passes legacy 6,704 total
(6,699 ordinary passes, zero failures, two not implemented, three expected
failures), VPI with PLI1 140/140, and JSON/VVP 3,753/3,753. The
[real-DPI UVM regression](uvm-final.log) passes 358/358 with zero failed or
skipped and the real DPI umbrella loaded. These infrastructure regressions
do not qualify LC_CTRL released DV.
