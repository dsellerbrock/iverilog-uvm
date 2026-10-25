# IEEE 1800 §§21.2.1.5–21.3.3 probe

Host: MacBook Air, using `~/codex-supervisor/localrun` with a 120-second cap
per edition. The pinned source is batch commit
`b9441bafbdb0b6b7413c09e0381845e69481391b`.

The probe source is [`p21_02b_misc.sv`](../../tests/1800_audit/c21/p21_02b_misc.sv).
It covers `%v`, `%s`, `%p`, `%m`, `$strobe`, `$monitor`, `$swrite*`, `$sformat`,
`$fopen`, `$fgets`, `$fwrite`, `$fdisplay`, and file-descriptor/MCD routing.
Raw outputs, created text files, compile logs, wall time, and peak RSS are in
`attempt-01/` and `attempt-02/` for both editions.

Both editions compile and run with exit 0. The reduced current test reports
`RESULT pass=9 fail=2` in each edition:

- `%s` of `32'h00006162` produces `  ab`; `%s` of the fixed byte array
  produces the literal `%s`. Both checks fail.
- `%p` on the associative array of structs prints `'{10:?, 20:?}` instead
  of exposing the struct values. This was observed, not asserted by the probe.
- `%v`, `%p` of a string member, `%m`, `$strobe`, `$monitor`, string writes,
  `$sformat` warning behavior, and file I/O checks pass.
- The `$sformat` missing-argument warning is expected; §21.3.3 permits a
  warning for a string-format mismatch.

The first exploratory run used one combined `s1` check and reported one
failure; attempt 02 splits that check and isolates both failing `%s` cases.
The actual file outputs are `abc\nxyz\n` in `p21_tmp.txt` and `BOTH\n` in
`p21_tmp2.txt` for both editions. `BOTH`, `FD1`, and `MCD1` appear on the
screen as expected.

Five focused `%p` reducers were then run under both editions in
`attempt-03-p/`. They print:

```text
struct ['{sw:1, s:"hi"}]
enum [1]
assoc_int ['{3:7, 9:8}]
fixed ['{1, 2, 3}]
assoc_struct ['{10:?}]
```

The reducers show that an enum is printed numerically instead of by name and
that an associative array containing a struct prints `?` for its value;
integral associative arrays, fixed arrays, and direct struct fields print
their values. Inputs are `r21_p_{struct,enum,assoc_int,fixed,assoc_struct}.sv`.

Dedupe searches across open and closed issues on 2026-10-20 used `%p struct`,
`%p assignment pattern`, `%s byte array`, and `%s leading zeros`. Results
matched #799, #800, and #801; no prior issue covered these behaviors. Other
search hits (#790/#788 struct queries and #27 OpenTitan runtime stubs) are
unrelated.
