// DD-041: a bare-name reference from inside a class METHOD body to a
// `parameter' declared in an enclosing (package) scope used to crash the
// compiler with "assert: net_design.cc: failed assertion cur->second.ivl_type"
// -- confirmed to reproduce for ANY bare-name reference from a class method
// to a parameter declared in an enclosing, non-class-local scope, not
// specific to division, wildcard imports, or entropy_src's own shape.
//
// Root cause: NetScope::evaluate_parameter_() elaborates a class-method-
// local `localparam's declared type into `ivl_type' immediately before
// evaluating its value expression -- but if that value expression is a
// bare reference to a package parameter, resolving it (elab_and_eval)
// walks scope-visibility machinery (ensure_visible_class_type) that,
// because the ordinary (non-parameterized) class-scope elaboration path
// never marked the class `scope_ready()', treated the ALREADY-elaborated
// class as still incomplete and re-ran complete_class_scope_in_place_()
// on it -- which re-declares every method-local parameter via
// NetScope::set_parameter(), unconditionally resetting `ivl_type' back to
// null on the SAME map entry the outer evaluate_parameter_() call was
// mid-way through. Fixed by marking the class scope_ready() once
// elaborate_scope_class() finishes elaborating its methods, mirroring
// what complete_class_scope_in_place_() already does at the end of its
// own (narrower, recovery-only) completion pass.
//
// This is a real, discriminating-population runtime check: two classes in
// two different packages, each referencing a DIFFERENT same-named
// parameter, plus two instances of the same class, confirming no
// cross-instance or cross-package value confusion -- not just "does it
// avoid the crash".
package dd041_pkg_a;
  parameter int W = 4;
  class C;
    function int f();
      localparam int X = 8 / W;
      return X;
    endfunction
  endclass
endpackage

package dd041_pkg_b;
  parameter int W = 2;
  class D;
    function int g();
      localparam int Y = 8 / W;
      return Y;
    endfunction
  endclass
endpackage

module main;
  import dd041_pkg_a::*;
  import dd041_pkg_b::*;
  int fails;

  initial begin
    C c1 = new;
    C c2 = new;
    D d1 = new;

    if (c1.f() != 2) fails++;
    if (c2.f() != 2) fails++;
    if (d1.g() != 4) fails++;

    if (fails == 0) $display("PASSED");
    else $display("FAILED, fails=%0d", fails);
    $finish;
  end
endmodule
