// Under -gcommercial-unsafe the 29.3.4 row conflict is a warning.
primitive issue3075_unsafe_p(q, a);
  output q; input a;
  table
    0 : 0;
    0 : 1;
    1 : 1;
  endtable
endprimitive

module issue3075_udp_unsafe;
  reg a = 1;
  wire q;
  issue3075_unsafe_p u(q, a);
  initial #1 if (q === 1'b1) $display("PASSED"); else $display("FAILED %b", q);
endmodule
