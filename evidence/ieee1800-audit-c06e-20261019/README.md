# IEEE 1800 clause 6.21 probes

Run on 2026-10-19 under `~/codex-supervisor/localrun 300` with
`run-p06-21.sh`. Host: Darwin ARM64. Audit checkout HEAD:
`27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`. Compiler source:
`b9441bafbdb0b6b7413c09e0381845e69481391b`; Icarus SHA-256
`7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`;
VVP SHA-256 `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`.
The serial run took 2.55 s and peaked at 16,891,904 bytes RSS. Per-case
compile and runtime logs are saved in `attempt-01/`; the full localrun output
is `attempt-01-localrun.log`.

## Results

`p06_21a_lifetime.sv` compiles and runs in both `-g2017` and `-g2023` with
`RESULT pass=7 fail=0`. The module automatic function prints `M2 f1=1 f2=1`;
the automatic program task prints `PROG loc=1 i=1` then `PROG loc=1 i=2`.
Checks cover compilation-unit lifetime, automatic task locals, static locals
inside automatic tasks and their hierarchical visibility, static task locals,
static versus automatic loop-block variables, and automatic class methods.

The four other expected compile-time rejections occur in both editions:

- NBA to an automatic task variable (`n06_21_nba_automatic`).
- Procedural continuous assignment to an automatic task variable
  (`n06_21_proc_assign_automatic`).
- Continuous assignment to a non-static class property
  (`n06_21_class_prop_cont_assign`).
- Hierarchical access to a variable in an unnamed block
  (`n06_21_hier_unnamed_block`).

Two expected rejections are accepted by Icarus in both editions:

- `n06_21_static_init_no_keyword.sv` compiles with warning
  `Static variable initialization requires explicit lifetime in this context.`
  The standard says an explicit `static` keyword is required for an
  initialization value on a static variable declaration (2017 §6.21 p.127;
  2023 §6.21 p.133). The probe reduces the `top_illegal` example's `int svar2
  = 2` declaration.
- `n06_21_nba_dyn_elem.sv` compiles without a diagnostic despite an NBA to
  `d[0]` for a dynamic array. IEEE 1800-2017 §6.21 p.128 and 2023 §6.21 p.134
  prohibit NBA, continuous, and procedural continuous writes to elements of
  dynamically sized arrays.

<a id="issue-dedupe"></a>
## Issue dedupe

All states were searched with `gh issue list --state all --limit 40` for
`lifetime`, `automatic`, `static`, `static initializer`, `program automatic`,
`module automatic`, `hierarchical static`, `unnamed block`,
`nonblocking automatic`, `class property continuous`, and
`dynamic array element`. The 52 unique hits, sorted by issue number, are in
[`dedupe-unique.tsv`](attempt-01/dedupe-unique.tsv); per-term results are in
[`dedupe-per-term.tsv`](attempt-01/dedupe-per-term.tsv).

Bodies reviewed for likely overlaps #102, #596, #637, #671, #449, #632, and
#97. They cover fork-captured automatic values, event-wait crashes, tracing
automatic variables, dynamic-array slice assignment to class properties,
static-lifetime `ref` arguments, and object-array property stores. These are
different from static initialization intent and NBA-to-dynamic-array-element
legality. No exact issue match was found in the search results. Lead
classification and filing decision are pending.

## Lead classification and issues filed

The 1800-audit lead classified the two accepted negatives as separate,
low-priority diagnostic gaps because the prohibitions are independent rules:

- [#752](https://github.com/dsellerbrock/iverilog-uvm/issues/752): the
  initialized static declaration without an explicit lifetime qualifier is
  accepted with only a warning, despite §6.21 requiring the keyword and
  marking the standard example as non-compiling.
- [#753](https://github.com/dsellerbrock/iverilog-uvm/issues/753): the NBA to
  a dynamic-array element is accepted silently, despite the separate §6.21
  prohibition. Its runtime effect was not probed.

Both issues were deduplicated against the 52 all-state search results and the
reviewed likely matches listed above. The lead requested user approval before
changing either behavior because existing code may rely on current acceptance.
The matrix row is PARTIAL for the tested subset and links both issues.
