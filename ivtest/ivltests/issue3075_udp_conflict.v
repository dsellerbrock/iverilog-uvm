// IEEE 1800-2023 29.3.4: "It shall be illegal to have the same combination
// of inputs, including edges, specify different output values."
primitive issue3075_duplicate(q, a);
  output q; input a;
  table
    0 : 0;
    0 : 1;
  endtable
endprimitive

primitive issue3075_overlap(q, a, b);
  output q; input a, b;
  table
    b 0 : x;
    1 ? : 1;
  endtable
endprimitive

// p includes (0x); in state 1 the second row's '-' is 1, the first's 0.
primitive issue3075_edge_overlap(q, a);
  output q; reg q; input a;
  table
    p : ? : 0;
    (0x) : 1 : -;
  endtable
endprimitive

module issue3075_udp_conflict;
  wire q1, q2, q3;
  reg a, b;
  issue3075_duplicate u1(q1, a);
  issue3075_overlap u2(q2, a, b);
  issue3075_edge_overlap u3(q3, a);
endmodule
