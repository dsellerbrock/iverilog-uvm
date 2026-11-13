primitive comb(q, a, b);
  output q; input a, b;
  table
    0 ? : 0;
    0 1 : 0;
    1 ? : 1;
  endtable
endprimitive
primitive seq(q, a);
  output q; reg q; input a;
  initial q = 1'b0;
  table
    0 : 0 : 0;
    r : 0 : -;
    p : 0 : 0;
    f : 1 : 1;
    r : 1 : 1;
  endtable
endprimitive
module test;
  reg a, b; wire c, s;
  comb pc(c, a, b); seq ps(s, a);
  initial begin
    a=0; b=0; #1; if (c !== 0) $fatal;
    a=1; #1; if (c !== 1 || s !== 0) $fatal;
    $display("PASS");
  end
endmodule
