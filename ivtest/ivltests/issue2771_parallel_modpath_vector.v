`timescale 1ns/1ns
module issue2771_parallel_modpath_vector_path(input [1:0] a,
                                              output [1:0] y);
  assign y = a;
  specify (a => y) = (3, 7); endspecify
endmodule

module issue2771_parallel_modpath_vector;
  reg [1:0] a = 0;
  wire [1:0] y;
  issue2771_parallel_modpath_vector_path u(a, y);

  initial $monitor("%0t y=%b", $time, y);
  initial begin
    #10 a = 2'b01;
    #20 a = 2'b10;
    #20 a = 2'b11;
    #20 a = 2'b00;
    #20 $finish;
  end
endmodule
