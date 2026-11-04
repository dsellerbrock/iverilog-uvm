primitive myudp (y, a, b);
  output y;
  input a, b;
  table
    0 0 : 0;
    0 1 : 0;
    1 0 : 0;
    1 1 : 1;
  endtable
endprimitive

module top(input logic a, input logic b, output wire [1:0] y);
  wire z;
  wire t0, t1, t2, t3;

  and g (y[0], a, b);
  not inv (y[1], a);
  myudp udp1 (z, a, b);
  tran tr (t0, t1);
  tranif1 tr_en (t2, t3, a);

endmodule

module issue1298_tb;
  logic a, b;
  wire [1:0] y;
  top top (a, b, y);

  initial begin
    a = 1'b0;
    b = 1'b0;
    #1 $check_primitive_vpi;
    $finish;
  end
endmodule
