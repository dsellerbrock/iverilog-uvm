// IEEE 1800 37.14: connections of a port bit through its parent port.
module leaf(input wire [1:0] d, input wire [-2:-1] asc,
            input wire [1:0] sel, expr, open_port,
            input wire [7:6][0:1] matrix, input wire [0:0] one);
endmodule

module cat(.p({x, y}));
  input wire x, y;
endmodule

module top;
  wire [1:0] w;
  bit [5:4] v;
  wire [3:0] wide;
  wire [0:1][3:2] m;
  wire [0:0] one;
  leaf l(w, v, wide[2:1], ~w, , m, one);
  cat c(w);
endmodule
