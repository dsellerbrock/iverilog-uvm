module sv_covergroup_cross_recursive_with_matches_unsupported;
  int a;
  covergroup cg;
    ca: coverpoint a { bins z = {0}; }
    cx: cross ca {
      // DD042 deliberately does not implement threshold policy.
      bins x = binsof(ca) with (ca == 0) matches 2;
    }
  endgroup
  cg c = new;
endmodule
