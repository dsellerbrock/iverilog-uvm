// M2 / G23 UVM-level regression (RESOLVED-BY-PRIOR; regression protection): `uvm_register_cb(T, CB) macro must not corrupt class layout.
import uvm_pkg::*;
`include "uvm_macros.svh"

class my_cb extends uvm_callback;
  function new(string name = "my_cb");
    super.new(name);
  endfunction
  virtual function void on_event(int x);
  endfunction
endclass

class my_comp extends uvm_component;
  `uvm_component_utils(my_comp)
  `uvm_register_cb(my_comp, my_cb)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  function void hit(int x);
    `uvm_do_callbacks(my_comp, my_cb, on_event(x))
  endfunction
endclass

class counting_cb extends my_cb;
  int count = 0;
  function new(string name = "counting_cb");
    super.new(name);
  endfunction
  virtual function void on_event(int x);
    count = count + x;
  endfunction
endclass

module m2_uvm_register_cb_test;
  initial begin
    my_comp c;
    counting_cb cb;
    c = new("c", null);
    cb = new("cb");
    uvm_callbacks#(my_comp, my_cb)::add(c, cb);
    c.hit(3);
    c.hit(4);
    if (cb.count == 7) $display("PASS g23");
    else $display("FAIL g23 count=%0d expected 7", cb.count);
    $finish;
  end
endmodule
