# String-element DPI open-array probe

Minimal legal use of a one-dimensional `string` array as a DPI open-array
actual. C only queries the formal's dimension and size; it does not depend on
string element representation. Both editions are compiled, linked, and run.

- Standard basis: [`STANDARD.md`](STANDARD.md)
- Probe sources: [`p35_string_openarray.sv`](p35_string_openarray.sv) and
  [`p35_string_openarray.c`](p35_string_openarray.c)
- Harness: [`run.sbatch`](run.sbatch)
