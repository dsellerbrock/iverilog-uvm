# Chip nested-associative struct VPI argument

## Result

The selected current-image `chip_sim` compile now exits 0 without the
`Unsupported VPI argument type 1` warning at
`sw_logger_if.sv:199`. It still has other compile warnings, and this was a
compile-only replay: it does not qualify the chip runtime or update the
partial 49-row census.

## Cause and fix

`$sformatf("%p", sw_logs[sw][addr])` passes an unpacked struct selected
through nested associative arrays. The final select is `IVL_EX_SELECT` with
`IVL_VT_NO_TYPE`; the VPI argument path tried to represent it as a signal
handle, then fell back to a vector. The selected aggregate now takes the
existing object evaluator path, which preserves both associative keys and
formats the struct value.

## Focused evidence

- Before the fix, the same minimal nested-associative struct formatter failed
  in both 2017 and 2023: the compiler warned and VVP terminated before the
  expected value check.
- After the fix, the paired `sv_nested_assoc_struct_display` 2017/2023 tests
  pass 2/2. Scalar enum formatting in both editions and fixed-array container
  formatting pass 3/3 alongside them; all five focused JSON tests pass with
  empty compiler and runtime stderr.
- The pinned `chip_sim` source-list compile exits 0 with zero hard errors and
  no unsupported VPI argument warning. Seven other distinct compile warning
  messages remain. The older partial census also recorded a runtime warning
  for `$value$plusargs()` called as a task; runtime was not rerun here.

Tool fingerprints: `ivl` SHA-256
`6a18cb3c8c4da86ad3e230935d8085635ea015e9fbf24eb4f6e07a8fd6ed384b`, VVP
target SHA-256 `fe1361e12742b7d80bb63b837c4ea5f3b71c3239857c858f34a611c92ae08d73`,
and VVP runtime SHA-256
`345645bee4da62c3100d722d7839c05503d9ad1dd585fbd3a7c700950eeae975`.
Pinned OpenTitan sources were not changed. The coherent 49-row current-image
census remains outstanding.
