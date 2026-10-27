`timescale 1ns/1ps

primitive simple_udp(q, a);
  output q;
  input a;
  table
    0 : 0;
    1 : 1;
  endtable
endprimitive

module p29_instance_array;
  reg a = 0;
  wire [1:0] q;
  simple_udp ua[1:0](q, a);
  initial begin
    #1 $display("A0 %b", q);
    a = 1;
    #1 $display("A1 %b", q);
  end
endmodule
