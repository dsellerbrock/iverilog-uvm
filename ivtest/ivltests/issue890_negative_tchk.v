// IEEE 1800-2017/2023 31.9: negative $setuphold/$recrem limits, enabled by
// -gneg-tchk. Delayed signals are shared module-wide, the limits are
// adjusted, and the latched data is the value stable in the window.
`timescale 1ns/10ps

// The 31.9 probe: window (t_clk + 2, t_clk + 6), so a data change 1 ns
// after the clock is clean and latched, and one 4 ns after it violates.
module ff(input clk, input d, output reg q);
  wire dclk, dd;
  reg notifier = 0;
  always @(posedge dclk) q <= dd;
  specify
    $setuphold(posedge clk, d, -2, 6, notifier, , , dclk, dd);
  endspecify
endmodule

// The limits of the 31.9.2 example (its condition arguments left out),
// with explicit delayed signals: Figure 31-6 gives dCP 10.01, dD 0,
// dTI 20.02 and dTE 2.02.
module fig(input CP, input D, input TI, input TE);
  wire dCP, dD, dTI, dTE;
  reg notifier = 0;
  specify
    $setuphold(posedge CP, D, -10, 20, notifier, , , dCP, dD);
    $setuphold(posedge CP, TI, 20, -10, notifier, , , dCP, dTI);
    $setuphold(posedge CP, TE, -4, 8, notifier, , , dCP, dTE);
  endspecify
endmodule

// Inconsistent limits: the first check needs dclk - dd1 > 4, the second
// dd1 - dclk > 2. The negative limit closest to zero (-2) becomes 0
// (user ruling 2026-11-07 on 31.9), so dclk = 4.01 and dd1 = 0.
module bad(input clk, input d1);
  wire dclk, dd1;
  reg notifier = 0;
  specify
    $setuphold(posedge clk, d1, -4, 10, notifier, , , dclk, dd1);
    $setuphold(posedge clk, d1, 8, -2, notifier, , , dclk, dd1);
  endspecify
endmodule

module top;
  reg clk = 0, d = 0;
  wire q;
  integer violations = 0;
  reg ok = 1;
  ff u(clk, d, q);
  always @(u.notifier) violations = violations + 1;

  reg CP = 0, D = 0, TI = 0, TE = 0;
  fig f(CP, D, TI, TE);
  reg bclk = 0, bd = 0;
  bad b(bclk, bd);

  realtime t_cp, t_d, t_ti, t_te, t_bclk, t_bd;
  always @(posedge f.dCP) t_cp = $realtime;
  always @(posedge f.dD) t_d = $realtime;
  always @(posedge f.dTI) t_ti = $realtime;
  always @(posedge f.dTE) t_te = $realtime;
  always @(posedge b.dclk) t_bclk = $realtime;
  always @(posedge b.dd1) t_bd = $realtime;

  task near(input [8*8:1] what, input real got, input real want);
    if (got < want - 0.001 || got > want + 0.001) begin
      $display("FAILED %0s: %f, expected %f", what, got, want);
      ok = 0;
    end
  endtask

  initial begin
    #10 clk = 1;
    #1 d = 1;                      // before the window: no violation
    #9 if (q !== 1'b1 || violations != 0) begin
      $display("FAILED A: q=%b violations=%0d", q, violations);
      ok = 0;
    end
    clk = 0;
    #10 d = 0;
    #10 clk = 1;
    #4 d = 1;                      // inside the window: one violation
    #10 if (violations != 1) begin
      $display("FAILED B: violations=%0d", violations);
      ok = 0;
    end

    #100 CP = 1; D = 1; TI = 1; TE = 1; bclk = 1; bd = 1;
    #50;
    near("dCP", t_cp - 154, 10.01);
    near("dD", t_d - 154, 0.0);
    near("dTI", t_ti - 154, 20.02);
    near("dTE", t_te - 154, 2.02);
    near("dclk", t_bclk - 154, 4.01);
    near("dd1", t_bd - 154, 0.0);
    if (ok) $display("PASSED");
    $finish;
  end
endmodule
