module sv_type_hier_ref_fail_sub;
  int x;
endmodule

module sv_type_hier_ref_fail;
  sv_type_hier_ref_fail_sub s();
  var type(s.x) y;
endmodule
