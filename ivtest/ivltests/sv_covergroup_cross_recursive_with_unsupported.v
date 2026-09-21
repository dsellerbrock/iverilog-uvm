module sv_covergroup_cross_recursive_with_unsupported;
  bit [1:0] a;
  covergroup cg;
    ca: coverpoint a { wildcard bins any = {2'b??}; }
    cx: cross ca {
      // The bounded value-tuple evaluator cannot enumerate wildcard bins.
      bins x = binsof(ca) with (ca == 0);
    }
  endgroup
  cg c = new;
endmodule
