# Clause 35.4, 35.5.4, 35.8, and 35.9 probe results

**Result:** §35.8 and the tested §35.9 task/function disable paths pass in
2017 and 2023 modes. §§35.4 and 35.5.4 have a reproduced gap: the compiler
accepts two imports with one C linkage name and incompatible signatures, even
when both imports are called.

## Paired-edition result

Slurm job 3559 ran on DAN-DESKTOP with the pinned compiler at `cc25756d1`,
GCC 15.2.0, 1 CPU, and 1 GiB. The full job log, tool versions, generated DPI
stubs, shared objects, source inputs, and SHA-256 values are in
[`remote-3559/`](remote-3559/).

Positive compile, link, and run returned 0 in both editions. Both outputs were
byte-identical:

```text
A1 9
T1 5
T2 1 16
F1 1
```

Neither `NOT_REACHED` nor `FUNCTION_NOT_REACHED` printed. The C linkage alias
`c_add2` correctly resolves to local SystemVerilog name `my_add`; the imported
context task advances time through the exported task; disabling its parent
returns status 1 and does not resume the SV tail. The separate imported
function detects disabled state and calls `svAckDisabledState()` before
returning.

The §35.4 negative source calls both incompatible imports:

```systemverilog
import "DPI-C" c_add2 = function int f1(int a, int b);
import "DPI-C" c_add2 = function real f2(real a);
initial begin
  $display("I1 %0d", f1(3, 4));
  $display("I2 %0.1f", f2(2.0));
end
```

`iverilog -g2017` and `iverilog -g2023` each returned **0** with empty
diagnostics. The compiler accepted a duplicate C name with different return,
argument count, and argument types. The expected result under §35.4's
no-overloading rule and §35.5.4's matching-signature rule is a compile-time
error. The negative binary was not linked or run because the foreign C
routines are intentionally absent.

Exact compile forms, using the pinned toolchain, were:

```sh
iverilog -B "$IVL_ROOT/lib/ivl" -g2017 -o n35_dup_c_identifier.out input/n35_dup_c_identifier.sv
iverilog -B "$IVL_ROOT/lib/ivl" -g2023 -o n35_dup_c_identifier.out input/n35_dup_c_identifier.sv
```

The harness used a 30-second per-command timeout and `vvp -d ./libdpi.so` for
the positive runtime. It requested 1 CPU and 1 GiB for a 10-minute maximum;
the job completed in seconds. `sbatch --wait` returned 1 only because the
expected negative compile error was not produced.

## Dedupe and issue handoff

Open and closed issue searches for `"export task"`, `"svIsDisabledState"`,
`"svAckDisabledState"`, `"disable DPI"`, `"c_identifier"`, and `"35.9"` are
saved under [`dedupe/`](dedupe/). The closed #13 DPI-completeness issue covers
task imports and exports, but its stated scope does not include global
`c_identifier` uniqueness or signature consistency. The other matches are
unrelated interface exports and a UVM regex null-input issue. No duplicate
issue for this §35.4 behavior was found.

I attempted to consult `ask-techlead --agent A3 --lead 1800-audit` before
adjusting the proposed task-disable probe to match §35.9. The helper rejected
the call with `daily lead cap reached (160)`. Following the exact standard
text and the existing `m10l_dpi_disable_protocol_test` pattern, the imported task returns
1, while `svAckDisabledState()` is exercised only by the separate imported
function. Issue filing and final lead classification are pending an available
lead call; no issue has been created by this probe runner.
