typedef struct {bit [7:0] op; logic [3:0] tag;} i_t;

module M(input var i_t a, output [7:0] b, output [3:0] t);
  assign b = a.op;
  assign t = a.tag;
endmodule

module top;
  i_t c;
  wire [7:0] w, port_w;
  wire [3:0] t, port_t;
  M m(c, port_w, port_t);
  assign w = c.op;
  assign t = c.tag;
  initial begin
    c.op = 8'h5A;
    c.tag = 4'b10x1;
    #1 $display("local=%h/%h port=%h/%h", w, t, port_w, port_t);
    $finish;
  end
endmodule
