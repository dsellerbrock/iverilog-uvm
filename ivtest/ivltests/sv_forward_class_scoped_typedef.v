module sv_forward_class_scoped_typedef;
  typedef C;
  typedef C::T c_t;
  c_t y;

  class C;
    typedef int T;
  endclass

  initial begin
    $display("BITS=%0d", $bits(y));
    if ($bits(y) != 32)
      $fatal(1, "forward class-scoped typedef has wrong width");
  end
endmodule
