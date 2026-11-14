primitive comb(q, a, b);
  output q; input a, b;
  table
    x x : x;
    x 0 : 1;
    ? 1 : 0;
  endtable
endprimitive
primitive seq(q, a);
  output q; reg q; input a;
  table
    x : 0 : x;
    x : 1 : x;
    0 : ? : 1;
  endtable
endprimitive
module test;
  reg a, b;
  wire c, s;
  comb pc(c, a, b);
  seq ps(s, a);
  initial begin
    a = 0; b = 1; #1;
    if (c !== 0 || s !== 1) $fatal(1, "ordinary rows");
    a = 1'bx; b = 0; #1;
    if (c !== 1 || s !== 1'bx) $fatal(1, "mixed or all-x rows");
    b = 1'bx; #1;
    if (c !== 1'bx) $fatal(1, "all-x row");
    $display("PASS");
  end
endmodule
