// Phase 62 / I5: class-static initializers must run in declaration
// (lexical) order so that dependent inits — like UVM's `uvm_register_cb`
// pattern — see the base class's static state already initialized.
`timescale 1ns/1ps
module top;
  class Foo;
    static int m_state = init_state();
    static function int init_state();
      return 0;
    endfunction
    static function bit register_x(string s);
      m_state = m_state + 1;
      return 1;
    endfunction
  endclass

  class Bar;
    static local bit m_done = Foo::register_x("Bar");
    static function bit get_done(); return m_done; endfunction
  endclass

  class Baz;
    static local bit m_done = Foo::register_x("Baz");
    static function bit get_done(); return m_done; endfunction
  endclass

  initial begin
    void'(Bar::get_done());
    void'(Baz::get_done());
    if (Foo::m_state == 2 && Bar::get_done() == 1 && Baz::get_done() == 1) begin
      $display("PASS: static-init order preserved (Foo::m_state=%0d)", Foo::m_state);
    end else begin
      $display("FAIL: Foo::m_state=%0d Bar::done=%0d Baz::done=%0d (expected 2,1,1)",
	   Foo::m_state, Bar::get_done(), Baz::get_done());
      $fatal(1, "static init order broken");
    end
    $finish;
  end
endmodule
