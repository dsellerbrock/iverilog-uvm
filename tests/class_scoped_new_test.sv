// Regression for the sv_class_* vendored-ivtest cluster: two parser gaps
// around class constructor calls.
//
// 1. Module-level `C c = new;` parsed through the fork's no-port
//    instantiation shape, whose initializer only accepted `expression` —
//    and `new` (class_new) is not derivable from `expression`, so it
//    exploded as "syntax error / Invalid module instantiation".
//    gate_instance now has class_new / dynamic_array_new initializer
//    alternatives.
// 2. `c = C::new;` in statement position was unreachable: the fork's
//    direct TYPE_IDENTIFIER K_SCOPE_RES expr/lpvalue rules win the LALR
//    shift over the ps_type_identifier reduction, so the generic
//    class_scope-based class_new path died before K_new was seen
//    ("Malformed statement"). expr_primary now supplies the K_new
//    continuation on the direct prefix.
module class_scoped_new_test;

  class C;
    int v;
    function new(int a = 1);
      v = a;
    endfunction
  endclass

  C m0 = new;          // module-level, no parens
  C m1 = new(42);      // module-level, with args
  int d[] = new[3];    // module-level dynamic_array_new initializer

  initial begin
    C s0, s1, s2;
    s0 = C::new;       // scoped, statement position
    s1 = C::new(7);    // scoped with args
    s2 = new(9);       // plain new still works
    if (m0.v == 1 && m1.v == 42 && d.size() == 3
        && s0.v == 1 && s1.v == 7 && s2.v == 9)
      $display("PASS: class/scoped new in module and statement contexts");
    else
      $display("FAIL: m0=%0d m1=%0d dsz=%0d s0=%0d s1=%0d s2=%0d",
               m0.v, m1.v, d.size(), s0.v, s1.v, s2.v);
    $finish;
  end
endmodule
