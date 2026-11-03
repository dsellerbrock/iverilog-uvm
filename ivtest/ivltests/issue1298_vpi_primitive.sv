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

module top;
  logic a, b;
  wire [1:0] y;
  wire z;

  and g (y[0], a, b);
  not inv (y[1], a);
  myudp udp1 (z, a, b);

  initial begin
    a = 1'b0;
    b = 1'b1;
    #1;
    $probe_primitives;
    #1 $finish;
  end
endmodule
