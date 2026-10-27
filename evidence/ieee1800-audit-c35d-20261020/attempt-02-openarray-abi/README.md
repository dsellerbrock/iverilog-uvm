# Clause 35 open-array ABI probe

Run the existing M10 open-array tests under both IEEE editions:

- `m10_dpi_openarray_test`: 1-D dynamic-array atom/real access and writes;
- `m10_dpi_open_array_bounds_test`: dimensions, bounds, increment, byte size,
  traversal, and 2-D dynamic arrays;
- `m10_dpi_open_array_layout_range_test`: ascending and descending fixed-array
  declared ranges, indexed element access, and out-of-range pointers.

The paired-edition Slurm harness and preserved raw results are linked below.
No test source or expected file is changed.

- Standard clauses: [`STANDARD.md`](STANDARD.md)
- Open/closed issue search: [`DEDUPE.md`](DEDUPE.md)
- Harness: [`run.sbatch`](run.sbatch)
