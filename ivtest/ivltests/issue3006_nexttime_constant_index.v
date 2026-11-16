// IEEE 1800-2023 16.12.10: a constant-expression nexttime index counts
// that many clock ticks. A localparam or `1+1' index used to be lowered as
// one tick; `a' is 1 on alternate cycles, so one tick would fail.
module issue3006_nexttime_constant_index;
  localparam int N = 2;
  bit clk, a;
  int pass_l = 0, fail_l = 0, pass_e = 0, fail_e = 0, pass_0 = 0, fail_0 = 0;
  always #5 clk = !clk;
  initial begin a = 1; forever begin @(negedge clk); a = !a; end end
  assert property (@(posedge clk) a |-> nexttime[N] a) pass_l++; else fail_l++;
  assert property (@(posedge clk) a |-> s_nexttime[1+1] a) pass_e++; else fail_e++;
  assert property (@(posedge clk) a |-> nexttime[0] a) pass_0++; else fail_0++;
  initial begin
    #200;
    $display("l=%0d/%0d e=%0d/%0d z=%0d/%0d", pass_l, fail_l, pass_e, fail_e,
             pass_0, fail_0);
    if (pass_l > 0 && fail_l == 0 && pass_e > 0 && fail_e == 0
        && pass_0 > 0 && fail_0 == 0)
      $display("PASSED");
    else
      $display("FAILED");
    $finish;
  end
endmodule
