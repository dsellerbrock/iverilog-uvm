typedef struct {bit [7:0] op;} i_t;
module M (output var i_t a);
  initial a.op = 8'h5A;
endmodule
module top;
  i_t t;
  M m(t);
  initial #1 $display("VE %h", t.op);
endmodule
