module leaf #(parameter int N = 1) ();
endmodule
module top;
  localparam int N = 3;
  leaf #(.N) inst ();
endmodule
