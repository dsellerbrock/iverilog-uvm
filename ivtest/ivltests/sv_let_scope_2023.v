let unit_value = 3;

package sv_let_scope_pkg;
  let add_one(x) = x + 1;
  let package_value = 4;
endpackage

module sv_let_scope;
  import sv_let_scope_pkg::*;

  initial begin
    if (unit_value !== 3 || package_value !== 4 || add_one(1) !== 2 ||
        sv_let_scope_pkg::add_one(1) !== 2)
      $fatal(1, "package or compilation-unit let expansion failed");
    $display("PASSED");
  end
endmodule
