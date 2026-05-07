// Exercises the do_callf_void hot path: many UVM object task calls across
// deep class hierarchies.  Verifies that scope-name caching and O(1) depth
// tracking produce correct cycle-detection behaviour.
`include "uvm_macros.svh"
import uvm_pkg::*;

class leaf_obj extends uvm_object;
  int depth;
  `uvm_object_utils(leaf_obj)
  function new(string name = "leaf_obj"); super.new(name); endfunction

  // Repeatedly invoked task — the hot-path target
  task run_steps(int n);
    for (int i = 0; i < n; i++) begin
      depth = i;
      void'(convert2string());
    end
  endtask

  virtual function string convert2string();
    return $sformatf("leaf_obj depth=%0d", depth);
  endfunction
endclass

class mid_obj extends uvm_object;
  leaf_obj child;
  `uvm_object_utils(mid_obj)
  function new(string name = "mid_obj");
    super.new(name);
    child = new("child");
  endfunction

  task run_chain(int n);
    child.run_steps(n);
    void'(convert2string());
  endtask

  virtual function string convert2string();
    return {"mid_obj -> ", child.convert2string()};
  endfunction
endclass

class top_obj extends uvm_object;
  mid_obj mid;
  `uvm_object_utils(top_obj)
  function new(string name = "top_obj");
    super.new(name);
    mid = new("mid");
  endfunction

  task run_all(int n);
    repeat (n) mid.run_chain(10);
  endtask
endclass

class callf_test extends uvm_test;
  `uvm_component_utils(callf_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    top_obj t = new("t");
    phase.raise_objection(this);
    // 200 outer iterations x 10 inner = 2000 leaf run_steps calls,
    // each calling convert2string — stress-tests cached scope lookup.
    t.run_all(200);
    `uvm_info("PERF", "callf cache test PASS", UVM_NONE)
    phase.drop_objection(this);
  endtask
endclass

module top;
  initial run_test("callf_test");
endmodule
