module dut(input a, output reg y);
  always @* y = a;
  specify
    (edge a => (y : a)) = 2;
  endspecify
endmodule

module issue1244_edge_path;
  reg a = 0;
  wire y;
  dut d(a, y);
  initial begin
    #1 a = 1;
    #1 a = 0;
    #3 $display("PASS");
    $finish;
  end
endmodule
