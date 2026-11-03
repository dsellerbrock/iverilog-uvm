module child #(parameter integer P = 4)(); endmodule
module narrow #(parameter [3:0] P = 4)(); endmodule

module top;
  child #(.P(8)) u();
  child #(3 + 5) v();
  narrow #(.P(8'h2f)) n();
endmodule
