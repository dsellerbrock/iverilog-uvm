primitive comb0(q, a);
  output q; input a;
  table
    x : 0;
  endtable
endprimitive
primitive comb1(q, a, b);
  output q; input a, b;
  table
    X x : 1;
  endtable
endprimitive
primitive seq0(q, a);
  output q; reg q; input a;
  table
    x : 0 : 1;
    x : 1 : -;
  endtable
endprimitive
