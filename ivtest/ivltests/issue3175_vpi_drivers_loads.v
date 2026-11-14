// Issue #3175 (IEEE 1800-2023 37.16, 37.21, 37.46): drivers and loads from
// continuous assignments and ports. $probe checks them from VPI.
module child(input wire ci, output wire co, input wire [1:0] cv);
  assign co = ci & cv[0];
endmodule

module top;
  wire scalar;
  wire [3:0] vec;
  wire sink, trinet, o1;
  typedef struct packed { logic [3:0] a; logic b; } st_t;
  st_t s, outs;
  logic [7:0] arr [0:1];
  logic [7:0] out;
  wire [7:0] warr [0:1];
  wire [7:0] wout;
  assign scalar = 1'b0;
  assign vec = 4'b1010;
  assign sink = vec[2];
  assign out = arr[0];
  assign outs = s;
  assign wout = warr[1];
  assign vec[1:0] = 2'b01;
  child c1(!trinet, o1, vec[3:2]);
  child c2(scalar, trinet, vec[1:0]);
  initial begin
    s = '0; arr[0] = 8'h5a; arr[1] = 8'ha5;
    #1 $probe;
  end
endmodule
