module test;
  logic [1:0][7:0] words;
  integer pos;
  assign words[0] = 8'h20;
  initial words[0][pos+:4] = 4'h3;
endmodule
