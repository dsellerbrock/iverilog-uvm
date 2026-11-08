// Issue #2756: timestamp_condition and timecheck_condition (IEEE
// 1800-2017/2023 31.9.2) gate $setuphold and $recrem. With the condition
// false the paired check sees no event; with it true the violation is
// reported once.
`timescale 1ns/1ns
module issue2756_tchk_conditions;
  reg clk = 0, d = 0, rst = 0, ts = 0, tc = 0;
  reg n_sh = 0, n_rr = 0;
  integer sh_count = 0, rr_count = 0;

  specify
    // timestamp_condition only: gates the setup timestamp (d).
    $setuphold(posedge clk, d, 3, 3, n_sh, ts, );
    // timecheck_condition only: gates the recovery timecheck (clk).
    $recrem(posedge rst, posedge clk, 3, 3, n_rr, , tc);
  endspecify

  always @(n_sh) sh_count = sh_count + 1;
  always @(n_rr) rr_count = rr_count + 1;

  initial begin
    // ts = 0: the d change is no setup timestamp, so clk 1 ns later is fine.
    #10 d = 1;
    #1 clk = 1;
    #1 clk = 0;
    // ts = 1: the same sequence is a setup violation.
    #8 ts = 1;
    #10 d = 0;
    #1 clk = 1;
    #1 clk = 0;
    // tc = 0: clk 1 ns after rst rises is not checked for recovery.
    #8 rst = 1;
    #1 clk = 1;
    #1 clk = 0;
    #1 rst = 0;
    // tc = 1: now it is a recovery violation.
    #7 tc = 1;
    #10 rst = 1;
    #1 clk = 1;
    #1 clk = 0;
    #5;
    if (sh_count === 1 && rr_count === 1) $display("PASSED");
    else $display("FAILED: setup violations %0d, recovery violations %0d (want 1, 1)",
                  sh_count, rr_count);
  end
endmodule
