module test;
  logic [7:0] value;
  logic [1:0] result;

  initial result = (value[3:2] = 2'b10);
endmodule
