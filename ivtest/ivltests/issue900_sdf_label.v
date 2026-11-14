// IEEE 1800-2017/2023 32.4.3: SDF LABEL annotates specparams, and every
// expression that uses them is re-evaluated: procedural delays (the
// clock example of 32.4.3) and specify path delays.
`timescale 1ns/100ps

module clock(input go, output reg clk);
  specparam dhigh = 2, dlow = 3;
  initial clk = 0;
  always begin
    wait (go);
    #dhigh clk = 1;
    #dlow clk = 0;
  end
endmodule

module d1(input a, output y);
  assign y = a;
  specify
    specparam tr = 1, tf = 1;
    (a => y) = (tr, tf);
  endspecify
endmodule

module d2(input a, output y);
  assign y = a;
  specify
    specparam cap = 0;
    (a => y) = (1.4 * cap + 0.7);
  endspecify
endmodule

// User ruling 2026-11-07 on 32.4.3: a LABEL value is a plain number; the
// SDF TIMESCALE (here 100ps, against the module's 1ns) does not scale it.
module d3(input go);
  specparam k = 1;
  realtime fired;
  initial begin
    wait (go);
    #k fired = $realtime;
  end
endmodule

module top;
  reg go = 0, a1 = 0, a2 = 0;
  wire clk, y1, y2;
  reg ok = 1;
  clock c(go, clk);
  d1 u1(a1, y1);
  d2 u2(a2, y2);
  d3 u3(go);

  realtime clk_rise, clk_fall, y1_rise, y1_fall, y2_rise;
  always @(posedge clk) if (clk_rise == 0) clk_rise = $realtime;
  always @(negedge clk) if (clk_fall == 0) clk_fall = $realtime;
  always @(posedge y1) y1_rise = $realtime;
  always @(negedge y1) y1_fall = $realtime;
  always @(posedge y2) y2_rise = $realtime;

  task near(input [8*8:1] what, input real got, input real want);
    if (got < want - 0.01 || got > want + 0.01) begin
      $display("FAILED %0s: %f, expected %f", what, got, want);
      ok = 0;
    end
  endtask

  initial begin
    $sdf_annotate("ivltests/issue900_sdf_label.sdf", top);
    $sdf_annotate("ivltests/issue900_sdf_label_ps.sdf", top);
    #1 go = 1;            // dhigh 6, dlow 3 + 1: rise at 7, fall at 11
    #19 a1 = 1;           // 20: tr 4
    #10 a1 = 0;           // 30: tf 6
    #10 a2 = 1;           // 40: 1.4 * 5 + 0.7 = 7.7
    #20;
    near("clk rise", clk_rise, 7);
    near("clk fall", clk_fall, 11);
    near("y1 rise", y1_rise, 24);
    near("y1 fall", y1_fall, 36);
    near("y2 rise", y2_rise, 47.7);
    $display("LABEL unscaled: k delay %0.1f", u3.fired - 1.0);
    if (ok) $display("PASSED");
    $finish;
  end
endmodule
