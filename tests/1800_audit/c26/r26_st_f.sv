typedef struct {bit [7:0] op;} i_t;
module M (input i_t a, output [7:0] b);
  assign b = a.op;
endmodule
module top;
  i_t t;
  wire [7:0] y;
  M m(t, y);
  initial begin t.op = 8'h5A; #1 $display("SF %h", y); end
endmodule
