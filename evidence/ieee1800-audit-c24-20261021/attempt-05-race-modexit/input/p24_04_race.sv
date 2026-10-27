module dut(input logic clk, input logic [3:0] d, output logic [3:0] q);
  always @(posedge clk) q <= d;
endmodule

program tb(input logic clk, output logic [3:0] d, input logic [3:0] q);
  initial begin
    d = 0;
    repeat (3) begin
      @(posedge clk);
      $display("T %0t q=%0d", $time, q);
      d = d + 1;
    end
  end
endprogram

module top;
  logic clk = 0;
  always #5 clk = ~clk;
  logic [3:0] d, q;
  dut u(.*);
  tb t(.*);
endmodule
