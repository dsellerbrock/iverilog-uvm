// Phase 51: $value$plusargs writes to a class string property (local var)
`include "uvm_macros.svh"
import uvm_pkg::*;

class my_cfg extends uvm_object;
  `uvm_object_utils(my_cfg)
  string test_name;
  string seed_str;
  function new(string name="my_cfg");
    super.new(name);
    test_name = "default";
    seed_str  = "none";
  endfunction
endclass

class my_test extends uvm_test;
  `uvm_component_utils(my_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    my_cfg local_cfg;
    phase.raise_objection(this);
    local_cfg = my_cfg::type_id::create("local_cfg");
    // populate via +plusarg — local_cfg is a local var so this is a direct property access
    void'($value$plusargs("MY_TESTNAME=%s", local_cfg.test_name));
    void'($value$plusargs("MY_SEED=%s",     local_cfg.seed_str));
    `uvm_info("TEST", $sformatf("test_name='%s' seed='%s'",
                                 local_cfg.test_name, local_cfg.seed_str), UVM_LOW)
    if (local_cfg.test_name == "hello" && local_cfg.seed_str == "42")
      `uvm_info("TEST", "PHASE51_PASS", UVM_LOW)
    else
      `uvm_error("TEST", $sformatf("PHASE51_FAIL got test_name=%s seed=%s",
                                    local_cfg.test_name, local_cfg.seed_str))
    phase.drop_objection(this);
  endtask
endclass

module top;
  initial run_test("my_test");
endmodule
