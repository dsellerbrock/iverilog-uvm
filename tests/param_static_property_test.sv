// Phase 62 / I5: `Class#(args)::var` should resolve to the SPECIALIZED
// class's static property, not the unparameterized base.  And the
// specialization's static initializer must run BEFORE any user-class
// init that mutates state on it (the UVM `uvm_register_cb` pattern).
`timescale 1ns/1ps
module top;
  class TypedPool#(type T = int);
    static int m_registered = 0;
    static function bit register_pair(string tag);
      m_registered = 1;
      return 1;
    endfunction
  endclass

  class MyClass;
    static local bit m_done = TypedPool#(MyClass)::register_pair("MyClass");
    static function bit get_done(); return m_done; endfunction
  endclass

  initial begin
    int v;
    void'(MyClass::get_done());
    v = TypedPool#(MyClass)::m_registered;
    if (v == 1)
      $display("PASS: TypedPool#(MyClass)::m_registered = %0d", v);
    else begin
      $display("FAIL: expected 1, got %0d (specialization init order broken)", v);
      $fatal(1, "I5 specialization static-property access broken");
    end
    $finish;
  end
endmodule
