class A; endclass
class B; endclass
class C extends A; endclass

module test;
  A dst;
  B src;
  A compatible_src;
  C derived_src;
  C downcast_dst;
  initial begin
    dst = new;
    src = null;
    if ($cast(dst, src)) $display("FAIL unrelated null cast succeeded");
    else $display("PASS unrelated null cast failed");
    if (dst == null) $fatal(1, "failed cast changed destination");
    if (!$cast(dst, null)) $fatal(1, "literal null cast failed");
    if (dst != null) $fatal(1, "literal null cast did not assign null");
    compatible_src = null;
    if (!$cast(dst, compatible_src)) $fatal(1, "same-type null cast failed");
    derived_src = null;
    if (!$cast(dst, derived_src)) $fatal(1, "assignment-compatible null cast failed");
    downcast_dst = new;
    if ($cast(downcast_dst, dst)) $fatal(1, "typed null downcast succeeded");
    if (downcast_dst == null) $fatal(1, "failed downcast changed destination");
    $display("PASS null cast controls");
  end
endmodule
