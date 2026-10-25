class A; endclass
class B; endclass

module issue1210_cast_unrelated_null;
  A dst;
  B src;

  initial begin
    dst = new;
    src = null;
    if ($cast(dst, src))
      $fatal(1, "unrelated null class cast succeeded");
    if (dst == null)
      $fatal(1, "failed cast changed destination");
    $display("PASS");
  end
endmodule
