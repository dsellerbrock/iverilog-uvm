module main;
  class c; endclass
  c object;
  logic q;
  initial q = 1'b1 ? object : null;
endmodule
