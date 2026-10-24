interface A_Bus(input logic clk);
  logic sig;
  clocking cbx @(posedge clk);
    input sig;
  endclocking
  modport M2 (clocking cbx);
endinterface
module u2(A_Bus.M2 p);
  initial begin
    @(p.cbx);
    $display("tick %0t", $time);
  end
endmodule
module top;
  logic clk = 0;
  A_Bus b1(clk);
  u2 x(b1);
  always #5 clk = ~clk;
  initial #20 $finish;
endmodule
