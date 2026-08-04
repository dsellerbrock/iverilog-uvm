module xnf_long_identifier(input wire a, input wire clk,
                           output wire y, output wire q);
  xnf_long_0 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa00(a, clk, y, q);
endmodule
module xnf_long_0(input wire a, input wire clk,
                  output wire y, output wire q);
  xnf_long_1 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa01(a, clk, y, q);
endmodule
module xnf_long_1(input wire a, input wire clk,
                  output wire y, output wire q);
  xnf_long_2 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa02(a, clk, y, q);
endmodule
module xnf_long_2(input wire a, input wire clk,
                  output wire y, output wire q);
  xnf_long_3 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa03(a, clk, y, q);
endmodule
module xnf_long_3(input wire a, input wire clk,
                  output wire y, output wire q);
  xnf_long_4 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa04(a, clk, y, q);
endmodule
module xnf_long_4(input wire a, input wire clk,
                  output wire y, output wire q);
  xnf_long_5 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa05(a, clk, y, q);
endmodule
module xnf_long_5(input wire a, input wire clk,
                  output wire y, output wire q);
  xnf_long_6 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa06(a, clk, y, q);
endmodule
module xnf_long_6(input wire a, input wire clk,
                  output wire y, output wire q);
  xnf_long_7 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa07(a, clk, y, q);
endmodule
module xnf_long_7(input wire a, input wire clk,
                  output wire y, output wire q);
  xnf_long_8 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa08(a, clk, y, q);
endmodule
module xnf_long_8(input wire a, input wire clk,
                  output wire y, output wire q);
  xnf_long_9 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa09(a, clk, y, q);
endmodule
module xnf_long_9(input wire a, input wire clk,
                  output wire y, output wire q);
  xnf_long_10 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa10(a, clk, y, q);
endmodule
module xnf_long_10(input wire a, input wire clk,
                   output wire y, output wire q);
  xnf_long_11 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa11(a, clk, y, q);
endmodule
module xnf_long_11(input wire a, input wire clk,
                   output wire y, output reg q);
  buf aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa12(y, a);
  always @(posedge clk)
    q <= a;
endmodule
