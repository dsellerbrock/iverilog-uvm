module sv_packed_real_prefix_fail;
  logic [1:0][2:0][7:0] words;
  logic [3:0] value;
  initial value = words[0][1.5][0 +: 4];
endmodule
