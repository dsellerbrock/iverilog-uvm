package A; typedef struct packed {bit [7:0] op;} p_t; endpackage
module M import A::p_t; (input p_t a, output [7:0] b);
  assign b = a.op;
endmodule
module top;
  A::p_t t;
  wire [7:0] y;
  M m(t, y);
  initial begin t.op = 8'h5A; #1 $display("SG %h", y); end
endmodule
