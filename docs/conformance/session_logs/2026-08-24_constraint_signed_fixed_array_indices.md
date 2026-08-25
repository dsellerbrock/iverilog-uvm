# Signed fixed-array indices in constraints (2026-08-24)

## Scope

The post-PR-228 full regression exposed one deterministic failure in both
Icarus runners: `sv_constraint_fixed_array_reduction`. Ubuntu CI treated it as
a hard failure. The macOS and Windows jobs showed the same raw failure in the
broad regression step, although those workflows allowed that step to continue;
their build, self-check, install, DPI, and UVM stages were otherwise clean.

This was not caused by the subsequent dynamic-array slice work. Replaying the
three-test reduction focus against its untouched base reproduced the same
warning and missing constraint leaves.

## Root cause and fix

PR 228 made unary negative constraint constants retain their SystemVerilog
width and signedness. For example, a 32-bit `-2` is represented as
`c:4294967294:32:s`. Most consumers use the common typed-constant decoder, but
the fixed-array indexed-class-property path still recognized only the `c:`
prefix and fed its decimal payload directly to `strtoull`. It therefore
treated `values[-2]` and `values[-1]` as enormous positive coordinates, dropped
those solver leaves as out of range, and warned that the constraint was not
representable.

That consumer now parses the full constant IR, rejects widths above its
64-bit coordinate boundary, and sign-extends signed values to the existing
two's-complement coordinate representation before subtracting the declared
lower bound. The canonical fixed-array slot calculation is otherwise
unchanged.

The permanent test now checks the solved values at declared indices `-2`,
`-1`, and `0` individually before checking the `index()`-weighted reduction.
This makes a future dropped-leaf regression observable even if the solver can
accidentally find a model satisfying the aggregate result.

## Native ARM64 validation

The compiler was rebuilt and installed natively on Apple Silicon with the
repository's 45-second per-process CPU guard and no RSS ceiling. No VM was
used. Results from the exact post-PR-230 base plus this two-file code/test fix:

- focused legacy reduction cluster: 3/3;
- focused JSON/VVP reduction cluster: 3/3;
- full legacy SystemVerilog runner: 1,863/1,863;
- full JSON/VVP runner: 932/932;
- `make check`: pass;
- bundled VPI runner: 99/99;
- exact negative-diagnostic runner: 123/123.
- real-DPI UVM runner: 338/338, with zero failures or skips.

Both compiler and runtime stderr files for the repaired test are empty.
Slang accepts the shared positive source without diagnostics under both
`--std 1800-2017` and `--std 1800-2023`.

The UVM runner resolves `iverilog-vpi` relative to the directory containing
the selected `iverilog`. A guarded-bin setup must therefore provide companion
wrappers for `iverilog`, `iverilog-vpi`, and `vvp`; providing only the compiler
and runtime makes the real-DPI build fall back even when the installed
`iverilog-vpi` exists one directory away.
