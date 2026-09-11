// L33: $value$plusargs writes to a NESTED class string property
// (obj.inner.s) -- the direct case (local_cfg.test_name) is covered by
// plusargs_class_string_test.sv (Phase 51); this exercises a property
// access chained through another class-typed property, which used to
// fall back to a discarded rvalue-only temporary and silently drop the
// write. See docs/conformance/BLOCKERS.md L33 and
// evidence/campaign-20260908/dd046/c3.sv (the original reducer).
`include "uvm_macros.svh"
import uvm_pkg::*;

class inner_cfg extends uvm_object;
  `uvm_object_utils(inner_cfg)
  string seed_str;
  function new(string name="inner_cfg");
    super.new(name);
    seed_str = "none";
  endfunction
endclass

class outer_cfg extends uvm_object;
  `uvm_object_utils(outer_cfg)
  inner_cfg inner;
  function new(string name="outer_cfg");
    super.new(name);
    inner = inner_cfg::type_id::create("inner");
  endfunction
endclass

class my_test extends uvm_test;
  `uvm_component_utils(my_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    outer_cfg cfg;
    phase.raise_objection(this);
    cfg = outer_cfg::type_id::create("cfg");
    // nested property chain: cfg.inner.seed_str is not a direct signal
    // property of cfg -- it is a property of the object stored IN cfg's
    // "inner" property, resolved dynamically at each access.
    void'($value$plusargs("MY_SEED=%s", cfg.inner.seed_str));
    `uvm_info("TEST", $sformatf("seed='%s'", cfg.inner.seed_str), UVM_LOW)
    if (cfg.inner.seed_str == "42")
      `uvm_info("TEST", "L33_PASS", UVM_LOW)
    else
      `uvm_error("TEST", $sformatf("L33_FAIL got seed=%s", cfg.inner.seed_str))
    phase.drop_objection(this);
  endtask
endclass

module top;
  initial run_test("my_test");
endmodule
