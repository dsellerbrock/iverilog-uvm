# Unpacked-structure DPI open-array probe

This complements the `string[]` probe with a fixed unpacked array of a
user-defined unpacked structure. C queries only the open-array dimension and
size; it does not inspect the structure layout.

- Standard basis: [`STANDARD.md`](STANDARD.md)
- Sources: [`p35_struct_openarray.sv`](p35_struct_openarray.sv) and
  [`p35_struct_openarray.c`](p35_struct_openarray.c)
- Harness: [`run.sbatch`](run.sbatch)
