// Issue #3181 (IEEE 1800-2023 23.2.2.1, 37.14): a port whose formal is a
// port expression has that expression as its vpiLowConn. $probe checks it.
module cat(.p({x, y}), .q(z[1:0]), .r(w), s);
  input wire x, y;
  input wire [3:0] z;
  input wire w;
  input wire s;
endmodule

module top;
  wire e, f, g, h;
  wire [1:0] k;
  cat c({e, f}, k, g, h);
  initial #1 $probe;
endmodule
