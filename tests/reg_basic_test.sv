// Minimal UVM reg layer test: define a register block with one field,
// do a backdoor write and read, verify value.
`include "uvm_macros.svh"
import uvm_pkg::*;

// Simple in-memory backdoor that stores the register value without DPI
class mem_backdoor extends uvm_reg_backdoor;
  `uvm_object_utils(mem_backdoor)
  uvm_reg_data_t stored_val;
  uvm_reg_data_t last_read_val;

  function new(string name = "mem_backdoor");
    super.new(name);
    stored_val = 0;
  endfunction

  virtual task write(uvm_reg_item rw);
    stored_val = rw.get_value(0);
    rw.set_status(UVM_IS_OK);
  endtask

  virtual function void read_func(uvm_reg_item rw);
    rw.set_value(stored_val, 0);
    last_read_val = rw.get_value(0);
    $display("DEBUG read_func: stored_val=0x%0h, after-set get_value(0)=0x%0h", stored_val, last_read_val);
    rw.set_status(UVM_IS_OK);
  endfunction
endclass

// Simple register: one 8-bit RW field "data"
class ctrl_reg extends uvm_reg;
  `uvm_object_utils(ctrl_reg)
  rand uvm_reg_field data;

  function new(string name = "ctrl_reg");
    super.new(name, 8, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    data = uvm_reg_field::type_id::create("data");
    data.configure(this, 8, 0, "RW", 0, 8'h00, 1, 1, 1);
  endfunction
endclass

// Register block containing ctrl_reg
class my_reg_block extends uvm_reg_block;
  `uvm_object_utils(my_reg_block)
  rand ctrl_reg ctrl;

  function new(string name = "my_reg_block");
    super.new(name, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    mem_backdoor bd;
    ctrl = ctrl_reg::type_id::create("ctrl");
    ctrl.build();
    ctrl.configure(this, null, "ctrl");
    bd = new("ctrl_bd");
    ctrl.set_backdoor(bd);
    default_map = create_map("default_map", 0, 1, UVM_LITTLE_ENDIAN);
    default_map.add_reg(ctrl, 0, "RW");
    lock_model();
  endfunction
endclass

class reg_basic_test extends uvm_test;
  `uvm_component_utils(reg_basic_test)

  my_reg_block regmodel;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    regmodel = my_reg_block::type_id::create("regmodel");
    regmodel.build();
  endfunction

  task run_phase(uvm_phase phase);
    uvm_status_e status;
    uvm_reg_data_t rdata;
    $display("DEBUG: run_phase started");
    phase.raise_objection(this);
    $display("DEBUG: objection raised");

    // Backdoor write via in-memory backdoor
    $display("DEBUG: before write");
    regmodel.ctrl.write(status, 8'hAB, UVM_BACKDOOR);
    $display("DEBUG: after write");
    if (status == UVM_IS_OK)
      `uvm_info("REG_TEST", "PASS: backdoor write accepted (status=UVM_IS_OK)", UVM_NONE)
    else
      `uvm_error("REG_TEST", $sformatf("FAIL: backdoor write status=%0d", status))

    // Backdoor read
    regmodel.ctrl.read(status, rdata, UVM_BACKDOOR);
    if (status != UVM_IS_OK)
      `uvm_error("REG_TEST", $sformatf("FAIL: backdoor read status=%0d", status))
    else if (rdata == 8'hAB)
      `uvm_info("REG_TEST", $sformatf("PASS: backdoor read rdata=0x%0h", rdata), UVM_NONE)
    else
      `uvm_error("REG_TEST", $sformatf("FAIL: backdoor read rdata=0x%0h expected 0xAB", rdata))

    // Mirror check
    if (regmodel.ctrl.get() == 8'hAB)
      `uvm_info("REG_TEST", "PASS: mirrored value matches 0xAB", UVM_NONE)
    else
      `uvm_error("REG_TEST", $sformatf("FAIL: mirrored=0x%0h expected 0xAB", regmodel.ctrl.get()))

    phase.drop_objection(this);
  endtask
endclass

module top;
  initial run_test("reg_basic_test");
endmodule
