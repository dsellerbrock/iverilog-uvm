# §21.7.5 type mapping results

Host: macOS localrun. Toolchain: compiler `7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`; VVP `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`.

| Probe | Edition | Exit | Wall | Peak RSS | Result |
|---|---:|---:|---:|---:|---|
| initial typemap | 2017 | 0 | 0.11 s | 6,979,584 B | `$dumpvars` warns `Unsupported argument type (vpiClassVar)`; only referenced variables appear |
| initial typemap | 2023 | 0 | 0.07 s | 6,963,200 B | Same |
| referenced typemap | 2017 | 0 | 0.05 s | 7,061,504 B | `vl`, `vm`, `vp`, `vb`, `ve`, `vf`, `vi`, `vq`, `vr`, `vs`, `vy` appear with expected reg/integer/real types and widths; `vu` is absent |
| referenced typemap | 2023 | 0 | 0.05 s | 7,061,504 B | Same |
| isolated unpacked struct | 2017 | 0 | 0.09 s | 6,897,664 B | `$display` reads 3 and 2, but VCD has no fork scope or members; same warning |
| isolated unpacked struct | 2023 | 0 | 0.06 s | 6,930,432 B | Same |

The isolated result is the minimal evidence for the §21.7.5 unpacked-structure mapping gap, filed as [#807](https://github.com/dsellerbrock/iverilog-uvm/issues/807): the standard table expects a named fork scope containing integer `x` and 2-bit `y`. The packed-dimension range mismatch for `vm` was filed as [#808](https://github.com/dsellerbrock/iverilog-uvm/issues/808). Full raw logs and VCDs are in the corresponding `typemap-*` directories.
