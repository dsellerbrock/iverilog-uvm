module sv_virtual_method_override_signature_ok;
  class base;
    virtual function base clone(); return this; endfunction
    virtual function int f(int a = 1); return a; endfunction
  endclass

  class derived extends base;
    function derived clone(); return this; endfunction
    function int f(int a = 2); return a + 10; endfunction
  endclass

  initial begin
    base b;
    derived d;
    d = new;
    b = d;
    if (b.f() != 11) $fatal(1, "virtual dispatch/default mismatch");
    if (b.clone() != d) $fatal(1, "covariant return mismatch");
    $display("PASS");
  end
endmodule
