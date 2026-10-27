typedef struct {bit [7:0] op;} i_t;
module M (input var i_t a);
  initial #1 $display("VD %h", a.op);
endmodule
module top;
  i_t t;
  M m(t);
  initial t.op = 8'h5A;
endmodule
