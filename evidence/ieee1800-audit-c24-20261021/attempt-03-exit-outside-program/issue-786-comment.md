Paired-edition §24.7 rerun of the module-origin `$exit` case already mentioned in this issue. Reproducer:

```systemverilog
program pg; initial begin #5 $display("PROG done"); end endprogram
module m; initial begin #1 $display("EX0"); $exit; end initial #20 $display("LATE"); endmodule
```

On current-main compiler source `fb584a251dd4cc91e56a75be662ccd5ee05c64e9` (Icarus 13.0-devel), I ran `iverilog -g2017 -o exit-2017.vvp r20_02_exit.sv; vvp exit-2017.vvp` and the same commands with `-g2023` / `exit-2023.vvp`. Both editions compile and run with exit code 0; stdout is only `EX0`, with empty stderr. Per IEEE 1800-2017/2023 §24.7, this module-origin call must be ignored, so `PROG done` should print at time 5 before program completion ends simulation. This confirms the behavior is already covered by #786; no duplicate issue was filed. Probe logs and source hash are recorded under `evidence/ieee1800-audit-c24-20261021/attempt-03-exit-outside-program/`.
