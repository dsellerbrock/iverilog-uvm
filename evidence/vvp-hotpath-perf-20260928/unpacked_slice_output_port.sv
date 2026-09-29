module m(input logic [1:0] a, output logic [1:0] s [3:0]);
  always_comb for (int i = 0; i < 4; i++) s[i] = a ^ i[1:0];
endmodule
module t;
  logic [1:0] a = 2'b01;
  logic [1:0] s [2][3:0];
  logic [1:0] s1 [3:0];
  m u0(.a(a), .s(s[0]));
  m u1(.a(a), .s(s1));
  initial begin #1 $display("%b %b %b %b | %b %b", s[0][0], s[0][1], s[0][3], s[1][0], s1[0], s1[3]); end
endmodule
