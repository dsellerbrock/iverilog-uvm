# Attempt 1619: build and edge test passed; harness stopped before profiling

Pinned measurement base: `374b037e7c8fba7097e0b86b05be7956ca6b5487`.

Both reference and candidate builds completed, and the registered
`sv_vpi_wide_index` edge fixture printed identical `PASSED` output on both.
The job then exited before Callgrind because the harness required the compiler
generated `.vvp` files to be byte-identical. They embed different install
paths, source dirty markers, and generated object IDs, so this comparison was
invalid for separate installations. The simulation output comparison was not
reached; this attempt contains no performance result.

The retry keeps exact output comparisons for the focused and corpus runs and
drops only the compiled `.vvp` file comparison. This failed setup attempt is
preserved with the submitted script and build logs; it is not counted as a
candidate screen.
