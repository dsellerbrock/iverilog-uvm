`timescale 1ns/1ps
module issue1246_width_vector_desc(input [1:0] clk);
  specify $width(posedge clk, 5); endspecify
endmodule

module issue1246_width_vector_asc(input [0:1] clk);
  specify $width(posedge clk, 5); endspecify
endmodule

module issue1246_width_vector;
  reg [1:0] desc = 0;
  reg [0:1] asc = 0;
  issue1246_width_vector_desc u_desc(desc);
  issue1246_width_vector_asc u_asc(asc);

  initial begin
    #10 desc[1] = 1;
    #2 desc[1] = 0;
    #5 desc[0] = 1;
    #2 desc[0] = 0;
    #5 asc[0] = 1;
    #2 asc[0] = 0;
    #5 asc[1] = 1;
    #2 asc[1] = 0;
    #5 $finish;
  end
endmodule
