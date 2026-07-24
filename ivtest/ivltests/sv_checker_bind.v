// Checkers via the idiomatic clause-17 flow: a parameterized checker
// bound into a DUT with a bind directive and a parameter override.
checker range_chk #(int MAX = 10) (input logic clk, logic [7:0] v);
  int fails = 0;
  a_r: assert property (@(posedge clk) v <= MAX) else fails++;
  m_a: assume property (@(posedge clk) !$isunknown(v));
endchecker

module dut(input logic clk, input logic [7:0] data);
endmodule

bind dut range_chk #(.MAX(5)) u_chk(clk, data);

module main;
  logic clk = 0;
  logic [7:0] data = 0;
  always #5 clk = ~clk;
  dut d0(clk, data);
  initial begin
    @(negedge clk) data = 3;   // ok (<= 5)
    @(negedge clk) data = 9;   // violates MAX=5
    @(negedge clk) data = 2;
    #12;
    if (main.d0.u_chk.fails == 1) $display("PASSED");
    else $display("FAILED -- fails=%0d, expected 1", main.d0.u_chk.fails);
    $finish(0);
  end
endmodule
