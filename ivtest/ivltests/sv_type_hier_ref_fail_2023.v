module sub;
  int x;
endmodule

module sv_type_hier_ref_fail;
  sub s();
  var type(s.x) y;
endmodule
