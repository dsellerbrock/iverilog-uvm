// An unpacked-array parameter whose DECLARED dimension names another
// parameter of the same module:
//
//     module child #(parameter int unsigned N = 4,
//                    parameter int A[N] = '{0,0,0,0});
//
// IEEE 1800-2017 23.10: a parameter override supplies a VALUE; it does
// not restate the declaration. So names in the declared range still
// resolve where the parameter was written (6.20.2) -- in the child.
//
// The declared dimension was evaluated in `val_scope', which becomes
// the INSTANTIATING scope once the parameter is overridden. Overriding
// `A' from a parent that has no `N' therefore looked `N' up in the
// parent and failed with "Unable to bind parameter `N'". Overriding
// nothing, or overriding only `N', both worked -- which is why this
// hid: it needs an override of the ARRAY specifically.
//
// Values are checked, not just compilation: the override must actually
// take effect.
module child #(parameter int unsigned N    = 4,
               parameter int          A[N] = '{0, 0, 0, 0}) ();
  initial begin
    if (N == 4 && A[0] == 1 && A[1] == 2 && A[2] == 3 && A[3] == 4)
      $display("PASSED");
    else
      $display("FAILED N=%0d A=%0d,%0d,%0d,%0d", N, A[0], A[1], A[2], A[3]);
  end
endmodule

module sv_uparam_dim_decl_scope;     // deliberately declares no `N'
  child #(.A('{1, 2, 3, 4})) u_c ();
endmodule
