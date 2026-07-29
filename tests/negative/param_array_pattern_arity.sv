// An assignment pattern for an unpacked array parameter must supply
// exactly one expression per element (IEEE 1800-2017 10.9.1 / 7.6).
// Three expressions for a four-element array used to silently create a
// three-element expansion.
module main;
  parameter logic [3:0] AP [0:3] = '{4'd1, 4'd2, 4'd3};
  initial $display("%0d", AP[0]);
endmodule
