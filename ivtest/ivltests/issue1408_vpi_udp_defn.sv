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

primitive sequdp (q, a);
  output q;
  reg q;
  input a;
  initial q = 0;
  table
    0 : 0 : 0;
    1 : 0 : 1;
    0 : 1 : 0;
    1 : 1 : 1;
  endtable
endprimitive

module issue1408_vpi_udp_defn;
  logic a, b;
  wire y, q;
  myudp udp1(y, a, b);
  sequdp udp2(q, a);
  initial begin
    #0;
    $check_udp_defs;
    $finish;
  end
endmodule
