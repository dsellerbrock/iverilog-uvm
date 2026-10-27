# §6.7.1 and §27 probes

Host: macOS, each run wrapped with `~/codex-supervisor/localrun`; every compiler
and simulator invocation had a 20-second timeout. The longest runner took
1.07 seconds and peaked at 17,858,560 bytes RSS.

Toolchain: Icarus build from batch commit
`b9441bafbdb0b6b7413c09e0381845e69481391b`:

- `iverilog` SHA-256 `7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`
- `vvp` SHA-256 `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`

All probes ran under both `-g2017` and `-g2023`.

## Positive generate probes

All seven lead-provided probes compiled and ran with the expected output after
the `g_cond` mixed-net declaration was split into separate declarations. The
explicit `generate` region probe also passed.

| Probe | Output |
| --- | --- |
| `g_loop` | `G1 0 0 0`; `G1 1 2 1`; `G1 2 4 2`; `G1B 4 1` |
| `g_ripple` | `G2 2 1` |
| `g_multi` | `G3 ok`; `G3H 1 1 1` |
| `g_cond` | `G4 1 1` |
| `g_unnamed` | `G5 1 1 1` |
| `g_recursion` | `G6 1111` |
| `g_case` | `G7 0` |
| `g_region` | `GR 1` |

The first `g_cond` attempt failed because it used a legal mixed net declaration
list (`wire a=1, b=0, c;`). Reduced controls confirmed the same syntax error with
and without a parameter port list, while a single initialized net passed. The
IEEE 1800-2017 Annex A.2.4 grammar (p.1148; the same grammar is present in 2023)
allows each net name to have an optional initializer. The lead deduped and
filed [#820](https://github.com/dsellerbrock/iverilog-uvm/issues/820) under
§6.7.1.

## Negative generate probes

Eleven of thirteen §27 negatives were rejected in both editions as required:
nested reuse of a genvar; generate-block name conflicts; nonterminating or
repeating loops; an X genvar; a self-referencing loop initializer; a
non-constant condition; a `specparam` in a generate block; a conditional/loop
name conflict; and a missing `endgenerate`. The nonterminating loop was rejected
immediately, not by timeout.

Two negatives were accepted in both editions:

- `n27_genvar_runtime.sv`: a declared genvar referenced from an `initial`
  block compiles with an unresolved-reference warning and runs with exit 0,
  contrary to §27.4 p.788. The lead deduped open and closed issues and filed
  [#821](https://github.com/dsellerbrock/iverilog-uvm/issues/821).
- `n27_port_in_gen.sv`: a port declaration inside a generate block compiles
  and runs with exit 0, contrary to §27.2 p.786. The lead deduped open and
  closed issues and filed
  [#822](https://github.com/dsellerbrock/iverilog-uvm/issues/822).

The lead classified the tested portions of §27.2–§27.6 and checked the 2017
clause references against the standards. Results, exact command arguments,
diagnostics, stdout and exit codes are recorded in [`results.json`](results.json),
[`accepted-runtime.json`](accepted-runtime.json), [`g_region-results.json`](g_region-results.json),
and the positive run files under [`../ieee1800-audit-c27a-20261020/`](../ieee1800-audit-c27a-20261020/).
