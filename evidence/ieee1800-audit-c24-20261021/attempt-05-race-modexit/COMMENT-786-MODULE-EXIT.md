The paired module-origin reproducer for #786 is:

```systemverilog
module top;
  initial begin
    #5 $exit;
    $display("AFTER %0t", $time);
  end
  initial #10 $display("LATE %0t", $time);
endmodule
```

On Icarus source `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`, it compiles and runs with exit code 0 under both `-g2017` and `-g2023`; stdout and stderr are empty. IEEE 1800-2017/2023 §24.7 says `$exit` from a thread not originating in a program initial procedure “shall be ignored” (a warning may be issued). Expected output is `AFTER 5` then `LATE 10`; the observed empty output means the module-origin call terminates the simulation instead.

The issue-body program-origin variant was rerun separately and conforms; see [the correction comment](https://github.com/dsellerbrock/iverilog-uvm/issues/786#issuecomment-6309531937). This issue now tracks only the module-origin §24.7 failure. Paired probe sources and logs are under `evidence/ieee1800-audit-c24-20261021/attempt-05-race-modexit/`.
