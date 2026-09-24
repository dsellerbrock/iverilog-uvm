# CSRNG Icarus package-order probe

Pinned source: Caliptra v2.1.2, `49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e`.

## Normative ordering

IEEE 1800-2017 §26.3, “Referencing data in packages,” PDF p. 776, says: “The compilation of a package shall precede the compilation of scopes in which the package is imported.” IEEE 1800-2023 §26.3, same heading, PDF p. 808, has the same sentence.

Local references:

- `reference-standards/local/IEEE_Std_1800-2017.pdf`, SHA-256 `12e3dc7bafafca28af2b89ebc2761fb7a606d68716cf04c2d93c8617c78eebec`
- `reference-standards/local/IEEE_Std_1800-2023.pdf`, SHA-256 `2280eb7f39532ca990b9bbd2e4226ae5c89910b51f42b2eb0e972df4403c9597`

## Pinned filelist and source order

`src/csrng/config/csrng_tb.vf` lists `caliptra_prim_generic_ram_1p.sv` on line 28, before `caliptra_prim_ram_1p_pkg.sv` on line 44. The former imports the latter at `src/caliptra_prim_generic/rtl/caliptra_prim_generic_ram_1p.sv:9` in the module header and uses `ram_1p_cfg_t` at line 25. Under the cited rule, package compilation must precede compilation of this importing scope.

The original unit census command was:

```sh
/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-campaign-20260908/local-install/bin/iverilog \
  -g2012 -gassertions -s csrng_tb \
  -o <evidence>/design.vvp \
  -f /Users/danielellerbrock/projects/iverilog_uvm/caliptra-rtl/src/csrng/config/csrng_tb.vf
```

It exited 3 with `Unknown package 'caliptra_prim_ram_1p_pkg' in import` at `caliptra_prim_generic_ram_1p.sv:9`. The complete census log is `../caliptra-full-dv-unit-census-20260923/caliptra-v2-1-2-csrng_tb/stderr.txt`.

A minimal compile-only probe, with the memory body black-boxed to isolate package binding, confirms the ordering effect: Icarus 13.0 exits 0 when the package file is supplied first and exits 3 with the same unknown-package error when the importing module file is supplied first. Exact command outputs are in `csrng_order_probe/package_first.log` and `csrng_order_probe/package_last.log`. Slang 11.0.448 lint of the same two files succeeds with package last (`csrng_pair_package_last.lint.log`); this is differential behavior and does not override the IEEE rule.

## Disposition

This is a release filelist ordering issue for consumers that compile entries in listed order. It does not establish a need for an Icarus forward package scan. A minimal Icarus exploration may use a disposable filelist overlay that moves only `caliptra_prim_ram_1p_pkg.sv` before `caliptra_prim_generic_ram_1p.sv`; no such overlay has been applied to the census or pinned release. VCS behavior is unverified because VCS is unavailable locally.

## Pinned full-filelist follow-up

A disposable copy of the pinned CSRNG `.vf` moving only `caliptra_prim_ram_1p_pkg.sv` before `caliptra_prim_generic_ram_1p.sv` has SHA-256 `9d98286d50cd2e345914d27ac8ee4a9ea55acf530c8e8517e0bcbdd0e073a8bb`; its diff is `csrng_order_probe/csrng_tb_package_first.diff`. The original pinned filelist SHA-256 is `78614e6aa69492f44feadd10d8f2243e88e1143bf0cb08ac9dbbc965b9236bc6`. A narrowed full `csrng_tb` compile using the reordered filelist no longer reports the unknown package, but exits 1 because `aes_clp_wrapper.sv:26` cannot include `caliptra_reg_field_defines.svh`. See `csrng_order_probe/csrng_tb_package_first.compile.log`. This later missing include is a separate setup/filelist blocker; the `.vf` overlay is exploratory only and was not applied to pinned sources.
