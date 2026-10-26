class A; endclass
class B; endclass
class Base; endclass
class Derived extends Base; endclass

module issue1210_cast_unrelated_null;
  A dst;
  B unrelated;
  Base base_handle;
  Derived derived_handle;
  initial begin
    dst = new;
    unrelated = null;
    if ($cast(dst, unrelated)) $fatal(1, "unrelated null cast succeeded");
    if (dst == null) $fatal(1, "failed cast changed destination");

    if (!$cast(dst, null)) $fatal(1, "literal null cast failed");
    if (dst != null) $fatal(1, "literal null cast changed value");

    derived_handle = new;
    if (!$cast(base_handle, derived_handle))
      $fatal(1, "assignment-compatible cast failed");
    if (!$cast(derived_handle, base_handle))
      $fatal(1, "compatible dynamic downcast failed");

    $display("PASSED");
    $finish;
  end
endmodule
