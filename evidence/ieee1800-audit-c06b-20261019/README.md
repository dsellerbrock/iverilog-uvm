# IEEE 1800 §6.19 enum probes — 2026-10-19

The audit lead selected §6.19 for enum declaration, value, method, and conversion probes. The sources are under `tests/1800_audit/c06/`; this is a scoped probe set, not a full-clause conformance claim.

## Run

- Primary command: `~/codex-supervisor/localrun 900 bash evidence/ieee1800-audit-c06b-20261019/run-probes-local.sh`.
- Focused bisect command: the sequential localrun call recorded in `diagnostics/rerun-localrun.out`.
- Host: MacBook-Air.local, Darwin 27.0.0, arm64.
- Slurm had all 20 CPUs allocated, so no job was submitted. These sequential probes used one CPU and the active local fallback.
- Compiler: Icarus 13.0 devel from source commit `b9441bafbdb0b6b7413c09e0381845e69481391b`; iverilog SHA-256 `7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`, vvp SHA-256 `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`.
- Editions: `-g2017` and `-g2023`. Each compile and simulation had a 60-second process-group timeout through `scripts/run_with_timeout.py`.
- Primary run: 13.98 seconds, peak RSS 46,481,408 bytes. Focused split run: 7.82 seconds, peak RSS 16,990,208 bytes.
- Full terminal output and per-case logs: [localrun.out](localrun.out), [diagnostics/](diagnostics/).

## Results

Both editions produced identical results.

- Enum declarations/ranges: 13 pass, 1 fail in `p06_19a_enum_decl.sv`. `XX='x` in an `enum integer` evaluates to `0000000000000000000000000000000x`, so the all-X comparison fails. The separate uninitialized enum variable `st4` reads all X. Raw values are in `diagnostics/rerun-localrun.out`.
- Enum numeric comparisons, arithmetic, explicit casts, and `$cast`: 8 pass, 0 fail in `p06_19c_enum_numeric.sv`.
- All 13 negative declarations/assignments were rejected in both editions; compiler diagnostics are in `n06_19_*.compile.log`.
- Removing the fixed-array-element line from `p06_19b_enum_methods.sv` lets all remaining enum-method checks pass: 13 pass, 0 fail in both editions. The two nonmember `next`/`prev` INFO results are 0, and an out-of-range enum's `name()` is empty.
- The initial method file used `c.name.len()`; replacing it with explicit `c.name().len()` passes with length 5. Explicit chaining `c.next().name()` also returns `blue`.
- Explicit enum methods on a class property pass: `k.col.name()`, `next()`, `first()` return `green`, 2, and 0. Explicit methods on a queue element pass: `q[0].name()` and `next()` return `yellow` and 0.
- Explicit enum methods on a fixed unpacked-array element compile, then VVP exits with `The second argument to enum method ... must be an enumeration variable, found a vpiMemoryWord.` Both `name()` and `next()` trigger it. The minimal source is `r06_19h_array_element_method.sv`; `p06_19b_enum_methods.sv` reproduces it in context.
- Bare no-parentheses enum calls on a class property compile with “not yet supported (expression dropped)” warnings and return 32; explicit `()` calls work. The minimal probe is `r06_19j_class_property_bare_method.sv`.
- Bare no-parentheses calls on a plain enum variable and a struct-member enum pass. Explicit calls on a struct member pass too. Plain string variables support `len()` and `toupper()`.
- Slang 11.0.448 rejects bare chained forms with “parentheses are required when chaining method calls.” Icarus rejects `c.name.len()` and `c.name.toupper()` too, but incorrectly accepts bare `c.name.len` and `c.next.name` with fallback warnings and wrong values. Explicit `c.name().len()` and `c.next().name()` pass. The lead kept #740 open for that fabricated fallback, while noting it found no specific IEEE rule for bare chaining; its issue comment records that limit.
- A fixed-width enum base does not context-fill unbased unsized literals: `ONES='1` gives `0001`, `Z0='z` gives `000z`, and `X1='x` gives `000x`. The lead classified the latter two as the same defect as #737 and the results were added in [a comment on #737](https://github.com/dsellerbrock/iverilog-uvm/issues/737#issuecomment-6283164079).

## Dedupe and disposition

Open-and-closed searches for `enum`, `enum first`, `enum next`, `enum name`, `enum range`, `enum cast`, `enum method`, and `enumeration` are saved as `dedupe_*.txt`; the second dedupe round is under `dedupe2/`, and searches for method nesting and unbased enum values are under `dedupe3/`.

The bodies of #11, #43, #44, #47, and #539 were reviewed. #11 is the generic enum-method runtime phase, #43 includes `enum.method()` on a function return, and #47 covers out-of-range `name()`; none describes the fixed-array-element VVP error, dropped bare class-property enum calls, or unbased-literal sizing. The lead classified four distinct new gaps; issues #737–#740 were filed from its approved payloads. The additional `'1`/`'z` probes were added to [#737](https://github.com/dsellerbrock/iverilog-uvm/issues/737#issuecomment-6283164079), so no duplicate issue was opened. Slang's differential evidence and the unresolved IEEE syntax basis for #740 are recorded [in its comment](https://github.com/dsellerbrock/iverilog-uvm/issues/740#issuecomment-6283224999); the 2023 counterpart to the cited 2017 footnote was not checked.
