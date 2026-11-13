primitive p(q, a);
  output reg q;
  input a;
  initial q = 2'b01;
  table
    0 : ? : 0;
    1 : ? : 1;
  endtable
endprimitive
module top;
  wire q;
  reg a;
  p inst(q, a);
endmodule
primitive pzero(q, a);
  output reg q; input a;
  initial q = 2'b00;
  table 0 : ? : 0; 1 : ? : 1; endtable
endprimitive
primitive px(q, a);
  output reg q; input a;
  initial q = 8'bx;
  table 0 : ? : 0; 1 : ? : 1; endtable
endprimitive
