# IEEE 1800 §§6.17–6.18 probes

Run on 2026-10-19 on Darwin ARM64 under `~/codex-supervisor/localrun`.
Each compile and simulation had a 60-second timeout. Audit checkout
`27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`; compiler source
`b9441bafbdb0b6b7413c09e0381845e69481391b`; Icarus SHA-256
`7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`;
VVP SHA-256 `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`.
The probes produced the same outcomes with `-g2017` and `-g2023`.

All compiler/runtime logs, runners, and dedupe output are in `attempt-01/`
through `attempt-03/`. `localrun` reports 9.59 s / 46,661,632 bytes peak RSS
for the first pass (including nine all-state GitHub searches), 1.67 s /
16,908,288 bytes for focused §6.18 tests, and 2.80 s / 16,973,824 bytes for
the six §6.17 reductions.

## §6.17 event data type

`p06_17a_event.sv` uses the exact legal declarations from both standards:
`event done; event done_too = done; event empty = null;`. It fails compilation
in both editions with two `Syntax error in event variable list` diagnostics.

The lead's reduction confirms the underlying existing #699 gap too:
`r06_17_a` and `r06_17_b` fail on those declaration initializers; `r06_17_c`
(event alias assignment/comparison), `r06_17_d` (assignment to null), and
`r06_17_f` (event comparison) fail compilation with `a value of type 0 cannot
be used in a vector context`. `r06_17_e` exits compilation with a
`Could not find variable e2` warning and emits no runtime output. The runner
attempted to execute VVP files even after compiler errors; those incomplete
artifacts' output is not valid evidence. The lead directed a comment on #699,
not a new issue; the reduction details are now posted on [#699](https://github.com/dsellerbrock/iverilog-uvm/issues/699#issuecomment-6283920310).

The all-state search over `event`, `event null`, `event alias`, `event assign`,
and the other listed terms found open issue #699. Its body already covers
named-event aliasing, assignment, comparison, and null disassociation under
§15.5.5, so it appears to be the same implementation gap viewed from §6.17.
The lead is reviewing whether to add a §6.17 comment; no new event issue has
been filed.

## §6.18 user-defined types

- `p06_18b_forward_kinds.sv`: the forward `enum`, `struct`, `union`, `class`,
  unspecified-base typedef, and duplicate forward declaration compile/run in
  both editions (`FWD enum=1 struct=3 union=5 class=3 generic=9 duplicate=0`).
- `p06_18c_coupled_class.sv`: coupled forward class declarations compile/run
  in both editions (`NODE=7`).
- `p06_18d_forward_class_scope.sv` is the standard's legal example
  (`typedef C; typedef C::T c_t; c_t y; class C; typedef int T; endclass`) and
  fails in both editions with `C doesn't name a visible class.`
- `p06_18e_interface_based_typedef.sv` is the standard's interface-based
  typedef example (`typedef p.data_t my_data_t`) and fails in both editions
  with `Syntax error in typedef clause.`
- `neg/n06_18_fwd_wrong_kind.sv` compiles in both editions despite a forward
  enum typedef being resolved as a struct; §6.18 requires an error when the
  final type does not conform to the declared forward kind.
- The incomplete-class-scope, unresolved-forward, hierarchical-type, and
  identifier-resolves-to-variable negatives all reject in both editions.

All-state dedupe terms were `event`, `event null`, `event alias`, `event assign`,
`forward typedef`, `typedef class`, `interface typedef`, `typedef scope`, and
`typedef enum`. Unique hits are in
[`attempt-01/dedupe-unique.txt`](attempt-01/dedupe-unique.txt). The broad
closed issue #19 was reviewed; it does not name these specific forward-type
rules. The lead classified the three §6.18 gaps as distinct, and they are
filed OPEN with `1800-audit` labels: [#760](https://github.com/dsellerbrock/iverilog-uvm/issues/760)
(class-scope selection through a forward class), [#761](https://github.com/dsellerbrock/iverilog-uvm/issues/761)
(interface-based typedef), and [#762](https://github.com/dsellerbrock/iverilog-uvm/issues/762)
(wrong-kind forward definition).

Standards read: IEEE 1800-2017 §6.17 p.112 and §6.18 pp.112–113; IEEE
1800-2023 §6.17 p.117 and §6.18 pp.117–118. No edition difference was
observed.
