interface A_Bus(input logic clk);
  wire req, gnt;
  clocking sb @(posedge clk);
    input gnt;
    output req;
  endclocking
  modport STB (clocking sb);
endinterface
module T(A_Bus.STB b);
  initial begin
    @(b.sb);
    b.sb.req <= 1;
    wait (b.sb.gnt == 1);
    $display("granted %0t", $time);
    $finish;
  end
endmodule
module top;
  logic clk = 0;
  logic g = 0;
  A_Bus b1(clk);
  assign b1.gnt = g;
  always @(posedge clk) g <= b1.req;
  always #5 clk = ~clk;
  T t(b1);
  initial #100 $fatal(1, "timeout");
endmodule
