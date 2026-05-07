// g41_static_class_array_test.sv — static fixed-size array property indexed by variable.
// G41: elab_lval emitted context-type error "netuarray_t" because the NetNet for
// a static class array was created without proper unpacked dimensions, so
// elaborate_lval_net_word_ was never called.
`include "uvm_macros.svh"
import uvm_pkg::*;

class Registry;
  static int instances[10];

  static function void register(int idx, int val);
    instances[idx] = val;
  endfunction

  static function int lookup(int idx);
    return instances[idx];
  endfunction
endclass

class g41_static_class_array_test extends uvm_test;
  `uvm_component_utils(g41_static_class_array_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    int pass_count;
    phase.raise_objection(this);
    pass_count = 0;

    for (int i = 0; i < 5; i++)
      Registry::register(i, i * 10);

    for (int i = 0; i < 5; i++)
      if (Registry::lookup(i) == i * 10)
        pass_count++;

    if (pass_count == 5)
      `uvm_info("G41", "PASS: static class array index lvalue works", UVM_NONE)
    else
      `uvm_error("G41", $sformatf("FAIL: only %0d/5 checks passed", pass_count))

    phase.drop_objection(this);
  endtask
endclass

module top;
  initial run_test("g41_static_class_array_test");
endmodule
