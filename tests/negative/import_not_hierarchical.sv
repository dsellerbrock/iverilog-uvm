// IEEE 1800-2017 26.3: imported names are visible LEXICALLY in the
// importing scope, but are NOT part of the design hierarchy -- they
// must not be reachable through hierarchical (`m.x`) or package-scoped
// (`P::y` for a $unit symbol merely visible inside P) references. The
// fork's unresolved-reference-as-warning policy used to downgrade
// these binding failures to compile-progress warnings (vendored ivtest
// sv_import_hier_fail1-3, sv_ps_hier_fail1/2): a reference whose
// prefix names a REAL scope is a genuine binding error, not typing loss.
package P;
  integer x;
endpackage
module M;
  import P::x;
endmodule
module import_not_hierarchical;
  M m ();
  initial begin
    integer y;
    y = m.x;  // error: import not visible through hierarchy
  end
endmodule
