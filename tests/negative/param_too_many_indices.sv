// More index components than the parameter has packed dimensions must
// be an error, not a silent use of only the final index (which selected
// a wrong element with no diagnostic).
module main;
  parameter logic [7:0] P = 8'h5a;
  initial $display("%b", P[1][2]);
endmodule
