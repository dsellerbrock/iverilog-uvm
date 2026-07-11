// M1 typed-expression dispatch: virtual method dispatch through
// function-call-result receivers (IEEE 1800-2017 8.20). The static type
// of the receiver expression is the base class; the runtime type selects
// the override.
module m1_virtual_dispatch_chain_test;
  class Base;
    virtual function string who();
      return "Base";
    endfunction
    function Base me();
      return this;
    endfunction
  endclass

  class Derived extends Base;
    virtual function string who();
      return "Derived";
    endfunction
  endclass

  function automatic Base make_derived();
    Derived d = new;
    return d;
  endfunction

  initial begin
    Derived d = new;
    Base b = d;
    int errors = 0;

    // Virtual dispatch on a function-return receiver (static type Base,
    // dynamic type Derived).
    if (make_derived().who() != "Derived") begin
      $display("FAIL: make_derived().who() = %s, expected Derived",
               make_derived().who());
      errors++;
    end

    // Virtual dispatch chained through a this-returning method.
    if (b.me().who() != "Derived") begin
      $display("FAIL: b.me().who() = %s, expected Derived", b.me().who());
      errors++;
    end

    // Non-virtual behavior is unchanged: static call goes to Base.
    if (b.who() != "Derived") begin
      $display("FAIL: b.who() = %s, expected Derived (virtual)", b.who());
      errors++;
    end

    if (errors == 0) $display("PASS");
    $finish;
  end
endmodule
