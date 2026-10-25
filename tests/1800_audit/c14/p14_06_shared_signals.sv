`timescale 1ns/1ps
module test;
  bit clk = 0;
  always #5 clk = ~clk;

  bit din = 0;
  bit dout = 0;
  bit seen_a = 0;
  bit seen_b = 0;

  clocking cb_a @(posedge clk);
    input din;
    output dout;
  endclocking

  clocking cb_b @(posedge clk);
    input din;
    output dout;
  endclocking

  clocking cb_neg @(negedge clk);
    input din;
    output dout;
  endclocking

  initial begin
    #1 din = 1;
    fork
      begin @(cb_a); seen_a = 1; end
      begin @(cb_b); seen_b = 1; end
    join
    if (!seen_a || !seen_b || cb_a.din !== 1'b1 || cb_b.din !== 1'b1) begin
      $display("FAIL: posedge clocking blocks did not sample the same value");
      $finish(1);
    end
    cb_a.dout <= 1'b1;
    @(cb_neg);
    if (cb_neg.din !== 1'b1 || dout !== 1'b1) begin
      $display("FAIL: shared signals did not sample/drive across clocking blocks");
      $finish(1);
    end
    $display("PASSED");
    $finish(0);
  end
endmodule
