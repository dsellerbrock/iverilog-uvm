# IEEE 1800 §21.2.1 display-format probe

Host: MacBook Air, run through `~/codex-supervisor/localrun` (90 seconds for
each positive compile+run; 60 seconds for each negative compile). The pinned
source is batch commit `b9441bafbdb0b6b7413c09e0381845e69481391b`.

Icarus 13.0 devel binaries built from that exact source:

- `iverilog`: SHA-256 `7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`
- `vvp`: SHA-256 `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`

Probe source: [`p21_02a_display.sv`](../../tests/1800_audit/c21/p21_02a_display.sv).
Negative sources: `n21_02_undefined_spec.sv` and `n21_02_missing_arg.sv` in
`tests/1800_audit/c21/neg/`.

Both `-g2017` and `-g2023` compile and run the positive probe, but print
`FAIL t3`, `FAIL w797`, and `RESULT pass=13 fail=2`. The debug result is the
same in both editions:

```text
t3=[00000005|00000100|00001234]
w797=[00000003]
w797_8bit=[03]
```

The two negative files (`%q` undefined specifier and missing `%d` argument)
both compile successfully with exit code 0 in both editions, with no compiler
diagnostic. Runtime checks in both editions return exit code 0, but emit a
warning and then print the unrecognized/missing format text: `%q` produces
`WARNING: ... unknown format $display<%q>.` followed by `<%q>          1`; a
missing `%d` produces `WARNING: ... missing argument for $display<%d>.`
followed by `<%d>`. The initial `n21_02_*.localrun.log` wrapper exit 1 records
the expected-rejection self-check failing, not a compile error.

The twelve raw logs retain output, wall time, and peak RSS. Positive commands use
the installed compiler at `/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog`
and runtime at `/tmp/a3-t2-batch-2026-10-19-6-local-r6/source/vvp/vvp`.

Dedupe searches across open and closed issues on 2026-10-20 used the terms
`argument shall be supplied`, `undefined format specifier`, and `%02X`. The
first two returned only #798; `%02X` returned #797. #796 is a separate issue
about formatted arguments to elaboration system tasks; #794 is about array
queries.
