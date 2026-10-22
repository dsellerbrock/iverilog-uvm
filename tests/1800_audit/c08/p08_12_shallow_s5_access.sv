module top;
  class B;
    local int p;
    protected int r;
    function void seed(int a, int b); p = a; r = b; endfunction
    function int get_p(); return p; endfunction
    function int get_r(); return r; endfunction
  endclass
  class D extends B; endclass
  D d1, d2;
  initial begin
    d1 = new; d1.seed(4, 6); d2 = new d1;
    if (d2.get_p() != 4 || d2.get_r() != 6) $fatal(1, "S5 access-controlled properties were not copied");
    $display("PASS S5 local=%0d protected=%0d", d2.get_p(), d2.get_r());
  end
endmodule
