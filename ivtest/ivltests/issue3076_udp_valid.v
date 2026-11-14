primitive p0(q, a);
  output reg q; input a;
  initial q = 1'b0;
  table 0 : ? : 0; 1 : ? : 1; endtable
endprimitive
primitive p1(q, a);
  output reg q; input a;
  initial q = 1'b1;
  table 0 : ? : 0; 1 : ? : 1; endtable
endprimitive
primitive px(q, a);
  output reg q; input a;
  initial q = 1'bx;
  table 0 : ? : 0; 1 : ? : 1; endtable
endprimitive
primitive pu0(q, a);
  output reg q; input a;
  initial q = 0;
  table 0 : ? : 0; 1 : ? : 1; endtable
endprimitive
primitive pu1(q, a);
  output reg q; input a;
  initial q = 1;
  table 0 : ? : 0; 1 : ? : 1; endtable
endprimitive
module top;
  wire [4:0] q;
  reg a;
  p0 i0(q[0],a); p1 i1(q[1],a); px ix(q[2],a);
  pu0 iu0(q[3],a); pu1 iu1(q[4],a);
  initial begin
    #1;
    if (q !== 5'b10x10) $display("FAIL: q=%b", q);
    else $display("PASS");
  end
endmodule
