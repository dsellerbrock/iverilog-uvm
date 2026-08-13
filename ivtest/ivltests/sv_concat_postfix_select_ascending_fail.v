module test;
  logic [7:0] hi;
  logic [7:0] lo;
  logic [3:0] result;

  initial result = {hi,lo}[6:9];
endmodule
