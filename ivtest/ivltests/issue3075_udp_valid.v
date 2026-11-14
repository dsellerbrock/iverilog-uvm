// Legal overlaps: rows that agree, a level row against an edge row (29.9:
// the level row wins), edges on different inputs, disjoint edges, and a
// '-' that equals the other row's output in every shared state.
primitive issue3075_valid_comb(q, a, b);
  output q; input a, b;
  table
    0 ? : 0;
    0 1 : 0;
    1 ? : 1;
  endtable
endprimitive

primitive issue3075_valid_dff(q, d, cp, cdn);
  output q; reg q; input d, cp, cdn;
  table
  // d  cp  cdn : q0 : q
     *   ?    ?  : ? : - ;
     ?   n    ?  : ? : - ;
     0   r    1  : ? : 0 ;
     1   r    1  : ? : 1 ;
     ?   ?    0  : ? : 0 ;
     ?   ?    p  : ? : - ;
  endtable
endprimitive

primitive issue3075_valid_seq(q, a);
  output q; reg q; input a;
  initial q = 1'b0;
  table
    1 : 0 : 0;
    r : 0 : 1;
    p : 1 : -;
    r : 1 : 1;
    f : ? : -;
  endtable
endprimitive

module issue3075_udp_valid;
  reg a = 0, b = 0, d = 0, cp = 0, cdn = 0;
  wire c, q, s;
  issue3075_valid_comb pc(c, a, b);
  issue3075_valid_dff pd(q, d, cp, cdn);
  issue3075_valid_seq ps(s, a);
  initial begin
    #1 if (c !== 1'b0 || q !== 1'b0) $display("FAILED comb/clear");
    cdn = 1; d = 1; #1 cp = 1; #1 if (q !== 1'b1) $display("FAILED dff");
    a = 1; #1 if (c !== 1'b1 || s !== 1'b0) $display("FAILED level wins");
    $display("PASSED");
  end
endmodule
