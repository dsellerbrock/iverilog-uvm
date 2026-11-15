// Issue #3137: IEEE 1800-2017/2023 16.5.1. A clocking-block input of an
// interface instance, named hierarchically (bus.cb.a) in a concurrent
// assertion, is the block's #1step sample. bus.a is 0 only from 12 to 18,
// so the assertion fails once, at 15.
interface bif(input logic clk);
  logic a = 1;
  clocking cb @(posedge clk); input a; endclocking
endinterface
module tb;
  logic clk = 0; int f = 0;
  always #5 clk = !clk;
  bif bus(clk);
  assert property (@(posedge bus.clk) bus.cb.a)
    else begin f++; $display("fail at %0t", $time); end
  initial begin
    #12 bus.a = 0; #6 bus.a = 1; #20;
    if (f == 1) $display("PASSED"); else $display("FAILED f=%0d", f);
    $finish;
  end
endmodule
