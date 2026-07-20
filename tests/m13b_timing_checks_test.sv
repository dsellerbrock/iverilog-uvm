// M13B: $timeskew / $fullskew / $nochange timing checks and
// edge-descriptor event lists (edge [01, x1]). Requires -gspecify
// (listed in the IVFLAGS table of the sweep).
//
// The timeline is arranged so every notifier toggles exactly once
// (odd parity) except n_none, which must stay 0:
//   t10 clk rises   (window opens; $timeskew stamp)
//   t12 d changes   -> $nochange violation (inside window)     n_noch
//   t14 clk falls   (window closes; not in the [01,x1] list)
//   t30 e changes   -> $fullskew dir-1 violation (20 > 2)      n_full
//                      ($timeskew(...e...,50) sees 20 <= 50)   n_none
//   t50 d changes   -> $timeskew violation (40 > 3)            n_tsk
//   t52 clk rises   -> edge-list $setup violation (2 < 3)      n_setup
//   t54 clk falls
`timescale 1ns/1ns

module m13b_tc_dut(input wire clk, input wire d, input wire e);
  reg n_noch  = 0;
  reg n_tsk   = 0;
  reg n_setup = 0;
  reg n_full  = 0;
  reg n_none  = 0;
  specify
    $nochange(posedge clk, d, 0, 0, n_noch);
    $timeskew(posedge clk, d, 3, n_tsk);
    $setup(d, edge [01, x1] clk, 3, n_setup);
    $fullskew(posedge clk, e, 2, 100, n_full);
    $timeskew(posedge clk, e, 50, n_none);
  endspecify
endmodule

module m13b_timing_checks_test;
  reg clk = 0, d = 0;
  reg e;   // no initializer: first event is the t30 assign
  m13b_tc_dut u(.clk(clk), .d(d), .e(e));

  initial begin
    #10 clk = 1;
    #2  d = 1;
    #2  clk = 0;
    #16 e = 1;
    #20 d = 0;
    #2  clk = 1;
    #2  clk = 0;
    #6;
    if (u.n_noch === 1'b1 && u.n_tsk === 1'b1 && u.n_setup === 1'b1
        && u.n_full === 1'b1 && u.n_none === 1'b0)
      $display("PASS: M13B timing checks (noch=%b tsk=%b setup=%b full=%b none=%b)",
               u.n_noch, u.n_tsk, u.n_setup, u.n_full, u.n_none);
    else
      $display("FAIL: notifiers noch=%b tsk=%b setup=%b full=%b none=%b (want 1 1 1 1 0)",
               u.n_noch, u.n_tsk, u.n_setup, u.n_full, u.n_none);
    $finish(0);
  end
endmodule
