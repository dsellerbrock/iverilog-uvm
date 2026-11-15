// An extern UDP declaration must match its definition (names, positions);
// a (.*) definition needs one; a second extern for a name is an error.
extern primitive issue3081_m(output q, input a);
extern primitive issue3081_d(q, a);
extern primitive issue3081_d(q, a);

primitive issue3081_m(output q, input b);
  table 0 : 0; 1 : 1; endtable
endprimitive

primitive issue3081_n(.*);
  output q;
  input a;
  table 0 : 0; 1 : 1; endtable
endprimitive

module issue3081_extern_udp_fail;
endmodule
