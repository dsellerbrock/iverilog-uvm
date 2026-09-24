module overlap(input logic source, input logic enable);
  logic driven;
  assign driven = source;
  always_comb if (enable) driven = 1'b0;
endmodule
