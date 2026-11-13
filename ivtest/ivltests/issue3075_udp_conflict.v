primitive duplicate(q, a);
  output q; input a;
  table
    0 : 0;
    0 : 1;
  endtable
endprimitive
primitive overlap(q, a, b);
  output q; input a, b;
  table
    b 0 : x;
    1 ? : 1;
  endtable
endprimitive
primitive edge_overlap(q, a);
  output q; reg q; input a;
  table
    p : ? : 0;
    (0x) : 1 : -;
  endtable
endprimitive
primitive level_edge(q, a);
  output q; reg q; input a;
  table
    1 : 0 : 0;
    r : 0 : 1;
  endtable
endprimitive
